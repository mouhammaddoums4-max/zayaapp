import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app.dart';
import '../../core/motion.dart';
import '../../core/tab_bar.dart';
import '../../core/theme.dart';
import '../../core/zaya_icons.dart';
import '../app/app_update.dart';
import '../app/rating_prompt.dart';
import '../auth/pin_screens.dart';
import '../chat/conversations_screen.dart';
import '../community/community_screen.dart';
import '../discovery/discovery_screen.dart';
import '../discovery/explore_screen.dart';
import '../discovery/profile_widgets.dart';
import '../mystery/mystery_box_screen.dart';
import '../mystery/mystery_box_service.dart';
import '../profile/profile_screen.dart';

/// Navigation principale : Découvrir · Explorer · Messages · Communauté · Profil (décision C16).
/// Les likes reçus sont en tête d'Explorer. Le changement d'onglet s'accompagne d'un fondu glissé ;
/// l'état de chaque onglet est conservé.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with SingleTickerProviderStateMixin, RouteAware {
  static const _exploreTab = 1;
  static const _messagesTab = 2;
  static const _communityTab = 3;

  late final AnimationController _switch =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 180), value: 1);
  int _index = 0;
  // Un onglet n'est construit (et ne charge ses données) qu'à sa première visite.
  final Set<int> _visited = <int>{0};
  int _messagesReload = 0;
  final RatingPrompter _rating = RatingPrompter();
  static const _updateDismissedKey = 'zaya_update_dismissed';
  static const _mysteryShownKey = 'zaya_mystery_box_shown';

  @override
  void initState() {
    super.initState();
    RatingPrompter.recordSession();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Session.read(context).refreshBadges();
      // D'abord le code de connexion (compte sans code), puis la mise à jour et la boîte mystère.
      _ensurePin().whenComplete(() {
        if (!mounted) return;
        _offerUpdate().whenComplete(() {
          if (mounted) _offerMysteryBox();
        });
      });
    });
  }

  /// Connexion par code (0071) : un compte sans code (inscription, ancien compte connecté par SMS) choisit son
  /// code tout de suite ; l'écran ne peut pas être fermé sans l'avoir fait. Sans la migration côté serveur,
  /// rien n'est demandé.
  Future<void> _ensurePin() async {
    try {
      final status = await Session.read(context).repo.myPinStatus();
      if (!mounted || status.hasPin) return;
      // Un autre écran est au-dessus (fin d'inscription…) : le choix du code attend qu'il se referme (didPopNext).
      if (!(ModalRoute.of(context)?.isCurrent ?? true)) {
        _pinPending = true;
        return;
      }
      await Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const PinSetupScreen(mode: PinSetupMode.create, forced: true)));
    } catch (_) {
      // Serveur sans la connexion par code, ou réseau indisponible : redemandé au prochain lancement.
    }
  }

  /// Choix du code en attente : un écran couvrait l'accueil au moment de la vérification.
  bool _pinPending = false;
  ModalRoute<Object?>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && !identical(route, _route)) {
      if (_route != null) zRouteObserver.unsubscribe(this);
      _route = route;
      zRouteObserver.subscribe(this, route);
    }
  }

  /// L'écran du dessus vient de se refermer : la page d'accueil est de nouveau visible.
  @override
  void didPopNext() {
    if (!_pinPending) return;
    _pinPending = false;
    unawaited(_ensurePin());
  }

  /// Boîte mystère de bienvenue (0033) : présentée automatiquement une seule fois, si le serveur la déclare disponible.
  /// Ensuite, elle reste accessible depuis « Mon portefeuille » tant qu'elle n'est pas ouverte.
  Future<void> _offerMysteryBox() async {
    final service = MysteryBoxService.forRepository(Session.read(context).repo);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_mysteryShownKey) == true) return;
      final st = await service.status();
      if (!st.available || !mounted) return;
      if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
      await prefs.setBool(_mysteryShownKey, true);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => MysteryBoxScreen(service: service, initial: st),
      ));
    } catch (_) {
      // Sans réseau : proposée au prochain lancement.
    }
  }

  /// Mise à jour disponible (non obligatoire) : proposée une seule fois par version.
  Future<void> _offerUpdate() async {
    final status = Session.read(context).update;
    if (status.level != UpdateLevel.available) return;
    // Pas par-dessus un autre écran (fin d'inscription…) : ce sera proposé au prochain lancement.
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_updateDismissedKey) == status.latest || !mounted) return;
      await prefs.setString(_updateDismissedKey, status.latest);
    } catch (_) {
      return;
    }
    if (mounted) await showUpdateAvailableDialog(context, status);
  }

  @override
  void dispose() {
    zRouteObserver.unsubscribe(this);
    _switch.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (index == _index) return;
    HapticFeedback.selectionClick();
    setState(() {
      _index = index;
      _visited.add(index);
      // Messages se recharge à chaque visite pour rester à jour.
      if (index == _messagesTab) _messagesReload++;
    });
    if (ZMotion.reduced(context)) {
      _switch.value = 1;
    } else {
      _switch.forward(from: 0);
    }
    final session = Session.read(context);
    session.refreshBadges();
    // Changement d'onglet = moment calme : la demande d'avis éventuelle n'interrompt aucune action.
    _rating.maybeAsk(session.ratingRules);
  }

  // Un onglet caché ne fait plus tourner ses animations (squelettes, rebonds…) : moins de travail, batterie préservée.
  Widget _lazy(int index, Widget child) =>
      _visited.contains(index) ? TickerMode(enabled: index == _index, child: child) : const SizedBox.shrink();

  @override
  Widget build(BuildContext context) {
    final session = Session.of(context);
    return Scaffold(
      body: FadeTransition(
        opacity: _switch.drive(CurveTween(curve: Curves.easeOut)),
        child: IndexedStack(index: _index, children: [
          _lazy(0, const DiscoveryScreen()),
          _lazy(_exploreTab, ExploreScreen(onDiscover: () => _select(0))),
          _lazy(
            _messagesTab,
            ConversationsScreen(key: ValueKey<String>('messages-$_messagesReload'), onDiscover: () => _select(0)),
          ),
          _lazy(_communityTab, const CommunityScreen()),
          _lazy(4, const ProfileScreen()),
        ]),
      ),
      bottomNavigationBar: ZayaTabBar(
        index: _index,
        onChanged: _select,
        badges: <int, int>{_exploreTab: session.likesBadge, _messagesTab: session.unreadBadge},
        items: [
          ZTabItem(label: 'Mariage', builder: (on, color) => ZIcon(ZGlyph.ring, filled: on, color: color)),
          ZTabItem(label: 'Explorer', builder: (on, color) => ZIcon(ZGlyph.hearts, filled: on, color: color)),
          ZTabItem(label: 'Messages', builder: (on, color) => ZIcon(ZGlyph.chat, filled: on, color: color)),
          const ZTabItem(icon: Icons.groups_outlined, activeIcon: Icons.groups, label: 'Communauté'),
          // Ma photo de profil, entourée de rose quand l'onglet est ouvert (à défaut de photo : mon initiale).
          ZTabItem(
            label: 'Profil',
            builder: (on, color) => Container(
              padding: const EdgeInsets.all(1.6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: on ? ZColors.primary : ZColors.line, width: on ? 2 : 1.4),
              ),
              child: RemoteAvatar(
                name: session.me?.displayName ?? '',
                photoPath: session.me?.mainPhotoPath,
                size: on ? 22 : 21,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
