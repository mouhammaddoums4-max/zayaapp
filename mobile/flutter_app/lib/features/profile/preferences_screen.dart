import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';

/// Préférences de découverte : elles filtrent uniquement les profils proposés au membre.
/// Se ferme en renvoyant `true` si les préférences ont été enregistrées.
class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  DiscoveryPrefs? _prefs;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = Session.read(context).repo;
    setState(() => _error = null);
    try {
      final prefs = await repo.loadPreferences();
      if (mounted) setState(() => _prefs = prefs);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  Future<void> _save(DiscoveryPrefs prefs) async {
    final repo = Session.read(context).repo;
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      await repo.savePreferences(prefs);
      navigator.pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showZayaSnack(context, friendlyError(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = _prefs;
    return Scaffold(
      appBar: AppBar(title: const Text('Préférences de découverte')),
      body: SafeArea(
        child: prefs == null
            ? (_error == null
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(children: [
                      Skeleton(height: 90),
                      SizedBox(height: 14),
                      Skeleton(height: 220),
                    ]),
                  )
                : EmptyState(
                    icon: Icons.wifi_off,
                    title: 'Connexion interrompue',
                    message: _error!,
                    action: FilledButton(onPressed: _load, child: const Text('Réessayer')),
                  ))
            : Column(children: [
                Expanded(
                  child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 16), children: [
                    SectionTitle('Âge recherché',
                        trailing: Text('${prefs.ageMin} – ${prefs.ageMax} ans',
                            style: const TextStyle(fontWeight: FontWeight.w700, color: ZColors.primaryDark))),
                    RangeSlider(
                      min: 18,
                      max: 70,
                      divisions: 52,
                      values: RangeValues(prefs.ageMin.toDouble(), prefs.ageMax.toDouble()),
                      labels: RangeLabels('${prefs.ageMin}', '${prefs.ageMax}'),
                      onChanged: (values) => setState(() {
                        prefs.ageMin = values.start.round();
                        prefs.ageMax = values.end.round();
                      }),
                    ),
                    const SizedBox(height: 8),
                    const SectionTitle('Préférence confessionnelle'),
                    for (final e in confessionModeLabels.entries)
                      ChoiceTile(
                        label: e.value,
                        subtitle: e.key == 'mine_only'
                            ? 'S’applique si vous avez indiqué votre confession.'
                            : null,
                        selected: prefs.confessionMode == e.key,
                        onTap: () => setState(() => prefs.confessionMode = e.key),
                      ),
                    if (prefs.confessionMode == 'selected') ...[
                      const SizedBox(height: 4),
                      Wrap(spacing: 8, runSpacing: 4, children: [
                        for (final e in confessionLabels.entries)
                          if (e.key != 'undisclosed')
                            FilterChip(
                              label: Text(e.value),
                              selected: prefs.confessions.contains(e.key),
                              selectedColor: ZColors.primarySoft,
                              checkmarkColor: ZColors.primaryDark,
                              onSelected: (on) => setState(
                                  () => on ? prefs.confessions.add(e.key) : prefs.confessions.remove(e.key)),
                            ),
                      ]),
                    ],
                    const SizedBox(height: 12),
                    const InfoBanner(
                      text: 'Ce filtre agit uniquement sur les profils qui vous sont proposés. Les personnes qui '
                          'n’ont pas précisé leur confession restent proposées : ZAYA ne déduit jamais la confession de quelqu’un.',
                    ),
                    const SizedBox(height: 10),
                    const InfoBanner(
                      icon: Icons.public,
                      text: 'Pays : Guinée. D’autres pays d’Afrique de l’Ouest seront ouverts progressivement.',
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  child: GradientButton(
                    label: 'Enregistrer',
                    busy: _saving,
                    onPressed: prefs.confessionMode == 'selected' && prefs.confessions.isEmpty
                        ? null
                        : () => _save(prefs),
                  ),
                ),
              ]),
      ),
    );
  }
}
