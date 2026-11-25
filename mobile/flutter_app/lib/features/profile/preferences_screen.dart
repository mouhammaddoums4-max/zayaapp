import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/l10n/l10n.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../premium/premium_screens.dart';

/// Préférences de découverte : elles filtrent uniquement les profils proposés au membre.
/// Se ferme en renvoyant `true` si les préférences ont été enregistrées.
class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  DiscoveryPrefs? _prefs;
  List<City> _cities = const <City>[];
  List<EducationLevel> _educationLevels = const <EducationLevel>[];
  String? _error;
  bool _saving = false;

  static const _conakry = 'Conakry — ';

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
      final cities = await repo.cities();
      // Liste administrable (0052) : sans elle, le groupe « Niveau d'études » n'est simplement pas affiché.
      final levels = await repo.educationLevels().catchError((Object _) => const <EducationLevel>[]);
      if (mounted) {
        setState(() {
          _prefs = prefs;
          _cities = cities;
          _educationLevels = levels;
        });
      }
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

  /// Un filtre réservé (CDC §4.4) : l'offre Premium s'ouvre au moment où le membre essaie de s'en servir.
  Future<void> _offerPremium() async {
    await Navigator.of(context).push(zRoute<void>(const PremiumScreen()));
    if (mounted) setState(() {});
  }

  /// Filtres avancés (Premium, migration 0025) : un groupe de puces à choix multiples ; aucun choix = tous.
  /// Sans Premium, les puces portent un cadenas et ouvrent l'offre Premium au lieu de changer le choix.
  Widget _advancedChips(String title, Map<String, String> options, List<String> selected, bool premium) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 10),
      Text(title, style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 4),
      Wrap(spacing: 8, runSpacing: 4, children: [
        for (final e in options.entries)
          FilterChip(
            label: Text(e.value),
            avatar: premium ? null : const Icon(Icons.lock_outline, size: 16, color: ZColors.muted),
            selected: selected.contains(e.key),
            selectedColor: ZColors.primarySoft,
            checkmarkColor: ZColors.primaryDark,
            onSelected: premium
                ? (on) => setState(() => on ? selected.add(e.key) : selected.remove(e.key))
                : (_) => _offerPremium(),
          ),
      ]),
    ]);
  }

  /// Nombre d'enfants au plus (Premium, migration 0052) : un seul choix ; « Peu importe » = pas de filtre.
  Widget _childrenChips(DiscoveryPrefs prefs, bool premium) {
    final s = context.s;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 10),
      Text(s.prefsChildren, style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 4),
      Wrap(spacing: 8, runSpacing: 4, children: [
        for (final max in const <int?>[null, 0, 1, 2, 3])
          ChoiceChip(
            label: Text(max == null ? s.prefsChildrenAny : s.prefsChildrenAtMost(max)),
            avatar: premium || max == null ? null : const Icon(Icons.lock_outline, size: 16, color: ZColors.muted),
            selected: prefs.childrenMax == max,
            selectedColor: ZColors.primarySoft,
            onSelected: premium ? (_) => setState(() => prefs.childrenMax = max) : (_) => _offerPremium(),
          ),
      ]),
    ]);
  }

  List<Widget> _advancedSection(DiscoveryPrefs prefs, bool premium) => [
        const SizedBox(height: 16),
        SectionTitle('Filtres avancés', trailing: premium ? null : const PremiumBadge()),
        Text(
          premium
              ? 'Ils s’ajoutent à vos préférences. Sans choix dans un groupe, tous les profils sont proposés.'
              : 'Avec ZAYA Premium, affinez les profils proposés par langue parlée, projet de mariage, situation '
                  'matrimoniale, niveau d’études et nombre d’enfants.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (!premium && prefs.hasAdvancedFilters) ...[
          const SizedBox(height: 10),
          InfoBanner(
            icon: Icons.info_outline,
            text: 'Vos filtres avancés sont conservés, mais ils ne s’appliquent pas sans ZAYA Premium.',
            action: TextButton(
              onPressed: () => setState(() {
                prefs.languages.clear();
                prefs.horizons.clear();
                prefs.maritalStatuses.clear();
                prefs.educationKeys.clear();
                prefs.childrenMax = null;
              }),
              child: const Text('Les retirer'),
            ),
          ),
        ],
        _advancedChips('Langues parlées', {for (final l in languageOptions) l: l}, prefs.languages, premium),
        _advancedChips('Projet de mariage', horizonLabels, prefs.horizons, premium),
        _advancedChips('Situation matrimoniale', maritalLabels, prefs.maritalStatuses, premium),
        if (_educationLevels.isNotEmpty)
          _advancedChips(
            context.s.prefsEducation,
            {
              for (final l in _educationLevels) l.key: l.label(LanguageScope.maybeOf(context)?.language.code ?? 'fr'),
            },
            prefs.educationKeys,
            premium,
          ),
        _childrenChips(prefs, premium),
        if (!premium) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _offerPremium,
            icon: const Icon(Icons.workspace_premium_outlined),
            label: const Text('Découvrir ZAYA Premium'),
          ),
        ],
      ];

  /// Choix des villes : « Toutes », raccourci « Tout Conakry », communes de Conakry puis autres villes.
  Widget _cityChips(DiscoveryPrefs prefs) {
    final communes = [
      for (final c in _cities)
        if (c.name.startsWith(_conakry)) c
    ];
    final autres = [
      for (final c in _cities)
        if (!c.name.startsWith(_conakry)) c
    ];
    final toutConakry = communes.isNotEmpty && communes.every((c) => prefs.cityIds.contains(c.id));
    Widget chip(String label, bool selected, VoidCallback onTap) => FilterChip(
          label: Text(label),
          selected: selected,
          selectedColor: ZColors.primarySoft,
          checkmarkColor: ZColors.primaryDark,
          onSelected: (_) => setState(onTap),
        );
    void basculer(City c) => prefs.cityIds.contains(c.id) ? prefs.cityIds.remove(c.id) : prefs.cityIds.add(c.id);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 4, children: [
        chip('Toutes', prefs.cityIds.isEmpty, prefs.cityIds.clear),
        if (communes.isNotEmpty)
          chip('Tout Conakry', toutConakry, () {
            if (toutConakry) {
              prefs.cityIds.removeWhere((id) => communes.any((c) => c.id == id));
            } else {
              for (final c in communes) {
                if (!prefs.cityIds.contains(c.id)) prefs.cityIds.add(c.id);
              }
            }
          }),
      ]),
      if (communes.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text('Communes de Conakry', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (final c in communes)
            chip(c.name.substring(_conakry.length), prefs.cityIds.contains(c.id), () => basculer(c)),
        ]),
      ],
      if (autres.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text('Autres villes', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (final c in autres) chip(c.name, prefs.cityIds.contains(c.id), () => basculer(c)),
        ]),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final prefs = _prefs;
    final premium = Session.of(context).me?.isPremium ?? false;
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
                    if (_cities.isNotEmpty) ...[
                      SectionTitle('Ville ou commune',
                          trailing: Text(
                              prefs.cityIds.isEmpty
                                  ? 'Toutes'
                                  : prefs.cityIds.length == 1
                                      ? '1 choisie'
                                      : '${prefs.cityIds.length} choisies',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: ZColors.primaryDark))),
                      _cityChips(prefs),
                      const SizedBox(height: 12),
                    ],
                    const SectionTitle('Préférence confessionnelle'),
                    for (final e in confessionModeLabels.entries)
                      ChoiceTile(
                        label: e.value,
                        subtitle: e.key == 'mine_only' ? 'S’applique si vous avez indiqué votre confession.' : null,
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
                              onSelected: (on) =>
                                  setState(() => on ? prefs.confessions.add(e.key) : prefs.confessions.remove(e.key)),
                            ),
                      ]),
                    ],
                    ..._advancedSection(prefs, premium),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  child: GradientButton(
                    label: 'Enregistrer',
                    busy: _saving,
                    onPressed:
                        prefs.confessionMode == 'selected' && prefs.confessions.isEmpty ? null : () => _save(prefs),
                  ),
                ),
              ]),
      ),
    );
  }
}
