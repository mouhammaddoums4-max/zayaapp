import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app.dart';
import '../../core/l10n/l10n.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import 'profile_widgets.dart' show zayaPhoto;
import '../ads/google_ads.dart';
import '../boost/boost_button.dart';
import '../notifications/notifications_screen.dart';
import '../premium/premium_screens.dart';
import '../profile/preferences_screen.dart';
import '../profile/verification_screen.dart';
import '../safety/safety_sheets.dart';
import 'like_actions.dart';
import 'profile_sections.dart';
import 'radar_search.dart';
import 'swipe_buttons.dart';

/// Durée minimale de la recherche animée à la première ouverture de l'onglet.
const _radarMinimum = Duration(milliseconds: 1500);

/// Hauteur de l'en-tête posé sur la photo (sous la barre d'état).
const double _topBarHeight = 56;

/// Place réservée en bas de la carte aux boutons d'action.
const double _actionsHeight = 100;

/// Rayon des coins bas de la carte (la carte occupe toute la largeur, sous la barre d'état).
const double _cardRadius = 28;

/// Barre d'état à icônes claires (sur la photo) ; la barre de navigation garde ses icônes sombres (barre d'onglets
/// blanche en dessous).
final _statusOnPhoto = zSystemUi.copyWith(
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
);

/// Onglet Mariage (découverte) : une carte de profil à la fois, en plein écran. On glisse à droite pour aimer, à
/// gauche pour passer ; on fait défiler la carte vers le haut (ou on touche la flèche) pour lire tout le profil, sans
/// quitter l'écran ; un toucher sur la photo passe à la suivante. Les boutons du bas offrent les mêmes actions sans
/// geste, plus le retour au profil précédent et le Boost ; ils réagissent au glissement de la carte.
class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _fly = AnimationController(vsync: this, duration: ZMotion.medium);

  /// Position de la carte du dessus. Un `ValueNotifier` plutôt que `setState` : pendant le geste, seules les
  /// transformations des deux cartes (et les boutons) sont recalculées, pas tout l'écran.
  final ValueNotifier<Offset> _drag = ValueNotifier<Offset>(Offset.zero);

  /// Profil dont la carte est en cours de lecture (défilée vers le haut) : tant que c'est la carte du dessus,
  /// l'en-tête de l'onglet s'efface au profit de celui de la carte (prénom et flèche pour revenir à la photo).
  final ValueNotifier<String?> _readingId = ValueNotifier<String?>(null);
  Offset _from = Offset.zero;
  Offset _to = Offset.zero;
  bool _acting = false;
  late final FeedStore _feed;

  /// Profils dont la photo a déjà été préparée à l'avance.
  final Set<String> _prefetched = <String>{};

  /// Profils dont la visite a déjà été comptée pendant cette session.
  final Set<String> _viewed = <String>{};

  /// Un filtre s'écarte des réglages par défaut : point sur l'icône des filtres.
  bool _filtersActive = false;

  /// Recherche animée (radar) : affichée au moins [_radarMinimum] à la première ouverture, puis tant que le fil
  /// charge. Sans animation (réglage système), elle ne retarde pas l'affichage des profils.
  Timer? _radarTimer;
  bool _radarElapsed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_radarTimer == null && !_radarElapsed) {
      if (ZMotion.reduced(context)) {
        _radarElapsed = true;
      } else {
        _radarTimer = Timer(_radarMinimum, () {
          if (mounted) setState(() => _radarElapsed = true);
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _fly.addListener(_onFly);
    _feed = Session.read(context).feed;
    _feed.addListener(_prefetchAhead);
    // Après la première image, pour ne pas notifier les écouteurs pendant la construction.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_feed.loaded && !_feed.loading) {
        _feed.load();
      } else {
        _prefetchAhead();
      }
    });
    _refreshFiltersState();
  }

  /// Prépare la photo des deux profils qui suivent la carte de derrière (URL signée + image décodée),
  /// pour qu'une carte qui avance s'affiche déjà prête au lieu d'apparaître sur un fond provisoire.
  /// Les deux premières cartes sont affichées, donc déjà chargées par leur propre widget.
  void _prefetchAhead() {
    if (!mounted) return;
    final repo = Session.read(context).repo;
    for (final profile in _feed.profiles.skip(2).take(2)) {
      final path = profile.photoPath;
      if (path == null || !_prefetched.add(profile.id)) continue;
      repo.photoUrl(path).then((url) {
        if (url != null && mounted) precacheImage(zayaPhoto(url, path), context, onError: (_, __) {});
      }, onError: (_) {});
    }
  }

  Future<void> _refreshFiltersState() async {
    try {
      final active = (await Session.read(context).repo.loadPreferences()).isFiltered;
      if (mounted && active != _filtersActive) setState(() => _filtersActive = active);
    } catch (_) {
      // Préférences illisibles (hors connexion) : on n'affiche simplement pas le point.
    }
  }

  @override
  void dispose() {
    _radarTimer?.cancel();
    _feed.removeListener(_prefetchAhead);
    _fly.removeListener(_onFly);
    _fly.dispose();
    _drag.dispose();
    _readingId.dispose();
    super.dispose();
  }

  void _onFly() {
    _drag.value = Offset.lerp(_from, _to, ZMotion.emphasized.transform(_fly.value))!;
  }

  /// Anime la carte vers [target] (sortie d'écran ou retour au centre).
  Future<void> _animateTo(Offset target) async {
    if (!mounted) return;
    if (ZMotion.reduced(context)) {
      _drag.value = target;
      return;
    }
    _from = _drag.value;
    _to = target;
    try {
      await _fly.forward(from: 0).orCancel;
    } on TickerCanceled {
      // Écran fermé pendant l'animation : rien à faire.
    }
  }

  Offset _exit(int direction) => Offset(MediaQuery.of(context).size.width * 1.5 * direction, 40);

  Future<void> _pass(DiscoveryProfile profile) async {
    if (_acting) return;
    final session = Session.read(context);
    // Passer consomme un swipe (0016) : quota atteint, l'écran de limite s'ouvre et la carte reste en place.
    final quota = session.feed.quota;
    if (quota != null && quota.remaining <= 0) {
      await showQuotaSheet(context, quota.resetsAt);
      return;
    }
    setState(() => _acting = true);
    // Sans réseau, le profil pourra simplement être proposé à nouveau plus tard.
    session.repo.pass(profile.id).then((_) {
      final q = session.feed.quota;
      if (q != null && q.remaining > 0) session.feed.setRemaining(q.remaining - 1);
    }, onError: (Object e) {
      if (e.toString().contains('SWIPE_QUOTA_REACHED')) session.feed.setRemaining(0);
    });
    await _animateTo(_exit(-1));
    if (!mounted) return;
    // Remise au centre et retrait de la carte dans la même image : la suivante prend sa place sans saut.
    _drag.value = Offset.zero;
    _readingId.value = null;
    setState(() => _acting = false);
    session.feed.remove(profile.id);
    // Swipe ordinaire : peut compter pour un interstitiel (désactivé tant que l'administration ne l'active pas).
    InterstitialPacer.instance.onSwipe(session.repo);
  }

  Future<void> _like(DiscoveryProfile profile) async {
    if (_acting) return;
    setState(() => _acting = true);
    HapticFeedback.lightImpact();
    final flight = _animateTo(_exit(1));
    final result = await sendLike(context, profile);
    await flight;
    if (!mounted) return;
    final refused = result == null || result.status == LikeStatus.quotaReached;
    if (refused) {
      // Like non pris en compte (quota atteint ou erreur) : la carte revient à sa place.
      await _animateTo(Offset.zero);
      if (!mounted) return;
    } else {
      // Le retrait de la carte (applyLikeResult) a lieu sans attente, dans la même image.
      _drag.value = Offset.zero;
      _readingId.value = null;
    }
    setState(() => _acting = false);
    // Interstitiel possible seulement après un like ordinaire, jamais juste après un match.
    if (result?.status == LikeStatus.liked) InterstitialPacer.instance.onSwipe(Session.read(context).repo);
    if (result != null) await applyLikeResult(context, profile, result);
  }

  void _onDragEnd(DiscoveryProfile profile, DragEndDetails details) {
    final width = MediaQuery.of(context).size.width;
    final dx = _drag.value.dx;
    // Un geste vif compte même s'il est court (lancer de carte).
    final velocity = details.primaryVelocity ?? 0;
    final flung = velocity.abs() > 900 && dx.abs() > width * 0.08 && velocity.sign == dx.sign;
    if (dx > width * 0.28 || (flung && dx > 0)) {
      _like(profile);
    } else if (dx < -width * 0.28 || (flung && dx < 0)) {
      _pass(profile);
    } else {
      _animateTo(Offset.zero);
    }
  }

  /// Retour au profil précédent (dernier profil passé, 0016) : il revient de la gauche, à sa place en tête.
  /// Ne rend pas le swipe consommé ; Premium peut remonter plus loin (réglage serveur).
  Future<void> _rewind() async {
    if (_acting) return;
    final session = Session.read(context);
    setState(() => _acting = true);
    DiscoveryProfile? back;
    try {
      back = await session.repo.rewindLastPass();
    } catch (e) {
      if (mounted) showZayaSnack(context, friendlyError(e), error: true);
    }
    if (!mounted) return;
    if (back == null) {
      setState(() => _acting = false);
      showZayaSnack(context, 'Aucun profil passé à faire revenir pour le moment.');
      return;
    }
    // La carte part de la gauche (là où elle était sortie) et revient au centre.
    _drag.value = _exit(-1);
    _readingId.value = null;
    session.feed.restore(back);
    await _animateTo(Offset.zero);
    if (mounted) setState(() => _acting = false);
  }

  /// Le membre fait défiler une carte pour lire le profil : c'est une vraie visite (statistiques du profil).
  void _onCardRead(DiscoveryProfile profile) {
    if (_viewed.add(profile.id)) Session.read(context).repo.recordProfileView(profile.id);
  }

  void _openPremium() => Navigator.of(context).push(zRoute<void>(const PremiumScreen()));

  Future<void> _openFilters() async {
    final changed = await Navigator.of(context).push<bool>(zRoute<bool>(const PreferencesScreen()));
    if (changed == true && mounted) Session.read(context).feed.load();
    if (mounted) _refreshFiltersState();
  }

  void _showCardMenu(DiscoveryProfile profile) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.flag_outlined, color: ZColors.danger),
            title: Text('Signaler ${profile.displayName}'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              showReportSheet(context, userId: profile.id, name: profile.displayName, reportContext: 'profile');
            },
          ),
          ListTile(
            leading: const Icon(Icons.block, color: ZColors.danger),
            title: Text('Bloquer ${profile.displayName}'),
            onTap: () async {
              Navigator.of(sheetContext).pop();
              final feed = Session.read(context).feed;
              if (await confirmBlock(context, userId: profile.id, name: profile.displayName)) feed.remove(profile.id);
            },
          ),
        ]),
      ),
    );
  }

  /// La carte du dessus est en cours de lecture.
  bool _isReading(Session session) {
    final id = _readingId.value;
    return id != null && session.feed.profiles.isNotEmpty && session.feed.profiles.first.id == id;
  }

  /// La carte est affichée (et non un état vide, de chargement ou d'erreur).
  bool _showsCards(Session session) {
    final me = session.me;
    if (me != null && (me.status == 'paused' || me.status == 'hidden')) return false;
    return _radarElapsed && session.feed.profiles.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final session = Session.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([session.feed, _readingId]),
      builder: (context, _) {
        final cards = _showsCards(session);
        final reading = cards && _isReading(session);
        final onPhoto = cards && !reading;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: onPhoto ? _statusOnPhoto : zSystemUi,
          child: Scaffold(
            backgroundColor: ZColors.bg,
            body: Stack(children: [
              // Fondu entre la recherche (ou un état vide) et les cartes.
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: ZMotion.of(context, ZMotion.slow),
                  switchInCurve: ZMotion.emphasized,
                  layoutBuilder: (current, previous) =>
                      Stack(fit: StackFit.expand, children: [...previous, if (current != null) current]),
                  child: cards
                      ? KeyedSubtree(key: const ValueKey<String>('cards'), child: _cards(context, session))
                      : KeyedSubtree(key: const ValueKey<String>('state'), child: _state(context, session)),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _TopBar(
                  onPhoto: onPhoto,
                  hidden: reading,
                  filtersActive: _filtersActive,
                  onFilters: _openFilters,
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  /// Bandeau « votre profil n'est pas encore visible » : sur la photo (verre fumé) ou sur fond clair.
  Widget? _verificationBanner(Session session, {required bool onPhoto}) {
    final me = session.me;
    if (me == null || me.isVerified) return null;
    final pending = me.verificationStatus == 'pending';
    // Sur la photo, une phrase courte : le bouton « Vérifier » dit la suite.
    final text = pending
        ? 'Vérification en cours. Votre profil sera visible dès qu’elle sera validée.'
        : onPhoto
            ? 'Votre profil n’est pas encore visible des autres membres.'
            : 'Votre profil n’est pas encore visible des autres membres. Ajoutez 3 photos et faites-le vérifier.';
    void verify() => Navigator.of(context).push(zRoute<void>(const VerificationScreen()));
    if (!onPhoto) {
      return InfoBanner(
        tone: BannerTone.warning,
        icon: Icons.verified_outlined,
        text: text,
        action: pending
            ? null
            : TextButton(
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero, minimumSize: const Size(0, 32), foregroundColor: const Color(0xFF5C4100)),
                onPressed: verify,
                child: const Text('Vérifier mon profil  →', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
      );
    }
    return Material(
      color: Colors.black.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: pending ? null : verify,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(children: [
            const Icon(Icons.verified_outlined, color: Color(0xFFFFD27A), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style: GoogleFonts.inter(fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
            if (!pending) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)),
                child: Text('Vérifier',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: ZColors.ink)),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  /// États sans carte (pause, chargement, erreur, plus de profils), sous l'en-tête en version claire.
  Widget _state(BuildContext context, Session session) {
    final top = MediaQuery.paddingOf(context).top + _topBarHeight;
    final banner = _verificationBanner(session, onPhoto: false);
    return Column(children: [
      SizedBox(height: top),
      if (banner != null) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 6), child: banner),
      Expanded(child: _stateBody(context, session)),
    ]);
  }

  Widget _stateBody(BuildContext context, Session session) {
    final feed = session.feed;
    final me = session.me;
    if (me != null && (me.status == 'paused' || me.status == 'hidden')) {
      return EmptyState(
        icon: Icons.pause_circle_outline,
        title: me.deletionScheduledFor != null ? 'Suppression du compte demandée' : 'Votre profil est en pause',
        message: me.deletionScheduledFor != null
            ? 'Votre profil n’est plus proposé. Vous pouvez annuler la suppression depuis l’onglet Profil.'
            : 'Réactivez votre profil depuis l’onglet Profil pour découvrir de nouvelles personnes.',
      );
    }
    if (!_radarElapsed || feed.loading || (!feed.loaded && feed.error == null)) {
      return RadarSearch(
        name: me?.displayName ?? '',
        photoPath: me?.mainPhotoPath,
        title: context.s.radarSearchTitle,
        subtitle: context.s.radarSearchSubtitle,
        found: [for (final p in feed.profiles.take(5)) (id: p.id, name: p.displayName, photoPath: p.photoPath)],
      );
    }
    if (feed.error != null) {
      return EmptyState(
        icon: Icons.wifi_off,
        title: 'Connexion interrompue',
        message: feed.error!,
        action: FilledButton(onPressed: feed.load, child: const Text('Réessayer')),
      );
    }
    return EmptyState(
      icon: Icons.search,
      title: 'Plus de profils pour le moment',
      message: 'De nouveaux membres rejoignent ZAYA chaque jour. Élargissez vos préférences ou revenez plus tard.',
      action: Column(mainAxisSize: MainAxisSize.min, children: [
        FilledButton(onPressed: _openFilters, child: const Text('Modifier mes préférences')),
        const SizedBox(height: 8),
        TextButton(onPressed: feed.load, child: const Text('Actualiser')),
        TextButton.icon(
          onPressed: _rewind,
          icon: const Icon(Icons.replay_rounded, size: 20),
          label: const Text('Revenir au profil précédent'),
        ),
      ]),
    );
  }

  Widget _cards(BuildContext context, Session session) {
    final feed = session.feed;
    final top = feed.profiles.first;
    final next = feed.profiles.length > 1 ? feed.profiles[1] : null;
    final width = MediaQuery.of(context).size.width;
    final threshold = width * 0.28;
    final topInset = MediaQuery.paddingOf(context).top + _topBarHeight;
    final banner = _verificationBanner(session, onPhoto: true);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Stack(children: [
        Positioned.fill(
          // Glissement horizontal : aimer / passer. Le glissement vertical reste à la carte, qui défile pour montrer
          // la suite du profil ; les deux gestes se départagent selon la direction du doigt.
          child: GestureDetector(
            onHorizontalDragUpdate: _acting ? null : (details) => _drag.value += Offset(details.delta.dx, 0),
            onHorizontalDragEnd: _acting ? null : (details) => _onDragEnd(top, details),
            child: Stack(children: [
              // Carte de derrière puis carte du dessus, avec la même structure et une clé par profil :
              // quand la carte de derrière passe devant, elle est conservée telle quelle (photo déjà
              // affichée) au lieu d'être reconstruite sur le fond provisoire.
              for (final profile in [if (next != null) next, top])
                Positioned.fill(
                  key: ValueKey<String>(profile.id),
                  child: ValueListenableBuilder<Offset>(
                    valueListenable: _drag,
                    // La carte est dessinée une fois ; pendant le geste, elle est seulement déplacée.
                    child: RepaintBoundary(
                      child: _ProfileCard(
                        profile: profile,
                        heroTag: 'discover-${profile.id}',
                        topInset: topInset,
                        bottomInset: _actionsHeight,
                        onMore: () => _showCardMenu(profile),
                        onRead: () => _onCardRead(profile),
                        onUnlock: _openPremium,
                        onReadingChanged: (reading) {
                          if (reading) {
                            _readingId.value = profile.id;
                          } else if (_readingId.value == profile.id) {
                            _readingId.value = null;
                          }
                        },
                      ),
                    ),
                    builder: (context, drag, card) {
                      final isTop = profile.id == top.id;
                      final progress = (drag.dx.abs() / threshold).clamp(0.0, 1.0).toDouble();
                      final swipe = (drag.dx / threshold).clamp(-1.0, 1.0).toDouble();
                      final scale = 0.92 + 0.08 * progress;
                      return Transform(
                        alignment: Alignment.bottomCenter,
                        // Dessus : suit le doigt en pivotant autour du bas. Derrière : grandit à mesure que l'autre
                        // s'éloigne.
                        transform: isTop
                            ? (Matrix4.translationValues(drag.dx, drag.dy, 0)..rotateZ(drag.dx / width * 0.22))
                            : Matrix4.diagonal3Values(scale, scale, 1),
                        child: Stack(fit: StackFit.expand, children: [
                          card!,
                          // Teinte du bord vers lequel la carte part, puis tampon « J'aime » / « Passer ».
                          if (isTop && swipe != 0) _SwipeTint(swipe: swipe),
                          if (isTop && swipe.abs() > 0.1) _SwipeStamp(swipe: swipe, top: topInset + 40),
                          // Voile sombre plutôt qu'une opacité animée : même rendu, sans recomposer toute la carte
                          // hors écran à chaque image (coûteux sur les téléphones modestes).
                          if (!isTop && progress < 1)
                            IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.45 * (1 - progress)),
                                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(_cardRadius)),
                                ),
                              ),
                            ),
                        ]),
                      );
                    },
                  ),
                ),
            ]),
          ),
        ),
        if (banner != null)
          Positioned(
            top: topInset + 14,
            left: 12,
            right: 12,
            child: ValueListenableBuilder<String?>(
              valueListenable: _readingId,
              builder: (context, readingId, child) => IgnorePointer(
                ignoring: readingId == top.id,
                child: AnimatedOpacity(
                    opacity: readingId == top.id ? 0 : 1, duration: ZMotion.of(context, ZMotion.fast), child: child),
              ),
              child: banner,
            ),
          ),
        // Pendant la lecture, un fondu clair sous les boutons : le texte du profil ne passe pas sous eux brutalement.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: _actionsHeight + 50,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: _isReading(session) ? 1 : 0,
              duration: ZMotion.of(context, ZMotion.medium),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(_cardRadius)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, 0.55],
                    colors: [ZColors.bg.withValues(alpha: 0), ZColors.bg],
                  ),
                ),
              ),
            ),
          ),
        ),
        // Boutons d'action, fixes au bas de la carte : ils restent sous le pouce pendant la lecture du profil.
        Positioned(
          left: 0,
          right: 0,
          bottom: 16,
          child: ValueListenableBuilder<Offset>(
            valueListenable: _drag,
            builder: (context, drag, _) {
              final swipe = (drag.dx / threshold).clamp(-1.0, 1.0).toDouble();
              final toLike = math.max(0.0, swipe);
              final toPass = math.max(0.0, -swipe);
              return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                SwipeActionButton(
                  action: SwipeAction.rewind,
                  label: 'Revenir au profil précédent',
                  dim: swipe.abs(),
                  onTap: _rewind,
                ),
                const SizedBox(width: 16),
                SwipeActionButton(
                  action: SwipeAction.pass,
                  label: 'Passer',
                  highlight: toPass,
                  dim: toLike,
                  onTap: () => _pass(top),
                ),
                const SizedBox(width: 20),
                SwipeActionButton(
                  action: SwipeAction.like,
                  label: 'Aimer',
                  highlight: toLike,
                  dim: toPass,
                  onTap: () => _like(top),
                ),
                const SizedBox(width: 16),
                SwipeActionButton(
                  action: SwipeAction.flower,
                  label: 'Fleur Premium — bientôt disponible',
                  dim: swipe.abs(),
                  onTap: _openPremium,
                ),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}

/// En-tête de l'onglet, posé sur la photo : filtres, titre, Boost (flamme animée), notifications.
/// En blanc sur la photo, en encre sur fond clair ; il s'efface pendant la lecture d'un profil.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onPhoto,
    required this.hidden,
    required this.filtersActive,
    required this.onFilters,
  });
  final bool onPhoto;
  final bool hidden;
  final bool filtersActive;
  final VoidCallback onFilters;

  @override
  Widget build(BuildContext context) {
    final fg = onPhoto ? Colors.white : ZColors.ink;
    return IgnorePointer(
      ignoring: hidden,
      child: AnimatedOpacity(
        opacity: hidden ? 0 : 1,
        duration: ZMotion.of(context, ZMotion.fast),
        child: AnimatedSlide(
          offset: hidden ? const Offset(0, -0.25) : Offset.zero,
          duration: ZMotion.of(context, ZMotion.medium),
          curve: ZMotion.emphasized,
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: _topBarHeight,
              child: Row(children: [
                const SizedBox(width: 4),
                IconButton(
                  icon: Badge(
                    isLabelVisible: filtersActive,
                    smallSize: 9,
                    backgroundColor: ZColors.primary,
                    child: Icon(Icons.tune_rounded, color: fg, shadows: onPhoto ? _iconShadow : null),
                  ),
                  tooltip: filtersActive ? 'Préférences de découverte (filtres actifs)' : 'Préférences de découverte',
                  onPressed: onFilters,
                ),
                const SizedBox(width: 2),
                // Titre de l'onglet, dans une pastille de verre fumé quand il est posé sur la photo.
                AnimatedContainer(
                  duration: ZMotion.of(context, ZMotion.medium),
                  padding: EdgeInsets.symmetric(horizontal: onPhoto ? 16 : 4, vertical: 7),
                  decoration: BoxDecoration(
                    color: onPhoto ? Colors.black.withValues(alpha: 0.32) : Colors.transparent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text('Mariage',
                      style: GoogleFonts.sora(fontSize: onPhoto ? 14 : 16, fontWeight: FontWeight.w700, color: fg)),
                ),
                const Spacer(),
                IconTheme.merge(
                  data: IconThemeData(color: fg),
                  child: const BoostButton(),
                ),
                IconButton(
                  icon: Icon(Icons.notifications_none_rounded, color: fg, shadows: onPhoto ? _iconShadow : null),
                  tooltip: 'Notifications',
                  onPressed: () => Navigator.of(context).push(zRoute<void>(const NotificationsScreen())),
                ),
                const SizedBox(width: 4),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  static const _iconShadow = [Shadow(color: Color(0x66000000), blurRadius: 8)];
}

/// Vol de la photo entre la carte et la fiche : les coins s'arrondissent ou s'aplatissent progressivement
/// (de 28 à 0 à l'ouverture, l'inverse au retour) au lieu de changer d'un coup au début ou à la fin du vol.
Widget _cardPhotoShuttle(BuildContext flightContext, Animation<double> animation, HeroFlightDirection direction,
    BuildContext fromHeroContext, BuildContext toHeroContext) {
  final hero = toHeroContext.widget as Hero;
  return AnimatedBuilder(
    animation: animation,
    child: hero.child,
    builder: (context, child) => ClipRRect(
      borderRadius: BorderRadius.circular(_cardRadius * (1 - animation.value).clamp(0.0, 1.0)),
      child: child,
    ),
  );
}

/// Lueur sur le bord vers lequel part la carte : rose pour « J'aime », sombre pour « Passer ».
class _SwipeTint extends StatelessWidget {
  const _SwipeTint({required this.swipe});
  final double swipe;

  @override
  Widget build(BuildContext context) {
    final like = swipe > 0;
    final s = swipe.abs();
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(_cardRadius)),
          gradient: LinearGradient(
            begin: like ? Alignment.centerRight : Alignment.centerLeft,
            end: like ? Alignment.centerLeft : Alignment.centerRight,
            colors: [
              (like ? ZColors.primary : Colors.black).withValues(alpha: (like ? 0.42 : 0.38) * s),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

/// Tampon « J'AIME » / « PASSER » affiché sur la carte pendant le geste ; [swipe] va de -1 (passer) à 1 (aimer).
/// Il arrive un peu grand puis se pose, comme un tampon qu'on appuie. Il est dessiné au-dessus de la carte, pour que
/// celle-ci n'ait pas à être redessinée à chaque mouvement.
class _SwipeStamp extends StatelessWidget {
  const _SwipeStamp({required this.swipe, required this.top});
  final double swipe;
  final double top;

  @override
  Widget build(BuildContext context) {
    final like = swipe > 0;
    final t = ((swipe.abs() - 0.1) / 0.5).clamp(0.0, 1.0).toDouble();
    final color = like ? ZColors.gradientStart : Colors.white;
    return Positioned(
      top: top,
      left: like ? 28 : null,
      right: like ? null : 28,
      child: IgnorePointer(
        child: Opacity(
          opacity: t,
          child: Transform.rotate(
            angle: like ? -0.24 : 0.24,
            child: Transform.scale(
              scale: 1.35 - 0.35 * Curves.easeOut.transform(t),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: like ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.18),
                  border: Border.all(color: color, width: 4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(like ? 'J’AIME' : 'PASSER',
                    style: GoogleFonts.sora(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: color,
                        shadows: const [Shadow(color: Color(0x40000000), blurRadius: 8)])),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Carte d'un profil, en plein écran : la photo occupe toute la carte, le nom et les informations principales sont
/// posés dessus. On la fait défiler vers le haut (ou on touche la flèche) pour lire la suite du profil en encadrés,
/// sans quitter l'écran ; un en-tête au prénom apparaît alors, avec la flèche pour revenir à la photo. Un toucher sur
/// la photo passe à la suivante ; au-delà de la dernière, la carte rebondit légèrement. La fiche est préchargée sans
/// compter de visite ; la visite est comptée quand le membre la lit.
class _ProfileCard extends StatefulWidget {
  const _ProfileCard({
    required this.profile,
    required this.heroTag,
    required this.topInset,
    required this.bottomInset,
    this.onMore,
    this.onRead,
    this.onUnlock,
    this.onReadingChanged,
  });
  final DiscoveryProfile profile;

  /// Toujours présent (même sur la carte de derrière), pour que la photo garde la même place dans
  /// l'arbre quand la carte passe devant.
  final String heroTag;

  /// Hauteur de l'en-tête de l'onglet (barre d'état comprise) posé sur le haut de la carte.
  final double topInset;

  /// Place des boutons d'action, posés sur le bas de la carte.
  final double bottomInset;
  final VoidCallback? onMore;

  /// Appelé une fois, quand le membre fait défiler la carte pour lire le profil.
  final VoidCallback? onRead;
  final VoidCallback? onUnlock;
  final ValueChanged<bool>? onReadingChanged;

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> with SingleTickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();
  late final AnimationController _bump = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  int _bumpDirection = 1;
  ProfileDetail? _detail;
  String? _error;
  bool _read = false;
  bool _reading = false;
  double _height = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  Future<void> _load() async {
    try {
      final detail = await Session.read(context).repo.profileDetail(widget.profile.id, recordView: false);
      if (mounted) {
        setState(() {
          _detail = detail;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  void _onScroll() {
    final reading = _height > 0 && _scroll.offset > _height * 0.38;
    if (reading != _reading) {
      setState(() => _reading = reading);
      widget.onReadingChanged?.call(reading);
    }
    if (!_read && _scroll.offset > 80) {
      _read = true;
      widget.onRead?.call();
    }
  }

  /// Flèche « voir tout le profil » : la carte défile jusqu'aux encadrés, la photo reste visible en haut.
  void _expand() {
    final target = _height * 0.58;
    if (ZMotion.reduced(context)) {
      _scroll.jumpTo(target);
    } else {
      _scroll.animateTo(target, duration: const Duration(milliseconds: 520), curve: Curves.easeOutCubic);
    }
  }

  void _collapse() {
    if (ZMotion.reduced(context)) {
      _scroll.jumpTo(0);
    } else {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 460), curve: Curves.easeOutCubic);
    }
  }

  /// Toucher au-delà de la première ou de la dernière photo : petit basculement de la carte, pour dire « c'est tout ».
  void _onEdge(int direction) {
    if (ZMotion.reduced(context)) return;
    HapticFeedback.selectionClick();
    _bumpDirection = direction;
    _bump.forward(from: 0);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _bump.dispose();
    super.dispose();
  }

  Widget _cover(DiscoveryProfile p) {
    final detail = _detail;
    final me = Session.of(context).me;
    final badges = profileCoverBadges(me, detail?.base ?? p);
    final photo = Stack(fit: StackFit.expand, children: [
      ProfilePhotoPager(
        name: p.displayName,
        photos: detail?.photos ?? const <ProfilePhoto>[],
        fallbackPath: p.photoPath,
        heroTag: widget.heroTag,
        heroShuttle: _cardPhotoShuttle,
        onUnlock: widget.onUnlock,
        onEdge: _onEdge,
        topInset: widget.topInset + 2,
      ),
      // Voile en haut, pour la lisibilité de l'en-tête.
      IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, math.min(0.4, (widget.topInset + 60) / math.max(_height, 1))],
              colors: const [Color(0x8C000000), Color(0x00000000)],
            ),
          ),
        ),
      ),
      // Voile en bas (nom, informations, boutons) : il s'efface pendant la lecture, pour laisser voir la photo.
      IgnorePointer(
        child: AnimatedOpacity(
          opacity: _reading ? 0 : 1,
          duration: ZMotion.of(context, ZMotion.medium),
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.5, 0.74, 1],
                colors: [Color(0x00140A18), Color(0x8C140A18), Color(0xF2140A18)],
              ),
            ),
          ),
        ),
      ),
    ]);
    return Stack(fit: StackFit.expand, children: [
      AnimatedBuilder(
        animation: _bump,
        child: photo,
        builder: (context, child) {
          if (!_bump.isAnimating) return child!;
          final angle = 0.07 * _bumpDirection * math.sin(math.pi * _bump.value);
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(angle),
            child: child,
          );
        },
      ),
      // Nom, informations et flèche : remplacés par l'en-tête de lecture quand on fait défiler la carte.
      Positioned(
        left: 20,
        right: 14,
        bottom: widget.bottomInset + 8,
        child: IgnorePointer(
          ignoring: _reading,
          child: AnimatedOpacity(
            opacity: _reading ? 0 : 1,
            duration: ZMotion.of(context, ZMotion.fast),
            child: _coverInfo(p, badges),
          ),
        ),
      ),
    ]);
  }

  Widget _coverInfo(DiscoveryProfile p, List<Widget> badges) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: IgnorePointer(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                if (badges.isNotEmpty) ...[
                  Wrap(spacing: 6, runSpacing: 6, children: badges),
                  const SizedBox(height: 10),
                ],
                Row(children: [
                  Flexible(child: ProfileNameAge(name: p.displayName, age: p.age)),
                  if (p.isVerified) ...[const SizedBox(width: 8), const VerifiedBadge(size: 26)],
                ]),
                ProfileCoverLines(profile: p),
              ]),
            ),
          ),
          const SizedBox(width: 10),
          _RoundArrow(up: true, tooltip: 'Voir tout le profil', onTap: _expand),
        ],
      );

  /// En-tête de lecture : prénom, âge, options et flèche pour revenir à la photo.
  Widget _readingHeader(DiscoveryProfile p) {
    final top = MediaQuery.paddingOf(context).top;
    return IgnorePointer(
      ignoring: !_reading,
      child: AnimatedOpacity(
        opacity: _reading ? 1 : 0,
        duration: ZMotion.of(context, ZMotion.fast),
        child: AnimatedSlide(
          offset: _reading ? Offset.zero : const Offset(0, -0.2),
          duration: ZMotion.of(context, ZMotion.medium),
          curve: ZMotion.emphasized,
          child: Container(
            padding: EdgeInsets.fromLTRB(20, top + 8, 10, 10),
            decoration: const BoxDecoration(
              color: ZColors.bg,
              border: Border(bottom: BorderSide(color: ZColors.line)),
            ),
            child: Row(children: [
              Expanded(
                child: Row(children: [
                  Flexible(child: ProfileNameAge(name: p.displayName, age: p.age, size: 26, color: ZColors.ink)),
                  if (p.isVerified) ...[const SizedBox(width: 6), const VerifiedBadge(size: 22)],
                ]),
              ),
              if (widget.onMore != null)
                IconButton(
                  icon: const Icon(Icons.more_horiz_rounded, color: ZColors.ink),
                  tooltip: 'Signaler ou bloquer',
                  onPressed: widget.onMore,
                ),
              _RoundArrow(up: false, tooltip: 'Revenir à la photo', onTap: _collapse),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(_cardRadius)),
      child: ColoredBox(
        color: ZColors.bg,
        child: LayoutBuilder(builder: (context, constraints) {
          _height = constraints.maxHeight;
          return Stack(children: [
            CustomScrollView(
              controller: _scroll,
              physics: const ClampingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: SizedBox(height: constraints.maxHeight, child: _cover(p))),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
                  sliver: SliverToBoxAdapter(
                    child: ProfileInfoSections(
                      base: _detail?.base ?? p,
                      detail: _detail,
                      error: _error,
                      onRetry: _load,
                      animate: false,
                    ),
                  ),
                ),
                if (widget.onMore != null)
                  SliverToBoxAdapter(
                    child: Center(
                      child: TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: ZColors.muted),
                        onPressed: widget.onMore,
                        icon: const Icon(Icons.flag_outlined, size: 18),
                        label: Text('Signaler ou bloquer ${p.displayName}'),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(child: SizedBox(height: widget.bottomInset + 20)),
              ],
            ),
            Positioned(top: 0, left: 0, right: 0, child: _readingHeader(p)),
          ]);
        }),
      ),
    );
  }
}

/// Flèche ronde et sombre : vers le haut pour lire tout le profil, vers le bas pour revenir à la photo.
class _RoundArrow extends StatelessWidget {
  const _RoundArrow({required this.up, required this.tooltip, required this.onTap});
  final bool up;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        // Nœud à part : sans cela, le lecteur d'écran fusionne la flèche avec le prénom voisin.
        container: true,
        button: true,
        label: tooltip,
        excludeSemantics: true,
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: PressScale(
            pressedScale: 0.88,
            onTap: onTap,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF1B1020).withValues(alpha: 0.88),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 10, offset: Offset(0, 4))],
              ),
              child: Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, color: Colors.white, size: 24),
            ),
          ),
        ),
      );
}
