import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app.dart';
import '../../core/l10n/l10n.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'help_content.dart';
import 'settings_widgets.dart';
import 'support_screens.dart';

/// Aide et assistance (CARTE_ECRANS F12) : questions fréquentes, demandes à l'assistance, parcours sécurité
/// prioritaire. Le bouton WhatsApp n'apparaît que si `app_config.support_whatsapp` est renseigné (décision C9).
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  String? _whatsapp;
  Future<List<HelpSection>>? _sections;
  String? _lang;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = LanguageScope.maybeOf(context)?.language.code ?? 'fr';
    if (lang != _lang) {
      _lang = lang;
      _sections = HelpContent.forRepository(Session.read(context).repo).sections(lang);
    }
  }

  void _reloadFaq() {
    final next = HelpContent.forRepository(Session.read(context).repo).sections(_lang ?? 'fr');
    setState(() {
      _sections = next;
    });
  }

  Future<void> _loadConfig() async {
    try {
      final config = await Session.read(context).repo.publicConfig();
      final number = (config['support_whatsapp'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
      if (mounted && number.isNotEmpty) setState(() => _whatsapp = number);
    } catch (_) {
      // Sans configuration, l'assistance reste joignable par les demandes dans l'application.
    }
  }

  Future<void> _push(Widget screen) => Navigator.of(context).push(zRoute<void>(screen));

  Future<void> _openWhatsapp(String number) async {
    final ok = await launchUrl(Uri.parse('https://wa.me/$number'), mode: LaunchMode.externalApplication);
    if (!ok && mounted) showZayaSnack(context, context.s.loadError, error: true);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final whatsapp = _whatsapp;
    return Scaffold(
      appBar: AppBar(title: Text(s.helpTitle)),
      body: ListView(padding: EdgeInsets.fromLTRB(16, 8, 16, 28 + MediaQuery.paddingOf(context).bottom), children: [
        _SafetyCard(onReport: () => _push(const SupportRequestScreen(initialCategory: 'safety'))),
        SettingsSectionTitle(s.helpFaqTitle),
        FutureBuilder<List<HelpSection>>(
          future: _sections,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.hasError) {
              return InfoBanner(
                tone: BannerTone.warning,
                icon: Icons.wifi_off,
                text: s.loadError,
                action: TextButton(onPressed: _reloadFaq, child: Text(s.retry)),
              );
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final section in snapshot.data ?? const <HelpSection>[]) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
                  child: Text(section.title, style: Theme.of(context).textTheme.titleMedium),
                ),
                SettingsGroup(children: [
                  for (final item in section.articles)
                    ExpansionTile(
                      shape: const Border(),
                      collapsedShape: const Border(),
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      expandedAlignment: Alignment.centerLeft,
                      title: Text(item.question,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                      children: [Text(item.answer, style: Theme.of(context).textTheme.bodyMedium)],
                    ),
                ]),
                const SizedBox(height: 10),
              ],
            ]);
          },
        ),
        SettingsSectionTitle(s.helpContactTitle),
        SettingsGroup(children: [
          SettingsTile(
            icon: Icons.support_agent,
            title: s.helpWriteSupport,
            subtitle: s.helpWriteSupportSubtitle,
            onTap: () => _push(const SupportRequestScreen()),
          ),
          SettingsTile(
            icon: Icons.inbox_outlined,
            title: s.helpMyRequests,
            subtitle: s.helpMyRequestsSubtitle,
            onTap: () => _push(const MyRequestsScreen()),
          ),
          if (whatsapp != null)
            SettingsTile(
              icon: Icons.chat_outlined,
              title: s.helpWhatsapp,
              subtitle: s.helpWhatsappSubtitle,
              trailing: const Icon(Icons.open_in_new, size: 18, color: ZColors.muted),
              onTap: () => _openWhatsapp(whatsapp),
            ),
        ]),
      ]),
    );
  }
}

class _SafetyCard extends StatelessWidget {
  const _SafetyCard({required this.onReport});
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZColors.danger.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ZColors.danger.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.health_and_safety_outlined, color: ZColors.danger),
          const SizedBox(width: 10),
          Expanded(child: Text(s.helpSafetyTitle, style: Theme.of(context).textTheme.titleMedium)),
        ]),
        const SizedBox(height: 8),
        Text(s.helpSafetyBody, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 6),
        Text(s.helpEmergency, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: ZColors.danger),
            icon: const Icon(Icons.flag_outlined, size: 20),
            label: Text(s.helpSafetyButton),
            onPressed: onReport,
          ),
        ),
      ]),
    );
  }
}
