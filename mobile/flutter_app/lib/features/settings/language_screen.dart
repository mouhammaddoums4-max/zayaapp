import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/l10n/l10n.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'settings_widgets.dart';
import 'support_screens.dart';

/// Langue de l'interface (CARTE_ECRANS F14, cahier des charges §22.15).
/// Une langue est proposée si elle est entièrement traduite dans l'application **et** activée par
/// l'administration (`app_config.active_languages`, §22.16). Les autres restent visibles, « bientôt disponibles ».
class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  /// Codes activés côté serveur ; `null` tant que la configuration n'est pas lue (on n'empêche rien).
  Set<String>? _active;

  @override
  void initState() {
    super.initState();
    _loadActive();
  }

  Future<void> _loadActive() async {
    try {
      final config = await Session.read(context).repo.publicConfig();
      final value = config['active_languages'];
      if (!mounted || value is! List) return;
      setState(() => _active = {for (final v in value) v.toString()});
    } catch (_) {
      // Sans configuration lisible, seules les langues traduites comptent.
    }
  }

  bool _available(AppLanguage l) => l.isTranslated && (_active == null || _active!.contains(l.code));

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final controller = LanguageScope.of(context);
    final current = controller.language;

    return Scaffold(
      appBar: AppBar(title: Text(s.languageTitle)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 28), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
          child: Text(s.languageIntro, style: Theme.of(context).textTheme.bodyLarge),
        ),
        SettingsGroup(children: [
          for (final l in AppLanguage.values)
            _LanguageTile(
              language: l,
              localName: s.languageName(l),
              selected: l == current,
              available: _available(l),
              unavailableLabel: l == AppLanguage.en ? s.languageComingSoon : s.languageInPreparation,
              onTap: () async {
                await controller.select(l);
                if (context.mounted) showZayaSnack(context, LanguageController.stringsFor(l).languageChanged);
              },
            ),
        ]),
        const SizedBox(height: 22),
        Text(s.languageReportTitle, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.flag_outlined, size: 20),
          label: Text(s.languageReportButton),
          onPressed: () =>
              Navigator.of(context).push(zRoute<void>(const SupportRequestScreen(initialCategory: 'translation'))),
        ),
      ]),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.language,
    required this.localName,
    required this.selected,
    required this.available,
    required this.unavailableLabel,
    required this.onTap,
  });

  final AppLanguage language;
  final String localName;
  final bool selected;
  final bool available;
  final String unavailableLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sameName = localName == language.nativeName;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: SettingsTile(
        icon: selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        title: language.nativeName,
        subtitle: available
            ? (sameName ? null : localName)
            : (sameName ? unavailableLabel : '$localName · $unavailableLabel'),
        enabled: available || selected,
        trailing: selected ? const Icon(Icons.check, color: ZColors.primary) : const SizedBox.shrink(),
        onTap: available && !selected ? onTap : null,
      ),
    );
  }
}
