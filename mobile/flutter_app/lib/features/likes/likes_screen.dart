import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../discovery/like_actions.dart';
import '../discovery/profile_widgets.dart';
import '../premium/premium_screens.dart';

class _LikesData {
  const _LikesData({required this.count, required this.premium, required this.profiles});
  final int count;
  final bool premium;
  final List<DiscoveryProfile> profiles;
}

const _gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  mainAxisSpacing: 12,
  crossAxisSpacing: 12,
  childAspectRatio: 0.72,
);

/// Onglet Likes : les personnes qui ont aimé mon profil.
/// Gratuit : le nombre uniquement (aucune identité n'est transmise à l'application).
/// Premium : la liste, sous réserve des réglages de confidentialité de chacun.
class LikesScreen extends StatefulWidget {
  const LikesScreen({super.key, required this.onDiscover});
  final VoidCallback onDiscover;

  @override
  State<LikesScreen> createState() => _LikesScreenState();
}

class _LikesScreenState extends State<LikesScreen> {
  late Future<_LikesData> _future = _load();

  Future<_LikesData> _load() async {
    final session = Session.read(context);
    final count = await session.repo.receivedInterestsCount();
    final premium = session.me?.isPremium ?? false;
    var profiles = const <DiscoveryProfile>[];
    if (premium && count > 0) profiles = await session.repo.receivedInterests();
    return _LikesData(count: count, premium: premium, profiles: profiles);
  }

  void _reload() => setState(() {
        _future = _load();
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Likes')),
      body: FutureBuilder<_LikesData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: _gridDelegate,
              itemCount: 4,
              itemBuilder: (_, __) => const Skeleton(radius: 20),
            );
          }
          final data = snapshot.data;
          if (snapshot.hasError || data == null) {
            return EmptyState(
              icon: Icons.wifi_off,
              title: 'Connexion interrompue',
              message: 'Impossible de charger vos likes.',
              action: FilledButton(onPressed: _reload, child: const Text('Réessayer')),
            );
          }
          if (data.count == 0) {
            return EmptyState(
              icon: Icons.favorite_border,
              title: 'Pas encore de like',
              message: 'Lorsqu’une personne aimera votre profil, vous le saurez ici. '
                  'Un profil complet et vérifié est plus souvent consulté.',
              action: OutlinedButton(onPressed: widget.onDiscover, child: const Text('Découvrir des profils')),
            );
          }
          return RefreshIndicator(
            color: ZColors.primary,
            onRefresh: () async => _reload(),
            child: data.premium ? _premiumList(context, data) : _freeView(context, data),
          );
        },
      ),
    );
  }

  String _headline(int count) =>
      count == 1 ? '1 personne a aimé votre profil' : '$count personnes ont aimé votre profil';

  Widget _premiumList(BuildContext context, _LikesData data) {
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Text(_headline(data.count), style: Theme.of(context).textTheme.titleLarge),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        sliver: SliverGrid.builder(
          gridDelegate: _gridDelegate,
          itemCount: data.profiles.length,
          itemBuilder: (context, i) {
            final p = data.profiles[i];
            return FadeSlideIn(
              index: i,
              child: ProfileTile(
                profile: p,
                heroTag: 'likes-${p.id}',
                onTap: () async {
                  await openProfileWithActions(context, p, heroTag: 'likes-${p.id}');
                  if (mounted) _reload();
                },
              ),
            );
          },
        ),
      ),
    ]);
  }

  Widget _freeView(BuildContext context, _LikesData data) {
    final shown = data.count > 6 ? 6 : data.count;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
      FadeSlideIn(
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(gradient: ZColors.brandGradient, borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            const Icon(Icons.favorite, color: Colors.white, size: 34),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_headline(data.count),
                    style:
                        GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white, height: 1.25)),
                const SizedBox(height: 4),
                Text('Si vous aimez l’une d’elles dans Découvrir, le match est immédiat.',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.95), height: 1.35)),
              ]),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: _gridDelegate,
        itemCount: shown,
        itemBuilder: (context, i) => FadeSlideIn(index: i + 1, child: const _HiddenLikeTile()),
      ),
      const SizedBox(height: 18),
      Text(
        'L’identité des personnes qui vous ont aimé fait partie de ZAYA Premium. '
        'Les matchs réciproques, eux, restent toujours gratuits et visibles.',
        style: Theme.of(context).textTheme.bodyMedium,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 14),
      GradientButton(label: 'Parcourir les profils', icon: Icons.style, onPressed: widget.onDiscover),
      const SizedBox(height: 8),
      TextButton(
        onPressed: () => Navigator.of(context).push(zRoute<void>(const PremiumScreen())),
        child: const Text('En savoir plus sur ZAYA Premium'),
      ),
    ]);
  }
}

/// Vignette masquée : l'application ne reçoit ni photo ni nom pour un compte Gratuit.
class _HiddenLikeTile extends StatelessWidget {
  const _HiddenLikeTile();

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Profil masqué',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFD3E0), Color(0xFFF8A9C4)],
              ),
            ),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.7), shape: BoxShape.circle),
                  child: const Icon(Icons.lock_outline, color: ZColors.primaryDark, size: 26),
                ),
                const SizedBox(height: 10),
                Text('Profil masqué',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: ZColors.primaryDark)),
              ]),
            ),
          ),
        ),
      );
}
