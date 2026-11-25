import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../ads/feed_ads.dart';
import 'communities_screen.dart';
import 'community_widgets.dart';
import 'compose_post_screen.dart';
import 'post_detail_screen.dart';
import 'saved_posts_screen.dart';

const _rulesSeenKey = 'zaya_community_rules_seen';

/// Onglet Communauté (CDC V2.3 §2–3, V6.0 §26) : un espace modéré pour échanger conseils et
/// expériences autour du mariage. Pastilles de filtre en haut (« Pour vous » et communautés suivies),
/// fil de publications, bouton « Publier ».
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  static const _pageSize = 20;

  List<Community> _communities = const <Community>[];
  String? _selected;
  List<CommunityPost> _posts = const <CommunityPost>[];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _disabled = false;
  bool _showRules = false;
  String? _error;
  int _generation = 0;

  /// Cartes publicitaires du fil (campagnes directes, sinon Google), au rythme fixé par le serveur.
  FeedAds? _ads;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _load();
      _ads = FeedAds.forRepository('community_feed', Session.read(context).repo)
        ..addListener(_onAds)
        ..load();
    });
    SharedPreferences.getInstance().then((prefs) {
      if (mounted && prefs.getBool(_rulesSeenKey) != true) setState(() => _showRules = true);
    }, onError: (_) {});
  }

  void _onAds() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ads
      ?..removeListener(_onAds)
      ..dispose();
    super.dispose();
  }

  Community? get _selectedCommunity {
    for (final c in _communities) {
      if (c.id == _selected) return c;
    }
    return null;
  }

  Future<void> _load() async {
    final repo = Session.read(context).repo;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final communities = await repo.communities();
      final posts = await repo.communityFeed(communityId: _selected);
      if (!mounted || generation != _generation) return;
      setState(() {
        _communities = communities;
        _posts = posts;
        _hasMore = posts.length >= _pageSize;
        _loading = false;
        _disabled = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      final disabled = e.toString().contains('COMMUNITY_DISABLED');
      setState(() {
        _loading = false;
        _disabled = disabled;
        _error = disabled ? null : friendlyError(e);
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _posts.isEmpty) return;
    final repo = Session.read(context).repo;
    setState(() => _loadingMore = true);
    try {
      final more = await repo.communityFeed(communityId: _selected, before: _posts.last.createdAt);
      if (!mounted) return;
      setState(() {
        _posts = [..._posts, ...more];
        _hasMore = more.length >= _pageSize;
      });
    } catch (e) {
      if (mounted) showZayaSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _select(String? communityId) {
    if (communityId == _selected) return;
    setState(() => _selected = communityId);
    _load();
  }

  void _apply(CommunityPost target, PostChange change) =>
      setState(() => _posts = applyPostChange(_posts, target, change));

  Future<void> _dismissRules() async {
    setState(() => _showRules = false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_rulesSeenKey, true);
    } catch (_) {
      // Préférence non enregistrée : le message sera simplement réaffiché.
    }
  }

  Future<void> _compose() async {
    final published = await Navigator.of(context)
        .push<bool>(zRoute<bool>(ComposePostScreen(communities: _communities, initialCommunityId: _selected)));
    if (published == true && mounted) {
      showZayaSnack(context, 'Publication en ligne.');
      await _load();
    }
  }

  Future<void> _openCommunities() async {
    final picked = await Navigator.of(context).push<String>(zRoute<String>(const CommunitiesScreen()));
    if (!mounted) return;
    if (picked != null) _selected = picked;
    await _load();
  }

  Future<void> _open(CommunityPost post) async {
    final change = await Navigator.of(context).push<PostChange>(zRoute<PostChange>(PostDetailScreen(post: post)));
    if (!mounted) return;
    if (change != null) {
      _apply(post, change);
      return;
    }
    // Retour simple : la publication est relue (commentaires, réactions), ou retirée si elle n'est plus visible.
    try {
      final fresh = await Session.read(context).repo.communityPost(post.id);
      if (mounted) _apply(post, PostChange.updated(fresh));
    } catch (_) {
      if (mounted) _apply(post, PostChange.removed());
    }
  }

  Future<void> _toggleJoin(Community community) async {
    final repo = Session.read(context).repo;
    try {
      if (community.joined) {
        await repo.leaveCommunity(community.id);
      } else {
        await repo.joinCommunity(community.id);
      }
      final communities = await repo.communities();
      if (mounted) setState(() => _communities = communities);
    } catch (e) {
      if (mounted) showZayaSnack(context, friendlyError(e), error: true);
    }
  }

  Future<void> _notifications(Community community) async {
    final level = await showCommunityNotifications(context, community);
    if (level == null || !mounted) return;
    setState(() {
      _communities = [for (final c in _communities) c.id == community.id ? c.copyWith(notifLevel: level) : c];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Communauté'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_border),
            tooltip: 'Publications enregistrées',
            onPressed: () => Navigator.of(context).push(zRoute<void>(const SavedPostsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Règles de la communauté',
            onPressed: () => showCommunityRules(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: _disabled
          ? null
          : FloatingActionButton.extended(
              heroTag: 'community-compose',
              backgroundColor: ZColors.primaryDark,
              foregroundColor: Colors.white,
              onPressed: _compose,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Publier'),
            ),
      body: _disabled
          ? const EmptyState(
              icon: Icons.groups_outlined,
              title: 'La communauté ouvrira bientôt',
              message: 'Cet espace d’échange ouvrira dès que l’équipe de modération sera en place.',
            )
          : RefreshIndicator(
              color: ZColors.primary,
              onRefresh: _load,
              child: CustomScrollView(slivers: [
                SliverToBoxAdapter(child: _filterRow()),
                if (_showRules)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: InfoBanner(
                        icon: Icons.waving_hand_outlined,
                        text: 'Bienvenue dans la communauté : un espace pour échanger conseils et expériences, avec '
                            'bienveillance. Pas de coordonnées ni de recherche de partenaire ici.',
                        action: Row(children: [
                          TextButton(
                            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                            onPressed: () => showCommunityRules(context),
                            child: const Text('Lire les règles', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 16),
                          TextButton(
                            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                            onPressed: _dismissRules,
                            child: const Text('J’ai compris', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ]),
                      ),
                    ),
                  ),
                if (_selectedCommunity != null)
                  SliverToBoxAdapter(
                    child: _CommunityHeader(
                      community: _selectedCommunity!,
                      onToggle: () => _toggleJoin(_selectedCommunity!),
                      onNotifications: () => _notifications(_selectedCommunity!),
                    ),
                  )
                else if (!_loading && _error == null && !_communities.any((c) => c.joined))
                  SliverToBoxAdapter(child: _JoinPrompt(onTap: _openCommunities)),
                ..._feed(),
                const SliverToBoxAdapter(child: SizedBox(height: 96)),
              ]),
            ),
    );
  }

  Widget _filterRow() {
    final joined = _communities.where((c) => c.joined).toList();
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        children: [
          _Pill(label: 'Pour vous', icon: Icons.auto_awesome, selected: _selected == null, onTap: () => _select(null)),
          for (final c in joined)
            _Pill(
              label: c.name,
              icon: communityIcon(c.icon),
              selected: _selected == c.id,
              onTap: () => _select(c.id),
            ),
          if (_selected != null && !joined.any((c) => c.id == _selected) && _selectedCommunity != null)
            _Pill(
              label: _selectedCommunity!.name,
              icon: communityIcon(_selectedCommunity!.icon),
              selected: true,
              onTap: () {},
            ),
          _Pill(label: 'Communautés', icon: Icons.add, selected: false, outlined: true, onTap: _openCommunities),
        ],
      ),
    );
  }

  List<Widget> _feed() {
    if (_loading && _posts.isEmpty) {
      return [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.list(children: const [
            PostSkeleton(),
            SizedBox(height: 12),
            PostSkeleton(),
          ]),
        ),
      ];
    }
    if (_error != null && _posts.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.wifi_off,
            title: 'Connexion interrompue',
            message: _error!,
            action: FilledButton(onPressed: _load, child: const Text('Réessayer')),
          ),
        ),
      ];
    }
    if (_posts.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.forum_outlined,
            title: 'Aucune publication',
            message: 'Posez la première question ou partagez un conseil utile à la communauté.',
            action: FilledButton(onPressed: _compose, child: const Text('Publier')),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList.builder(
          itemCount: _posts.length,
          itemBuilder: (context, i) {
            final post = _posts[i];
            final tile = Padding(
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
            final ads = _ads;
            final slot = ads?.slotAfter(i);
            if (ads == null || slot == null) return tile;
            return Column(mainAxisSize: MainAxisSize.min, children: [
              tile,
              FeedAdSlot(ads: ads, slot: slot, padding: const EdgeInsets.only(bottom: 12)),
            ]);
          },
        ),
      ),
      if (_hasMore)
        SliverToBoxAdapter(
          child: Center(
            child: _loadingMore
                ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())
                : TextButton(onPressed: _loadMore, child: const Text('Voir plus de publications')),
          ),
        ),
    ];
  }
}

/// Pastille de filtre : la couleur pleine marque la sélection, avec une transition douce.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.outlined = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool outlined;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : (outlined ? ZColors.primaryDark : ZColors.ink);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: selected,
        child: PressScale(
          onTap: onTap,
          child: AnimatedContainer(
            duration: ZMotion.of(context, ZMotion.fast),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: selected ? ZColors.primaryDark : Colors.white,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                  color: selected ? ZColors.primaryDark : (outlined ? ZColors.primaryDark : ZColors.line),
                  width: outlined ? 1.4 : 1),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 17, color: foreground),
              const SizedBox(width: 6),
              Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: foreground)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _CommunityHeader extends StatelessWidget {
  const _CommunityHeader({required this.community, required this.onToggle, required this.onNotifications});
  final Community community;
  final VoidCallback onToggle;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final c = community;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: FadeSlideIn(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(gradient: ZColors.brandGradient, borderRadius: BorderRadius.circular(20)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), shape: BoxShape.circle),
                child: Icon(communityIcon(c.icon), color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(c.name,
                    style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ]),
            const SizedBox(height: 8),
            Text(c.description,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.white.withValues(alpha: 0.95), height: 1.4)),
            const SizedBox(height: 10),
            Row(children: [
              Text(c.memberCount <= 1 ? '${c.memberCount} membre' : '${c.memberCount} membres',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              const Spacer(),
              if (c.joined)
                IconButton(
                  icon: Icon(c.notifLevel == 'none' ? Icons.notifications_off_outlined : Icons.notifications_outlined,
                      color: Colors.white),
                  tooltip: 'Notifications de cette communauté',
                  onPressed: onNotifications,
                ),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  backgroundColor: Colors.white,
                  foregroundColor: ZColors.primaryDark,
                ),
                onPressed: onToggle,
                child: Text(c.joined ? 'Membre ✓' : 'Rejoindre'),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _JoinPrompt extends StatelessWidget {
  const _JoinPrompt({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: ZColors.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: ZColors.primarySoft, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.groups_outlined, color: ZColors.primaryDark),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Choisissez vos communautés', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text('Votre fil « Pour vous » montrera leurs publications.',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ]),
                ),
                const Icon(Icons.chevron_right, color: ZColors.muted),
              ]),
            ),
          ),
        ),
      );
}
