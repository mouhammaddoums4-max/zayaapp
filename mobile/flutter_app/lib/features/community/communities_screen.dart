import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import 'community_widgets.dart';

/// Choix des notifications d'une communauté (V6.0 §26.5). Retourne le niveau choisi, ou null.
Future<String?> showCommunityNotifications(BuildContext context, Community community) async {
  final repo = Session.read(context).repo;
  final level = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Notifications', style: Theme.of(sheetContext).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(community.name, style: Theme.of(sheetContext).textTheme.bodyMedium),
          const SizedBox(height: 14),
          for (final e in communityNotifLabels.entries)
            ChoiceTile(
              label: e.value,
              selected: (community.notifLevel ?? 'important') == e.key,
              onTap: () => Navigator.of(sheetContext).pop(e.key),
            ),
          Text(
            'Votre choix est enregistré ; les notifications sur le téléphone arriveront avec une prochaine version.',
            style: Theme.of(sheetContext).textTheme.bodyMedium,
          ),
        ]),
      ),
    ),
  );
  if (level == null || !context.mounted) return null;
  try {
    await repo.setCommunityNotifications(community.id, level);
    return level;
  } catch (e) {
    if (context.mounted) showZayaSnack(context, friendlyError(e), error: true);
    return null;
  }
}

/// Toutes les communautés. Un appui ouvre ses publications : l'écran se ferme en renvoyant son identifiant.
class CommunitiesScreen extends StatefulWidget {
  const CommunitiesScreen({super.key});

  @override
  State<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen> {
  List<Community>? _items;
  String? _error;
  final Set<String> _busy = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = Session.read(context).repo;
    try {
      final items = await repo.communities();
      if (mounted) {
        setState(() {
          _items = items;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  Future<void> _toggle(Community community) async {
    final repo = Session.read(context).repo;
    setState(() => _busy.add(community.id));
    try {
      if (community.joined) {
        await repo.leaveCommunity(community.id);
      } else {
        await repo.joinCommunity(community.id);
      }
      await _load();
      if (mounted) {
        showZayaSnack(context,
            community.joined ? 'Vous avez quitté « ${community.name} ».' : 'Bienvenue dans « ${community.name} » !');
      }
    } catch (e) {
      if (mounted) showZayaSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(community.id));
    }
  }

  Future<void> _notifications(Community community) async {
    final level = await showCommunityNotifications(context, community);
    if (level != null) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: const Text('Communautés')),
      body: items == null
          ? (_error == null
              ? ListView(padding: const EdgeInsets.all(16), children: const [
                  Skeleton(height: 120),
                  SizedBox(height: 12),
                  Skeleton(height: 120),
                  SizedBox(height: 12),
                  Skeleton(height: 120),
                ])
              : EmptyState(
                  icon: Icons.wifi_off,
                  title: 'Connexion interrompue',
                  message: _error!,
                  action: FilledButton(onPressed: _load, child: const Text('Réessayer')),
                ))
          : RefreshIndicator(
              color: ZColors.primary,
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: items.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
                      child: Text(
                        'Rejoignez les communautés qui vous intéressent : leurs publications composent votre fil '
                        '« Pour vous ».',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: ZColors.muted),
                      ),
                    );
                  }
                  final c = items[i - 1];
                  return FadeSlideIn(
                    index: i,
                    child: _CommunityTile(
                      community: c,
                      busy: _busy.contains(c.id),
                      onOpen: () => Navigator.of(context).pop(c.id),
                      onToggle: () => _toggle(c),
                      onNotifications: () => _notifications(c),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _CommunityTile extends StatelessWidget {
  const _CommunityTile({
    required this.community,
    required this.busy,
    required this.onOpen,
    required this.onToggle,
    required this.onNotifications,
  });

  final Community community;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onToggle;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final c = community;
    final members = c.memberCount == 0
        ? 'Soyez parmi les premiers membres'
        : (c.memberCount == 1 ? '1 membre' : '${c.memberCount} membres');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: c.joined ? ZColors.primary : ZColors.line, width: c.joined ? 1.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: ZColors.primarySoft, borderRadius: BorderRadius.circular(14)),
                  child: Icon(communityIcon(c.icon), color: ZColors.primaryDark),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.name, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text(c.description,
                        maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 6),
                    Text(members,
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: ZColors.muted)),
                  ]),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                TextButton(onPressed: onOpen, child: const Text('Voir les publications')),
                const Spacer(),
                if (c.joined)
                  IconButton(
                    icon: Icon(c.notifLevel == 'none' ? Icons.notifications_off_outlined : Icons.notifications_outlined,
                        color: ZColors.primaryDark),
                    tooltip: 'Notifications de ${c.name}',
                    onPressed: onNotifications,
                  ),
                AnimatedSwitcher(
                  duration: ZMotion.of(context, ZMotion.fast),
                  child: c.joined
                      ? OutlinedButton.icon(
                          key: const ValueKey('joined'),
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                          onPressed: busy ? null : onToggle,
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Membre'),
                        )
                      : FilledButton(
                          key: const ValueKey('join'),
                          style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 40), backgroundColor: ZColors.primaryDark),
                          onPressed: busy ? null : onToggle,
                          child: const Text('Rejoindre'),
                        ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
