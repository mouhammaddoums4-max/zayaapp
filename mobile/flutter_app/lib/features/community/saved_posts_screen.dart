import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import 'community_widgets.dart';
import 'post_detail_screen.dart';

/// Publications enregistrées par le membre (favoris, CDC V2.3 §2.2).
class SavedPostsScreen extends StatefulWidget {
  const SavedPostsScreen({super.key});

  @override
  State<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  List<CommunityPost>? _posts;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = Session.read(context).repo;
    try {
      final posts = await repo.savedPosts();
      if (mounted) {
        setState(() {
          _posts = posts;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  void _apply(CommunityPost target, PostChange change) {
    final posts = _posts;
    if (posts == null) return;
    setState(() {
      final next = applyPostChange(posts, target, change);
      // Une publication retirée des enregistrements quitte cette liste.
      _posts = next.where((p) => p.saved).toList();
    });
  }

  Future<void> _open(CommunityPost post) async {
    final change = await Navigator.of(context).push<PostChange>(zRoute<PostChange>(PostDetailScreen(post: post)));
    if (!mounted) return;
    if (change != null) {
      _apply(post, change);
    } else {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final posts = _posts;
    return Scaffold(
      appBar: AppBar(title: const Text('Publications enregistrées')),
      body: posts == null
          ? (_error == null
              ? ListView(padding: const EdgeInsets.all(16), children: const [PostSkeleton()])
              : EmptyState(
                  icon: Icons.wifi_off,
                  title: 'Connexion interrompue',
                  message: _error!,
                  action: FilledButton(onPressed: _load, child: const Text('Réessayer')),
                ))
          : posts.isEmpty
              ? const EmptyState(
                  icon: Icons.bookmark_border,
                  title: 'Aucune publication enregistrée',
                  message: 'Appuyez sur le signet d’une publication pour la retrouver ici.',
                )
              : RefreshIndicator(
                  color: ZColors.primary,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.paddingOf(context).bottom),
                    itemCount: posts.length,
                    itemBuilder: (context, i) {
                      final post = posts[i];
                      return Padding(
                        key: ValueKey<String>(post.id),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: FadeSlideIn(
                          index: i,
                          child: PostTile(
                            post: post,
                            onChanged: (change) => _apply(post, change),
                            onOpen: () => _open(post),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
