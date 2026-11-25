import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../discovery/profile_detail_screen.dart';
import '../discovery/profile_widgets.dart';
import 'zaya2_api.dart';

/// Pulse : nouveaux membres vérifiés qui ont accepté d'y figurer, et chiffres réels de la communauté.
/// Apparaître dans Pulse est désactivé par défaut ; aucune activité n'est inventée.
class PulseScreen extends StatefulWidget {
  const PulseScreen({super.key});

  @override
  State<PulseScreen> createState() => _PulseScreenState();
}

class _PulseScreenState extends State<PulseScreen> {
  late final Zaya2Api _api = Zaya2Api.of(context);
  late Future<PulseFeed> _feed = _api.pulse();
  bool _saving = false;

  Future<void> _toggle(bool on) async {
    setState(() => _saving = true);
    try {
      await _api.setPulseOptIn(on);
      if (!mounted) return;
      setState(() {
        _feed = _api.pulse();
      });
      showZayaSnack(
          context,
          on
              ? tr(context, 'Vous pouvez apparaître dans Pulse.', 'You can now appear in Pulse.')
              : tr(context, 'Vous n’apparaissez plus dans Pulse.', 'You no longer appear in Pulse.'));
    } catch (e) {
      if (mounted) showZayaSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Pulse')),
        body: FutureBuilder<PulseFeed>(
          future: _feed,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return ListView(padding: const EdgeInsets.all(16), children: const [
                Skeleton(height: 120),
                SizedBox(height: 16),
                Skeleton(height: 220),
              ]);
            }
            if (snap.hasError) {
              return EmptyState(
                icon: Icons.wifi_off,
                title: tr(context, 'Connexion interrompue', 'Connection lost'),
                message: friendlyError(snap.error!),
                action: FilledButton(
                  onPressed: () => setState(() {
                    _feed = _api.pulse();
                  }),
                  child: Text(tr(context, 'Réessayer', 'Try again')),
                ),
              );
            }
            final f = snap.data!;
            if (f.status == 'disabled') {
              return EmptyState(
                icon: Icons.bolt_rounded,
                title: tr(context, 'Pulse est en pause', 'Pulse is paused'),
                message: tr(context, 'Revenez un peu plus tard.', 'Please come back later.'),
              );
            }
            return RefreshIndicator(
              color: ZColors.primary,
              onRefresh: () async {
                setState(() {
                  _feed = _api.pulse();
                });
                await _feed;
              },
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
                FadeSlideIn(
                  // Surface Material (et non une décoration) : l'effet d'appui de l'interrupteur reste visible.
                  child: Material(
                    color: Colors.white,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: ZColors.line),
                    ),
                    child: SwitchListTile(
                      value: f.optedIn,
                      onChanged: _saving ? null : _toggle,
                      activeThumbColor: ZColors.primary,
                      title: Text(tr(context, 'Apparaître dans Pulse', 'Appear in Pulse'),
                          style: Theme.of(context).textTheme.titleSmall),
                      subtitle: Text(tr(
                          context,
                          'Désactivé par défaut. Si vous l’activez, votre prénom, votre âge, votre ville et votre photo '
                              'principale peuvent être montrés aux membres de votre pays pendant vos 14 premiers jours. '
                              'Vous pouvez le retirer à tout moment.',
                          'Off by default. If you turn it on, your first name, age, city and main photo may be shown to '
                              'members in your country during your first 14 days. You can turn it off at any time.')),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                FadeSlideIn(index: 1, child: SectionTitle(tr(context, 'Nouveaux membres', 'New members'))),
                if (f.members.isEmpty)
                  InfoBanner(
                    text: tr(context, 'Aucun nouveau membre vérifié n’a choisi d’apparaître ici pour le moment.',
                        'No new verified member has chosen to appear here yet.'),
                  )
                else
                  SizedBox(
                    height: 168,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: f.members.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, i) {
                        final m = f.members[i];
                        return FadeSlideIn(
                          index: i,
                          child: PressScale(
                            onTap: () => Navigator.of(context)
                                .push(zRoute<void>(ProfileDetailScreen(userId: m.userId, name: m.name))),
                            child: SizedBox(
                              width: 112,
                              child: Column(children: [
                                RemoteAvatar(name: m.name, photoPath: m.photoPath, size: 96),
                                const SizedBox(height: 8),
                                Text('${m.name}, ${m.age}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                                if (m.city != null)
                                  Text(m.city!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context).textTheme.bodyMedium),
                              ]),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 18),
                FadeSlideIn(
                    index: 2, child: SectionTitle(tr(context, 'La communauté en chiffres', 'Community figures'))),
                if (f.stats.isEmpty)
                  InfoBanner(
                    text: tr(
                        context,
                        'Les chiffres apparaîtront quand chaque groupe comptera assez de membres pour ne désigner personne.',
                        'Figures will appear once each group has enough members not to identify anyone.'),
                  )
                else
                  for (final (i, s) in f.stats.indexed)
                    FadeSlideIn(
                      index: 3 + i,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: ZColors.line),
                        ),
                        child: Row(children: [
                          const Icon(Icons.location_city_rounded, color: ZColors.primaryDark),
                          const SizedBox(width: 12),
                          Expanded(child: Text(s.city, style: Theme.of(context).textTheme.titleSmall)),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text(tr(context, '${s.members} membres', '${s.members} members'),
                                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                            Text(
                                tr(context, '${s.activeThisWeek} actifs cette semaine',
                                    '${s.activeThisWeek} active this week'),
                                style: Theme.of(context).textTheme.bodyMedium),
                          ]),
                        ]),
                      ),
                    ),
              ]),
            );
          },
        ),
      );
}
