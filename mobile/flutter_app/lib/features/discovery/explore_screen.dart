import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
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

/// Onglet Explorer : sélections thématiques et grille de tous les profils proposés.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  @override
  void initState() {
    super.initState();
    final feed = Session.read(context).feed;
    if (!feed.loaded && !feed.loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => feed.load());
    }
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
          if (feed.loading && feed.profiles.isEmpty) return const _GridSkeleton();
          if (feed.error != null && feed.profiles.isEmpty) {
            return EmptyState(
              icon: Icons.wifi_off,
              title: 'Connexion interrompue',
              message: feed.error!,
              action: FilledButton(onPressed: feed.load, child: const Text('Réessayer')),
            );
          }
          if (feed.profiles.isEmpty) {
            return EmptyState(
              icon: Icons.explore_outlined,
              title: 'Rien à explorer pour le moment',
              message: 'Les profils qui correspondent à vos préférences apparaîtront ici.',
              action: OutlinedButton(onPressed: feed.load, child: const Text('Actualiser')),
            );
          }
          final collections = [
            for (final c in _collectionsFor(session.me))
              if (feed.profiles.any(c.test)) c,
          ];
          return RefreshIndicator(
            color: ZColors.primary,
            onRefresh: feed.load,
            child: CustomScrollView(slivers: [
              if (collections.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 0), child: SectionTitle('Sélections pour vous')),
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
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverGrid.builder(
                  gridDelegate: _gridDelegate,
                  itemCount: feed.profiles.length,
                  itemBuilder: (context, i) {
                    final p = feed.profiles[i];
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
              ),
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

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) => GridView.builder(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: _gridDelegate,
        itemCount: 6,
        itemBuilder: (_, __) => const Skeleton(radius: 20),
      );
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
