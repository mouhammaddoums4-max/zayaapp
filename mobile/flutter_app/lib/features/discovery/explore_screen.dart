import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../ads/feed_ads.dart';
import '../likes/likes_screen.dart';
import 'like_actions.dart';
import 'profile_widgets.dart';

/// Une sélection thématique de profils, calculée à partir du fil (déjà filtré par le serveur
/// selon les préférences réciproques) et des informations réellement renseignées.
class _Collection {
  const _Collection({required this.title, required this.subtitle, required this.icon, required this.test});
  final String title;
  final String subtitle;
  final IconData icon;
  final bool Function(DiscoveryProfile profile) test;
}

List<_Collection> _collectionsFor(MyProfile? me) {
  final collections = <_Collection>[
    _Collection(
      title: 'Mariage à court terme',
      subtitle: 'Bientôt ou dans les prochains mois',
      icon: Icons.event_available_outlined,
      test: (p) => p.horizon == 'soon' || p.horizon == 'few_months',
    ),
  ];
  final city = me?.city;
  if (city != null) {
    final inConakry = city.startsWith('Conakry');
    collections.add(_Collection(
      title: 'Près de chez vous',
      subtitle: inConakry ? 'À Conakry' : city,
      icon: Icons.place_outlined,
      test: (p) => p.city == city || (inConakry && (p.city?.startsWith('Conakry') ?? false)),
    ));
  }
  final languages = me?.languages ?? const <String>[];
  if (languages.isNotEmpty) {
    collections.add(_Collection(
      title: 'Parlent votre langue',
      subtitle: languages.join(', '),
      icon: Icons.translate,
      test: (p) => p.languages.any(languages.contains),
    ));
  }
  final interests = me?.interests ?? const <String>[];
  if (interests.isNotEmpty) {
    collections.add(_Collection(
      title: 'Mêmes centres d’intérêt',
      subtitle: interests.take(3).join(', '),
      icon: Icons.palette_outlined,
      test: (p) => p.interests.any(interests.contains),
    ));
  }
  collections.add(_Collection(
    title: 'Prennent leur temps',
    subtitle: 'À moyen terme ou sans date précise',
    icon: Icons.hourglass_empty,
    test: (p) => p.horizon == 'medium_term' || p.horizon == 'no_date',
  ));
  return collections;
}

const _gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  mainAxisSpacing: 12,
  crossAxisSpacing: 12,
  childAspectRatio: 0.72,
);

/// Onglet Explorer : likes reçus en tête, sélections thématiques et grille de tous les profils proposés.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key, required this.onDiscover});

  /// Ramène à l'onglet Découvrir (depuis l'écran des likes).
  final VoidCallback onDiscover;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  /// Cartes publicitaires de la grille (campagnes directes, sinon Google), au rythme fixé par le serveur.
  late final FeedAds _ads = FeedAds.forRepository('explore', Session.read(context).repo);

  @override
  void initState() {
    super.initState();
    final feed = Session.read(context).feed;
    if (!feed.loaded && !feed.loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => feed.load());
    }
    _ads
      ..addListener(_onAds)
      ..load();
  }

  void _onAds() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ads
      ..removeListener(_onAds)
      ..dispose();
    super.dispose();
  }

  /// Grille « Tous les profils » découpée en tranches, avec une carte publicitaire entre deux tranches ; une seule
  /// grille si la régie est éteinte.
  List<Widget> _profileGrid(List<DiscoveryProfile> profiles) {
    final every = _ads.settings.everyFor('explore');
    final chunk = every > 0 ? every : max(profiles.length, 1);
    final slivers = <Widget>[];
    for (var start = 0; start < profiles.length; start += chunk) {
      final end = min(start + chunk, profiles.length);
      final first = start;
      slivers.add(SliverPadding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, end == profiles.length ? 24 : 12),
        sliver: SliverGrid.builder(
          gridDelegate: _gridDelegate,
          itemCount: end - first,
          itemBuilder: (context, j) {
            final i = first + j;
            final p = profiles[i];
            return FadeSlideIn(
              key: ValueKey<String>(p.id),
              index: i,
              child: ProfileTile(
                profile: p,
                heroTag: 'explore-${p.id}',
                onTap: () => openProfileWithActions(context, p, heroTag: 'explore-${p.id}'),
              ),
            );
          },
        ),
      ));
      final slot = end < profiles.length ? _ads.slotAfter(end - 1) : null;
      if (slot != null) {
        slivers.add(SliverToBoxAdapter(
          child: FeedAdSlot(ads: _ads, slot: slot, padding: const EdgeInsets.fromLTRB(16, 0, 16, 12)),
        ));
      }
    }
    return slivers;
  }

  Future<void> _openLikes() async {
    final navigator = Navigator.of(context);
    final session = Session.read(context);
    await navigator.push(zRoute<void>(LikesScreen(onDiscover: () {
      navigator.pop();
      widget.onDiscover();
    })));
    session.refreshBadges();
  }

  Future<void> _refresh() async {
    final session = Session.read(context);
    await session.feed.load();
    await session.refreshBadges();
  }

  @override
  Widget build(BuildContext context) {
    final session = Session.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Explorer')),
      body: ListenableBuilder(
        listenable: session.feed,
        builder: (context, _) {
          final feed = session.feed;
          final likes = SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: _LikesCard(count: session.likesBadge, onTap: _openLikes),
            ),
          );
          final Widget? placeholder;
          if (feed.loading && feed.profiles.isEmpty) {
            placeholder = null;
          } else if (feed.error != null && feed.profiles.isEmpty) {
            placeholder = EmptyState(
              icon: Icons.wifi_off,
              title: 'Connexion interrompue',
              message: feed.error!,
              action: FilledButton(onPressed: feed.load, child: const Text('Réessayer')),
            );
          } else if (feed.profiles.isEmpty) {
            placeholder = EmptyState(
              icon: Icons.explore_outlined,
              title: 'Rien à explorer pour le moment',
              message: 'Les profils qui correspondent à vos préférences apparaîtront ici.',
              action: OutlinedButton(onPressed: feed.load, child: const Text('Actualiser')),
            );
          } else {
            placeholder = const SizedBox.shrink();
          }
          if (placeholder == null || feed.profiles.isEmpty) {
            return RefreshIndicator(
              color: ZColors.primary,
              onRefresh: _refresh,
              child: CustomScrollView(slivers: [
                likes,
                if (placeholder == null)
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverGrid.builder(
                      gridDelegate: _gridDelegate,
                      itemCount: 4,
                      itemBuilder: (_, __) => const Skeleton(radius: 20),
                    ),
                  )
                else
                  SliverFillRemaining(hasScrollBody: false, child: placeholder),
              ]),
            );
          }
          final collections = [
            for (final c in _collectionsFor(session.me))
              if (feed.profiles.any(c.test)) c,
          ];
          return RefreshIndicator(
            color: ZColors.primary,
            onRefresh: _refresh,
            child: CustomScrollView(slivers: [
              likes,
              if (collections.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child:
                      Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 0), child: SectionTitle('Sélections pour vous')),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 138,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: collections.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, i) {
                        final c = collections[i];
                        return FadeSlideIn(
                          index: i,
                          child: _CollectionCard(
                            collection: c,
                            count: feed.profiles.where(c.test).length,
                            onTap: () => Navigator.of(context)
                                .push(zRoute<void>(ProfileGridScreen(title: c.title, test: c.test))),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
              const SliverToBoxAdapter(
                child: Padding(padding: EdgeInsets.fromLTRB(16, 14, 16, 0), child: SectionTitle('Tous les profils')),
              ),
              ..._profileGrid(feed.profiles),
            ]),
          );
        },
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.collection, required this.count, required this.onTap});
  final _Collection collection;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '${collection.title}, $count ${count > 1 ? 'profils' : 'profil'}',
        child: PressScale(
          onTap: onTap,
          child: Container(
            width: 190,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(gradient: ZColors.brandGradient, borderRadius: BorderRadius.circular(20)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), shape: BoxShape.circle),
                  child: Icon(collection.icon, color: Colors.white, size: 20),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)),
                  child: Text('$count',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: ZColors.primaryDark)),
                ),
              ]),
              const Spacer(),
              Text(collection.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, height: 1.2)),
              const SizedBox(height: 3),
              Text(collection.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.9))),
            ]),
          ),
        ),
      );
}

/// Carte des likes reçus : le nombre est gratuit et réel (jamais de faux like) ; l'identité des
/// personnes fait partie de Premium (CDC V3.0 §4.2–4.3).
class _LikesCard extends StatelessWidget {
  const _LikesCard({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = switch (count) {
      0 => 'Vos likes',
      1 => '1 personne a aimé votre profil',
      _ => '$count personnes ont aimé votre profil',
    };
    final subtitle = count == 0
        ? 'Les personnes qui aimeront votre profil apparaîtront ici.'
        : 'Aimez-les en retour dans Découvrir : le match est immédiat.';
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      excludeSemantics: true,
      onTap: onTap,
      child: PressScale(
        pressedScale: 0.97,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: count > 0 ? ZColors.brandGradient : null,
            color: count > 0 ? null : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: count > 0 ? null : Border.all(color: ZColors.line),
          ),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: count > 0 ? Colors.white.withValues(alpha: 0.22) : ZColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(count > 0 ? Icons.favorite : Icons.favorite_border,
                  color: count > 0 ? Colors.white : ZColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style: GoogleFonts.sora(
                        fontSize: 16, fontWeight: FontWeight.w700, color: count > 0 ? Colors.white : ZColors.ink)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.35,
                        color: count > 0 ? Colors.white.withValues(alpha: 0.95) : ZColors.muted)),
              ]),
            ),
            Icon(Icons.chevron_right, color: count > 0 ? Colors.white : ZColors.muted),
          ]),
        ),
      ),
    );
  }
}

/// Grille des profils d'une sélection. Se met à jour quand un profil est aimé, passé ou bloqué.
class ProfileGridScreen extends StatelessWidget {
  const ProfileGridScreen({super.key, required this.title, required this.test});
  final String title;
  final bool Function(DiscoveryProfile profile) test;

  @override
  Widget build(BuildContext context) {
    final session = Session.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListenableBuilder(
        listenable: session.feed,
        builder: (context, _) {
          final items = session.feed.profiles.where(test).toList();
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.check_circle_outline,
              title: 'Vous avez tout vu',
              message: 'Il n’y a plus de profil dans cette sélection pour le moment.',
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: _gridDelegate,
            itemCount: items.length,
            itemBuilder: (context, i) {
              final p = items[i];
              return FadeSlideIn(
                key: ValueKey<String>(p.id),
                index: i,
                child: ProfileTile(
                  profile: p,
                  heroTag: 'collection-${p.id}',
                  onTap: () => openProfileWithActions(context, p, heroTag: 'collection-${p.id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
