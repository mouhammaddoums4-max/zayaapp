import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../discovery/profile_detail_screen.dart';
import '../discovery/profile_widgets.dart';
import 'invitation_screen.dart';
import 'pulse_screen.dart';
import 'questions_screen.dart';
import 'zaya2_api.dart';

/// Carte d'accès à ZAYA+ (profil) : Match du jour, surprise, défis, Pulse, questions et invitations.
class Zaya2EntryCard extends StatelessWidget {
  const Zaya2EntryCard({super.key});

  @override
  Widget build(BuildContext context) => PressScale(
        onTap: () => Navigator.of(context).push(zRoute<void>(const ZayaHubScreen())),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(gradient: ZColors.brandGradient, borderRadius: BorderRadius.circular(18)),
          child: Row(children: [
            const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('ZAYA+', style: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 2),
                Text(
                    tr(context, 'Match du jour, surprise, défis, Pulse et questions',
                        'Daily match, surprise, challenges, Pulse and questions'),
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.92))),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ]),
        ),
      );
}

/// ZAYA+ : la suggestion du jour, la surprise, les défis et l'accès aux espaces de la communauté.
/// Tout ce qui est affiché vient du serveur ; une fonction coupée par l'administration disparaît d'elle-même.
class ZayaHubScreen extends StatefulWidget {
  const ZayaHubScreen({super.key});

  @override
  State<ZayaHubScreen> createState() => _ZayaHubScreenState();
}

class _ZayaHubScreenState extends State<ZayaHubScreen> {
  late final Zaya2Api _api = Zaya2Api.of(context);
  late Future<DailyMatch> _match;
  late Future<(String, List<ChallengeItem>)> _challenges;
  Future<List<SurpriseOdd>>? _odds;
  SurpriseResult? _surprise;
  bool _opening = false;
  bool _acting = false;
  Map<String, Object?> _config = const <String, Object?>{};

  @override
  void initState() {
    super.initState();
    _match = _api.dailyMatch();
    _challenges = _api.challenges();
    _odds = _api.surpriseOdds();
    _api.registerDevice();
    _api.repo.publicConfig().then((c) {
      if (mounted) setState(() => _config = c);
    }, onError: (_) {});
  }

  /// Bloc affiché seulement si le serveur déclare la fonction active (interrupteur présent et vrai).
  bool _on(String feature) =>
      (_config['feature_${feature}_enabled'] ??
          Session.read(context).publicConfigCache['feature_${feature}_enabled']) ==
      true;

  Future<void> _reload() async {
    setState(() {
      _match = _api.dailyMatch();
      _challenges = _api.challenges();
    });
    await Future.wait<Object?>([_match, _challenges]);
  }

  Future<void> _openSurprise() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final r = await _api.openSurprise();
      if (mounted) setState(() => _surprise = r);
      if (r.amount > 0 && mounted) Session.read(context).feed.load();
    } catch (e) {
      if (mounted) showZayaSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _likeOrPass(DiscoveryProfile p, {required bool like}) async {
    if (_acting) return;
    setState(() => _acting = true);
    final repo = _api.repo;
    try {
      if (like) {
        final r = await repo.like(p.id);
        if (!mounted) return;
        switch (r.status) {
          case LikeStatus.matched:
            showZayaSnack(
                context, tr(context, 'C’est un match avec ${p.displayName} !', 'It’s a match with ${p.displayName}!'));
          case LikeStatus.quotaReached:
            showZayaSnack(context, tr(context, 'Plus de swipes pour le moment.', 'No swipes left for now.'),
                error: true);
          case LikeStatus.liked:
          case LikeStatus.alreadyLiked:
            showZayaSnack(
                context, tr(context, 'Intérêt envoyé à ${p.displayName}.', 'Interest sent to ${p.displayName}.'));
        }
      } else {
        await repo.pass(p.id);
      }
      if (mounted) {
        setState(() {
          _match = _api.dailyMatch();
        });
      }
    } catch (e) {
      if (mounted) showZayaSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _claim(ChallengeItem c) async {
    try {
      final reward = await _api.claimChallenge(c.code);
      if (!mounted) return;
      showZayaSnack(
          context,
          reward > 0
              ? tr(context, 'Défi validé : +$reward swipes', 'Challenge completed: +$reward swipes')
              : tr(context, 'Défi validé, bravo !', 'Challenge completed, well done!'));
      setState(() {
        _challenges = _api.challenges();
      });
    } catch (e) {
      if (mounted) showZayaSnack(context, friendlyError(e), error: true);
    }
  }

  void _push(Widget screen) => Navigator.of(context).push(zRoute<void>(screen));

  @override
  Widget build(BuildContext context) {
    var i = 0;
    return Scaffold(
      appBar: AppBar(title: const Text('ZAYA+')),
      body: RefreshIndicator(
        color: ZColors.primary,
        onRefresh: _reload,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
          if (_on('match_of_day')) ...[
            FadeSlideIn(index: i++, child: SectionTitle(tr(context, 'Match du jour', 'Daily match'))),
            FadeSlideIn(index: i++, child: _dailyMatch()),
            const SizedBox(height: 18),
          ],
          if (_on('surprise')) ...[
            FadeSlideIn(index: i++, child: SectionTitle(tr(context, 'Surprise du jour', 'Today’s surprise'))),
            FadeSlideIn(index: i++, child: _surpriseCard()),
            const SizedBox(height: 18),
          ],
          if (_on('challenge')) ...[
            FadeSlideIn(index: i++, child: SectionTitle(tr(context, 'Défis du jour', 'Today’s challenges'))),
            FadeSlideIn(index: i++, child: _challengesCard()),
            const SizedBox(height: 18),
          ],
          FadeSlideIn(index: i++, child: SectionTitle(tr(context, 'Communauté', 'Community'))),
          if (_on('pulse'))
            _HubTile(
              icon: Icons.bolt_rounded,
              title: 'Pulse',
              subtitle: tr(context, 'Nouveaux membres et chiffres réels de la communauté',
                  'New members and real community figures'),
              onTap: () => _push(const PulseScreen()),
            ),
          if (_on('questions'))
            _HubTile(
              icon: Icons.forum_outlined,
              title: tr(context, 'Mieux se connaître', 'Get to know each other'),
              subtitle: tr(context, 'Vos réponses sur le mariage, visibles par qui vous choisissez',
                  'Your answers about marriage, visible to whom you choose'),
              onTap: () => _push(const QuestionsScreen()),
            ),
          if (_on('invitation'))
            _HubTile(
              icon: Icons.person_add_alt_1_rounded,
              title: tr(context, 'Inviter un proche', 'Invite someone'),
              subtitle: tr(context, 'Votre code personnel d’invitation', 'Your personal invitation code'),
              onTap: () => _push(const InvitationScreen()),
            ),
        ]),
      ),
    );
  }

  Widget _dailyMatch() => FutureBuilder<DailyMatch>(
        future: _match,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Skeleton(height: 380, radius: 22);
          if (snap.hasError) {
            return InfoBanner(icon: Icons.wifi_off, text: friendlyError(snap.error!));
          }
          final m = snap.data!;
          if (m.status == 'done') {
            return InfoBanner(
              icon: Icons.check_circle_outline,
              text: tr(context, 'Vous avez répondu à la suggestion du jour. Une nouvelle vous attend demain.',
                  'You answered today’s suggestion. A new one awaits you tomorrow.'),
            );
          }
          final p = m.profile;
          if (!m.ready || p == null) {
            return InfoBanner(
              icon: Icons.hourglass_empty_rounded,
              text: tr(
                  context,
                  'Pas de suggestion aujourd’hui : aucun profil vérifié ne correspond encore à vos préférences.',
                  'No suggestion today: no verified profile matches your preferences yet.'),
            );
          }
          return _DailyMatchCard(
            profile: p,
            shared: m.sharedInterests,
            busy: _acting,
            onLike: () => _likeOrPass(p, like: true),
            onPass: () => _likeOrPass(p, like: false),
            onOpen: () => _push(ProfileDetailScreen(userId: p.id, name: p.displayName)),
          );
        },
      );

  Widget _surpriseCard() {
    final s = _surprise;
    final Widget body;
    if (s == null) {
      body = Column(key: const ValueKey('closed'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const _GiftIcon(),
          const SizedBox(width: 14),
          Expanded(
            child: Text(tr(context, 'Une surprise vous attend chaque jour. Le tirage est fait par le serveur.',
                'A surprise awaits you every day. The draw is made by the server.')),
          ),
        ]),
        const SizedBox(height: 12),
        FutureBuilder<List<SurpriseOdd>>(
          future: _odds,
          builder: (context, snap) {
            final odds = snap.data ?? const <SurpriseOdd>[];
            if (odds.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                '${tr(context, 'Chances réelles', 'Real odds')} : ${odds.map((o) => '${tr(context, o.labelFr, o.labelEn)}${o.amount > 0 ? ' (${o.amount})' : ''} ${o.percent.toStringAsFixed(o.percent % 1 == 0 ? 0 : 1)} %').join(' · ')}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          },
        ),
        FilledButton.icon(
          onPressed: _opening ? null : _openSurprise,
          icon: const Icon(Icons.redeem_rounded),
          label: Text(tr(context, 'Ouvrir la surprise', 'Open the surprise')),
        ),
      ]);
    } else if (!s.opened) {
      body = Text(
        key: const ValueKey('none'),
        switch (s.status) {
          'not_eligible' => tr(context, 'La surprise du jour est réservée aux profils vérifiés.',
              'The daily surprise is for verified profiles.'),
          'disabled' =>
            tr(context, 'La surprise est momentanément indisponible.', 'The surprise is unavailable for now.'),
          _ => tr(context, 'Pas de surprise disponible aujourd’hui.', 'No surprise available today.'),
        },
      );
    } else if (s.prize == 'swipes') {
      body = Row(key: const ValueKey('swipes'), children: [
        const _GiftIcon(open: true),
        const SizedBox(width: 14),
        Expanded(
          child: Text(tr(context, '+${s.amount} swipes offerts aujourd’hui.', '+${s.amount} free swipes today.'),
              style: Theme.of(context).textTheme.titleMedium),
        ),
      ]);
    } else {
      body = Column(key: const ValueKey('question'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const _GiftIcon(open: true),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              tr(context, 'Votre surprise : une question pour mieux vous connaître.',
                  'Your surprise: a question to know yourself better.'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ]),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => _push(QuestionsScreen(focusQuestionId: s.questionId)),
          child: Text(tr(context, 'Répondre', 'Answer')),
        ),
      ]);
    }
    return _Panel(
      child: AnimatedSwitcher(
        duration: ZMotion.of(context, ZMotion.slow),
        switchInCurve: ZMotion.spring,
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: ScaleTransition(scale: Tween<double>(begin: 0.92, end: 1).animate(a), child: child),
        ),
        child: body,
      ),
    );
  }

  Widget _challengesCard() => FutureBuilder<(String, List<ChallengeItem>)>(
        future: _challenges,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Skeleton(height: 150, radius: 18);
          if (snap.hasError) return InfoBanner(icon: Icons.wifi_off, text: friendlyError(snap.error!));
          final (status, items) = snap.data!;
          if (status != 'ready' || items.isEmpty) {
            return InfoBanner(text: tr(context, 'Aucun défi pour le moment.', 'No challenge for now.'));
          }
          return _Panel(
            child: Column(children: [
              for (final c in items) ...[
                _ChallengeRow(item: c, onClaim: () => _claim(c)),
                if (c != items.last) const Divider(height: 22),
              ],
            ]),
          );
        },
      );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ZColors.line),
        ),
        child: child,
      );
}

class _GiftIcon extends StatelessWidget {
  const _GiftIcon({this.open = false});
  final bool open;

  @override
  Widget build(BuildContext context) => Container(
        width: 52,
        height: 52,
        decoration: const BoxDecoration(gradient: ZColors.brandGradient, shape: BoxShape.circle),
        child: Icon(open ? Icons.celebration_rounded : Icons.card_giftcard_rounded, color: Colors.white, size: 26),
      );
}

class _DailyMatchCard extends StatelessWidget {
  const _DailyMatchCard({
    required this.profile,
    required this.shared,
    required this.busy,
    required this.onLike,
    required this.onPass,
    required this.onOpen,
  });
  final DiscoveryProfile profile;
  final int shared;
  final bool busy;
  final VoidCallback onLike;
  final VoidCallback onPass;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PressScale(
        onTap: onOpen,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(
            height: 340,
            child: Stack(fit: StackFit.expand, children: [
              ProfilePhotoView(name: p.displayName, photoPath: p.photoPath),
              const PhotoScrim(start: 0.45),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(
                      child: Text('${p.displayName}, ${p.age}',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.sora(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                    const SizedBox(width: 6),
                    const VerifiedBadge(size: 20),
                  ]),
                  if (p.city != null)
                    Text(p.city!, style: GoogleFonts.inter(fontSize: 14, color: Colors.white.withValues(alpha: 0.9))),
                  if (shared > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(99)),
                      child: Text(
                        tr(context, '$shared centre${shared > 1 ? 's' : ''} d’intérêt en commun',
                            '$shared shared interest${shared > 1 ? 's' : ''}'),
                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                  ],
                ]),
              ),
            ]),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        tr(context, 'Suggestion basée sur vos préférences : ce n’est pas une garantie de compatibilité.',
            'Suggestion based on your preferences: it is not a guarantee of compatibility.'),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: busy ? null : onPass,
            child: Text(tr(context, 'Passer', 'Pass')),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: busy ? null : onLike,
            icon: const Icon(Icons.favorite_rounded),
            label: Text(tr(context, 'J’aime', 'Like')),
          ),
        ),
      ]),
    ]);
  }
}

class _ChallengeRow extends StatelessWidget {
  const _ChallengeRow({required this.item, required this.onClaim});
  final ChallengeItem item;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final c = item;
    final ratio = c.target == 0 ? 0.0 : (c.progress / c.target).clamp(0.0, 1.0);
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr(context, c.titleFr, c.titleEn), style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: ratio),
              duration: ZMotion.of(context, ZMotion.slow),
              curve: ZMotion.emphasized,
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 6,
                backgroundColor: ZColors.line,
                color: ZColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${c.progress}/${c.target}${c.reward > 0 ? ' · +${c.reward} swipes' : ''}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ]),
      ),
      const SizedBox(width: 12),
      if (c.claimed)
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.check_circle_rounded, color: ZColors.success, size: 20),
          const SizedBox(width: 4),
          Text(tr(context, 'Validé', 'Done'),
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: ZColors.success)),
        ])
      else
        FilledButton(
          style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 16)),
          onPressed: c.completed ? onClaim : null,
          child: Text(tr(context, 'Valider', 'Claim')),
        ),
    ]);
  }
}

class _HubTile extends StatelessWidget {
  const _HubTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: PressScale(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ZColors.line),
            ),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: ZColors.primarySoft, shape: BoxShape.circle),
                child: Icon(icon, color: ZColors.primaryDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded, color: ZColors.muted),
            ]),
          ),
        ),
      );
}
