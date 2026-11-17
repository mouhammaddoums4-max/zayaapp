import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';

/// Modification du profil : présentation, projet de mariage, situation, langues et centres d'intérêt.
/// Tous ces champs sont facultatifs et modifiables à tout moment.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const _maxInterests = 6;

  final _bio = TextEditingController();
  String? _horizon;
  String? _maritalStatus;
  Set<String> _languages = <String>{};
  Set<String> _interests = <String>{};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final me = Session.read(context).me;
    if (me != null) {
      _bio.text = me.bio ?? '';
      _horizon = me.horizon;
      _maritalStatus = me.maritalStatus;
      _languages = me.languages.toSet();
      _interests = me.interests.toSet();
    }
  }

  @override
  void dispose() {
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final session = Session.read(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      await session.repo.updateProfile(
        bio: _bio.text,
        horizon: _horizon,
        maritalStatus: _maritalStatus,
        languages: _languages.toList(),
        interests: _interests.toList(),
      );
      await session.refresh();
      if (!mounted) return;
      showZayaSnack(context, 'Profil mis à jour.');
      navigator.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showZayaSnack(context, friendlyError(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modifier mon profil')),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 16), children: [
              const SectionTitle('Présentation'),
              TextField(
                controller: _bio,
                maxLines: 5,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Parlez de vous, de vos valeurs et de ce que vous recherchez.',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              const SectionTitle('Projet de mariage'),
              ZPickerField<String>(
                label: 'Horizon envisagé',
                options: horizonLabels,
                value: _horizon,
                onChanged: (v) => setState(() => _horizon = v),
              ),
              const SizedBox(height: 14),
              ZPickerField<String>(
                label: 'Situation matrimoniale (facultatif)',
                options: maritalLabels,
                value: _maritalStatus,
                onChanged: (v) => setState(() => _maritalStatus = v),
              ),
              const SizedBox(height: 14),
              const SectionTitle('Langues parlées'),
              Wrap(spacing: 8, runSpacing: 4, children: [
                for (final language in languageOptions)
                  FilterChip(
                    label: Text(language),
                    selected: _languages.contains(language),
                    selectedColor: ZColors.primarySoft,
                    checkmarkColor: ZColors.primaryDark,
                    onSelected: (on) =>
                        setState(() => on ? _languages.add(language) : _languages.remove(language)),
                  ),
              ]),
              const SizedBox(height: 14),
              SectionTitle('Centres d’intérêt',
                  trailing: Text('${_interests.length} / $_maxInterests', style: Theme.of(context).textTheme.bodyMedium)),
              Wrap(spacing: 8, runSpacing: 4, children: [
                for (final interest in interestOptions)
                  FilterChip(
                    label: Text(interest),
                    selected: _interests.contains(interest),
                    selectedColor: ZColors.primarySoft,
                    checkmarkColor: ZColors.primaryDark,
                    onSelected: (on) {
                      if (on && _interests.length >= _maxInterests) {
                        showZayaSnack(context, 'Vous pouvez choisir jusqu’à $_maxInterests centres d’intérêt.');
                        return;
                      }
                      setState(() => on ? _interests.add(interest) : _interests.remove(interest));
                    },
                  ),
              ]),
              const SizedBox(height: 18),
              const InfoBanner(
                text: 'Pour corriger votre prénom, votre date de naissance ou votre genre, contactez l’assistance : '
                    'ces informations ne se modifient pas librement après l’inscription.',
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: GradientButton(label: 'Enregistrer', busy: _saving, onPressed: _save),
          ),
        ]),
      ),
    );
  }
}
