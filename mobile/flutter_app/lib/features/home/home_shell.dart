import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../core/motion.dart';
import '../../core/tab_bar.dart';
import '../chat/conversations_screen.dart';
import '../discovery/discovery_screen.dart';
import '../discovery/explore_screen.dart';
import '../likes/likes_screen.dart';
import '../profile/profile_screen.dart';

/// Navigation principale : Découvrir · Explorer · Likes · Messages · Profil.
/// Le changement d'onglet s'accompagne d'un fondu glissé ; l'état de chaque onglet est conservé.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with SingleTickerProviderStateMixin {
  static const _likesTab = 2;
  static const _messagesTab = 3;

  late final AnimationController _switch = AnimationController(vsync: this, duration: ZMotion.medium, value: 1);
  int _index = 0;
  int _direction = 1;
  // Un onglet n'est construit (et ne charge ses données) qu'à sa première visite.
  final Set<int> _visited = <int>{0};
  int _likesReload = 0;
  int _messagesReload = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Session.read(context).refreshBadges();
    });
  }

  @override
  void dispose() {
    _switch.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (index == _index) return;
    HapticFeedback.selectionClick();
    setState(() {
      _direction = index > _index ? 1 : -1;
      _index = index;
      _visited.add(index);
      // Likes et Messages se rechargent à chaque visite pour rester à jour.
      if (index == _likesTab) _likesReload++;
      if (index == _messagesTab) _messagesReload++;
    });
    if (ZMotion.reduced(context)) {
      _switch.value = 1;
    } else {
      _switch.forward(from: 0);
    }
    Session.read(context).refreshBadges();
  }

  Widget _lazy(int index, Widget child) => _visited.contains(index) ? child : const SizedBox.shrink();

  @override
  Widget build(BuildContext context) {
    final session = Session.of(context);
    final slide = Tween<Offset>(begin: Offset(0.035 * _direction, 0), end: Offset.zero)
        .chain(CurveTween(curve: ZMotion.emphasized));
    return Scaffold(
      body: FadeTransition(
        opacity: _switch.drive(CurveTween(curve: Curves.easeOut)),
        child: SlideTransition(
          position: _switch.drive(slide),
          child: IndexedStack(index: _index, children: [
            _lazy(0, const DiscoveryScreen()),
            _lazy(1, const ExploreScreen()),
            _lazy(_likesTab, LikesScreen(key: ValueKey<String>('likes-$_likesReload'), onDiscover: () => _select(0))),
            _lazy(
              _messagesTab,
              ConversationsScreen(key: ValueKey<String>('messages-$_messagesReload'), onDiscover: () => _select(0)),
            ),
            _lazy(4, const ProfileScreen()),
          ]),
        ),
      ),
      bottomNavigationBar: ZayaTabBar(
        index: _index,
        onChanged: _select,
        badges: <int, int>{_likesTab: session.likesBadge, _messagesTab: session.unreadBadge},
        items: const [
          ZTabItem(icon: Icons.style_outlined, activeIcon: Icons.style, label: 'Découvrir'),
          ZTabItem(icon: Icons.explore_outlined, activeIcon: Icons.explore, label: 'Explorer'),
          ZTabItem(icon: Icons.favorite_border, activeIcon: Icons.favorite, label: 'Likes'),
          ZTabItem(icon: Icons.chat_bubble_outline, activeIcon: Icons.chat_bubble, label: 'Messages'),
          ZTabItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profil'),
        ],
      ),
    );
  }
}
