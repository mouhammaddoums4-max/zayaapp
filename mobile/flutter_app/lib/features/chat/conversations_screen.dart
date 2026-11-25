import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app.dart';
import '../../core/l10n/l10n.dart';
import '../../core/motion.dart';
import '../../core/phone_mask.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../discovery/profile_widgets.dart';
import '../likes/likes_screen.dart';
import '../safety/safety_sheets.dart';
import 'chat_screen.dart';
import 'ended_matches_screen.dart';

/// Onglet Messages : grand titre, recherche parmi les matchs, nouveaux matchs en vignettes (précédés des likes
/// reçus), demandes de re-match, puis les conversations sur une feuille blanche. La messagerie est réservée aux
/// matchs réciproques.
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key, required this.onDiscover});
  final VoidCallback onDiscover;

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

/// Matchs, places de conversation (« 1/5 ») et demandes de re-match reçues (migration 0040).
class _Donnees {
  const _Donnees(this.matches, this.places, this.demandes);
  final List<MatchSummary> matches;
  final ({int active, int limit})? places;
  final List<RematchRequest> demandes;
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  late Future<_Donnees> _future = _charger();
  final TextEditingController _search = TextEditingController();
  String _query = '';

  Future<_Donnees> _charger() async {
    final repo = Session.read(context).repo;
    final matches = await repo.matches();
    ({int active, int limit})? places;
    var demandes = const <RematchRequest>[];
    try {
      places = await repo.conversationSlots();
      demandes = await repo.rematchRequests();
    } catch (_) {
      // Serveur sans la migration 0040 : la liste des conversations reste utilisable.
    }
    return _Donnees(matches, places, demandes);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    final session = Session.read(context);
    setState(() {
      _future = _charger();
    });
    session.refreshBadges();
  }

  Future<void> _repondre(RematchRequest demande, {required bool accepter}) async {
    try {
      await Session.read(context).repo.respondRematch(demande.matchId, accept: accepter);
      if (!mounted) return;
      showZayaSnack(context,
          accepter ? 'Le match avec ${demande.displayName} a repris.' : 'Demande de ${demande.displayName} refusée.');
      _reload();
    } catch (e) {
      if (mounted) showZayaSnack(context, friendlyError(e), error: true);
    }
  }

  Future<void> _open(MatchSummary match) async {
    await Navigator.of(context).push(zRoute<void>(ChatScreen(match: match)));
    if (mounted) _reload();
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

  String _when(DateTime? time) {
    if (time == null) return '';
    final local = time.toLocal();
    final now = DateTime.now();
    final sameDay = local.year == now.year && local.month == now.month && local.day == now.day;
    return sameDay ? formatTime(time) : formatDate(time).substring(0, 5);
  }

  String _placesLibres(({int active, int limit}) p) {
    final libres = p.limit - p.active;
    if (libres <= 0) return 'Complet';
    return libres == 1 ? '1 place libre' : '$libres places libres';
  }

  /// L'aperçu ne révèle jamais un numéro de téléphone.
  String _preview(String body) => splitPhones(body).map((s) => s.isPhone ? maskPhone(s.text) : s.text).join();

  /// Recherche sans tenir compte des majuscules ni des accents (« aissatou » trouve « Aïssatou »).
  static String _fold(String text) {
    const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ';
    const to = 'aaaaaaceeeeiiiinooooouuuuyyoa';
    final lower = text.toLowerCase();
    final out = StringBuffer();
    for (final ch in lower.split('')) {
      final i = from.indexOf(ch);
      out.write(i < 0 ? ch : to[i]);
    }
    return out.toString();
  }

  bool _matchesQuery(String name) => _query.isEmpty || _fold(name).contains(_fold(_query));

  @override
  Widget build(BuildContext context) {
    final likes = Session.of(context).likesBadge;
    return Scaffold(
      backgroundColor: ZColors.bg,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<_Donnees>(
          future: _future,
          builder: (context, snapshot) {
            final header = _Header(
              onSafety: () => Navigator.of(context).push(zRoute<void>(const SafetyTipsScreen())),
              onEnded: () async {
                await Navigator.of(context).push(zRoute<void>(const EndedMatchesScreen()));
                if (mounted) _reload();
              },
            );
            if (snapshot.connectionState != ConnectionState.done) {
              return Column(children: [header, const Expanded(child: _ListSkeleton())]);
            }
            final donnees = snapshot.data;
            final items = donnees?.matches;
            if (snapshot.hasError || donnees == null || items == null) {
              return Column(children: [
                header,
                Expanded(
                  child: EmptyState(
                    icon: Icons.wifi_off,
                    title: 'Connexion interrompue',
                    message: 'Impossible de charger vos conversations.',
                    action: FilledButton(onPressed: _reload, child: const Text('Réessayer')),
                  ),
                ),
              ]);
            }
            final fresh = [
              for (final m in items)
                if (m.lastAt == null && _matchesQuery(m.displayName)) m,
            ];
            final talks = [
              for (final m in items)
                if (m.lastAt != null && _matchesQuery(m.displayName)) m,
            ];
            final searching = _query.isNotEmpty;
            return RefreshIndicator(
              color: ZColors.primary,
              onRefresh: () async => _reload(),
              child: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(), slivers: [
                SliverToBoxAdapter(child: header),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                    child: _SearchField(
                      controller: _search,
                      count: items.length,
                      onChanged: (v) => setState(() => _query = v.trim()),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _NewMatchesRow(likes: likes, fresh: fresh, onLikes: _openLikes, onOpen: _open),
                ),
                if (!searching && donnees.demandes.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        const _SectionLabel('Demandes pour reprendre'),
                        for (var i = 0; i < donnees.demandes.length; i++)
                          FadeSlideIn(
                            index: i,
                            child: _RematchCard(
                              demande: donnees.demandes[i],
                              onAccept: () => _repondre(donnees.demandes[i], accepter: true),
                              onRefuse: () => _repondre(donnees.demandes[i], accepter: false),
                            ),
                          ),
                      ]),
                    ),
                  ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _ConversationsSheet(
                    places: donnees.places,
                    placesLibres: donnees.places == null ? null : _placesLibres(donnees.places!),
                    children: [
                      for (var i = 0; i < talks.length; i++) ...[
                        if (i > 0) const Divider(indent: 96, endIndent: 20, height: 1),
                        FadeSlideIn(
                          index: i,
                          child: _ConversationTile(
                            match: talks[i],
                            preview: talks[i].lastMessage == null ? 'Message retiré' : _preview(talks[i].lastMessage!),
                            retired: talks[i].lastMessage == null,
                            when: _when(talks[i].lastAt),
                            onTap: () => _open(talks[i]),
                          ),
                        ),
                      ],
                      if (talks.isEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
                          child: Column(children: [
                            Icon(searching ? Icons.search_off_rounded : Icons.waving_hand_outlined,
                                size: 34, color: ZColors.primary.withValues(alpha: 0.7)),
                            const SizedBox(height: 10),
                            Text(
                              searching
                                  ? 'Aucun match ne correspond à « $_query ».'
                                  : 'Dites bonjour à vos nouveaux matchs : un premier message simple et sincère est souvent le meilleur.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ]),
                        ),
                    ],
                  ),
                ),
              ]),
            );
          },
        ),
      ),
    );
  }
}

/// Grand titre de l'onglet, avec les conseils de sécurité et les matchs terminés.
class _Header extends StatelessWidget {
  const _Header({required this.onSafety, required this.onEnded});
  final VoidCallback onSafety;
  final VoidCallback onEnded;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 8, 8),
        child: Row(children: [
          Expanded(
            child: Text('Messages',
                style: GoogleFonts.sora(fontSize: 30, fontWeight: FontWeight.w700, color: ZColors.ink, height: 1.1)),
          ),
          IconButton(
            icon: const Icon(Icons.shield_outlined, size: 27),
            color: ZColors.ink,
            tooltip: 'Conseils de sécurité',
            onPressed: onSafety,
          ),
          IconButton(
            icon: const Icon(Icons.heart_broken_outlined, size: 26),
            color: ZColors.ink,
            tooltip: context.s.endedMatchesTitle,
            onPressed: onEnded,
          ),
        ]),
      );
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.count, required this.onChanged});
  final TextEditingController controller;
  final int count;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: ZColors.ink),
          decoration: InputDecoration(
            hintText: count == 0
                ? 'Rechercher une conversation'
                : count == 1
                    ? 'Rechercher parmi 1 match'
                    : 'Rechercher parmi $count matchs',
            hintStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: ZColors.muted),
            prefixIcon: const Icon(Icons.search_rounded, color: ZColors.muted),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, color: ZColors.muted),
                    tooltip: 'Effacer la recherche',
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(99),
              borderSide: const BorderSide(color: ZColors.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(99),
              borderSide: const BorderSide(color: ZColors.primary, width: 1.5),
            ),
          ),
        ),
      );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: Text(text, style: GoogleFonts.sora(fontSize: 19, fontWeight: FontWeight.w700, color: ZColors.ink)),
      );
}

/// Largeur et hauteur d'une vignette de nouveau match.
const double _tileWidth = 92;
const double _tileHeight = 126;

/// Nouveaux matchs (sans message encore) en grandes vignettes, précédés des likes reçus ; des emplacements vides
/// complètent la rangée pour montrer où arriveront les prochains matchs.
class _NewMatchesRow extends StatelessWidget {
  const _NewMatchesRow({required this.likes, required this.fresh, required this.onLikes, required this.onOpen});
  final int likes;
  final List<MatchSummary> fresh;
  final VoidCallback onLikes;
  final ValueChanged<MatchSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      if (likes > 0) _LikesTile(count: likes, onTap: onLikes),
      for (final m in fresh) _NewMatchTile(match: m, onTap: () => onOpen(m)),
    ];
    final placeholders = math.max(0, 4 - tiles.length);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(padding: EdgeInsets.fromLTRB(20, 6, 20, 0), child: _SectionLabel('Nouveaux matchs')),
      SizedBox(
        height: _tileHeight + 34,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            for (var i = 0; i < tiles.length; i++)
              Padding(padding: const EdgeInsets.only(right: 12), child: _PopIn(index: i, child: tiles[i])),
            for (var i = 0; i < placeholders; i++)
              const Padding(padding: EdgeInsets.only(right: 12), child: _EmptyTile()),
          ],
        ),
      ),
    ]);
  }
}

/// Apparition d'une vignette : elle grandit légèrement en se dévoilant, l'une après l'autre.
class _PopIn extends StatelessWidget {
  const _PopIn({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (ZMotion.reduced(context)) return child;
    final delay = 70.0 * math.min(index, 6);
    final total = 380 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: total.round()),
      curve: Interval(delay / total, 1, curve: Curves.easeOutBack),
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0).toDouble(),
        child: Transform.scale(scale: 0.82 + 0.18 * t, child: child),
      ),
    );
  }
}

class _NewMatchTile extends StatelessWidget {
  const _NewMatchTile({required this.match, required this.onTap});
  final MatchSummary match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Nouveau match : ${match.displayName}',
        excludeSemantics: true,
        child: PressScale(
          onTap: onTap,
          child: SizedBox(
            width: _tileWidth,
            child: Column(children: [
              Container(
                width: _tileWidth,
                height: _tileHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [BoxShadow(color: Color(0x141B1020), blurRadius: 14, offset: Offset(0, 4))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(fit: StackFit.expand, children: [
                    ProfilePhotoView(name: match.displayName, photoPath: match.photoPath, initialSize: 48),
                    if (match.isVerified)
                      const Positioned(
                        right: 6,
                        bottom: 6,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: Padding(padding: EdgeInsets.all(1.5), child: VerifiedBadge(size: 18)),
                        ),
                      ),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
              Text(match.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: ZColors.ink)),
            ]),
          ),
        ),
      );
}

/// Likes reçus : vignette floutée (aucune identité n'est montrée ici), entourée d'un liseré doré dont le reflet fait
/// un tour de temps en temps (pas en continu : la batterie est épargnée). Elle ouvre la liste des likes, dont l'accès
/// aux identités dépend du forfait (contrôlé par le serveur).
class _LikesTile extends StatefulWidget {
  const _LikesTile({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  State<_LikesTile> createState() => _LikesTileState();
}

class _LikesTileState extends State<_LikesTile> with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
  Timer? _first;
  Timer? _every;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = ZMotion.reduced(context);
    if (reduced) {
      _first?.cancel();
      _every?.cancel();
      _first = _every = null;
      _turn.value = 0;
    } else if (_every == null) {
      _first = Timer(const Duration(milliseconds: 700), _shine);
      _every = Timer.periodic(const Duration(seconds: 6), (_) => _shine());
    }
  }

  void _shine() {
    if (mounted) _turn.forward(from: 0);
  }

  @override
  void dispose() {
    _first?.cancel();
    _every?.cancel();
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.count;
    final label = count == 1 ? '1 like' : '$count likes';
    return Semantics(
      button: true,
      label: count == 1 ? '1 personne a aimé votre profil' : '$count personnes ont aimé votre profil',
      excludeSemantics: true,
      child: PressScale(
        onTap: widget.onTap,
        child: SizedBox(
          width: _tileWidth,
          child: Column(children: [
            AnimatedBuilder(
              animation: _turn,
              builder: (context, child) => Container(
                width: _tileWidth,
                height: _tileHeight,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: SweepGradient(
                    transform: GradientRotation(Curves.easeInOutCubic.transform(_turn.value) * 2 * math.pi),
                    colors: const [
                      Color(0xFFE9C46A),
                      ZColors.premium,
                      Color(0xFFFFE7A8),
                      ZColors.premium,
                      Color(0xFFE9C46A)
                    ],
                  ),
                  boxShadow: const [BoxShadow(color: Color(0x33C8962E), blurRadius: 14, offset: Offset(0, 5))],
                ),
                child: child,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: Stack(fit: StackFit.expand, children: [
                  // Taches de couleur adoucies : évoque une photo floutée sans rien montrer de réel.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF8E5B6B), Color(0xFF3B2430)],
                      ),
                    ),
                  ),
                  const Positioned(left: -10, top: 6, child: _Blob(size: 70, color: Color(0xFFE38AA6))),
                  const Positioned(right: -14, top: 40, child: _Blob(size: 64, color: Color(0xFFB98A55))),
                  const Positioned(left: 18, bottom: -12, child: _Blob(size: 60, color: Color(0xFF6E3A55))),
                  Center(
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: Center(
                        child: Text(count > 99 ? '99+' : '$count',
                            style: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w700, color: ZColors.ink)),
                      ),
                    ),
                  ),
                  const Positioned(
                    right: 7,
                    top: 7,
                    child: Icon(Icons.favorite_rounded, size: 18, color: Colors.white),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: ZColors.ink)),
          ]),
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color.withValues(alpha: 0.9), color.withValues(alpha: 0)]),
        ),
      );
}

/// Emplacement vide de la rangée des nouveaux matchs.
class _EmptyTile extends StatelessWidget {
  const _EmptyTile();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Column(children: [
          Container(
            width: _tileWidth,
            height: _tileHeight,
            decoration: BoxDecoration(
              color: const Color(0xFFF3EAEF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.favorite_border_rounded, size: 26, color: ZColors.primary.withValues(alpha: 0.18)),
          ),
          const SizedBox(height: 8),
        ]),
      );
}

/// Demande de re-match reçue : accepter (le match reprend) ou refuser.
class _RematchCard extends StatelessWidget {
  const _RematchCard({required this.demande, required this.onAccept, required this.onRefuse});
  final RematchRequest demande;
  final VoidCallback onAccept;
  final VoidCallback onRefuse;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ZColors.line),
        ),
        child: Row(children: [
          RemoteAvatar(name: demande.displayName, photoPath: demande.photoPath, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(demande.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: ZColors.ink)),
              const SizedBox(height: 2),
              Text('souhaite reprendre la conversation', style: Theme.of(context).textTheme.bodyMedium),
            ]),
          ),
          IconButton(
            style: IconButton.styleFrom(side: const BorderSide(color: ZColors.line)),
            icon: const Icon(Icons.close_rounded, color: ZColors.ink),
            tooltip: 'Refuser',
            onPressed: onRefuse,
          ),
          const SizedBox(width: 4),
          IconButton(
            style: IconButton.styleFrom(backgroundColor: ZColors.primary),
            icon: const Icon(Icons.favorite_rounded, color: Colors.white),
            tooltip: 'Accepter',
            onPressed: onAccept,
          ),
        ]),
      );
}

/// Feuille blanche des conversations, aux coins hauts arrondis, avec le nombre de conversations actives.
class _ConversationsSheet extends StatelessWidget {
  const _ConversationsSheet({required this.children, this.places, this.placesLibres});
  final List<Widget> children;
  final ({int active, int limit})? places;
  final String? placesLibres;

  @override
  Widget build(BuildContext context) {
    final places = this.places;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      // Fond blanc uni, sans panneau arrondi ni ombre : la liste se fond dans la page.
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
          child: Row(children: [
            Expanded(
              child: Text('Conversations',
                  style: GoogleFonts.sora(fontSize: 19, fontWeight: FontWeight.w700, color: ZColors.ink)),
            ),
            if (places != null)
              Tooltip(
                message: placesLibres ?? '',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: ZColors.primarySoft, borderRadius: BorderRadius.circular(99)),
                  child: Text('${places.active}/${places.limit} actives',
                      style:
                          GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: ZColors.primaryDark)),
                ),
              ),
          ]),
        ),
        if (placesLibres != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Text(placesLibres!, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ...children,
        const SizedBox(height: 24),
      ]),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.match,
    required this.preview,
    required this.when,
    required this.onTap,
    this.retired = false,
  });
  final MatchSummary match;
  final String preview;
  final String when;
  final VoidCallback onTap;
  final bool retired;

  @override
  Widget build(BuildContext context) {
    final unread = match.unread > 0;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(children: [
          // Avatar : anneau au dégradé de marque et pastille du nombre de messages quand il y a du nouveau.
          SizedBox(
            width: 68,
            height: 68,
            child: Stack(clipBehavior: Clip.none, children: [
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: unread ? ZColors.brandGradient : null,
                ),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: RemoteAvatar(name: match.displayName, photoPath: match.photoPath, size: 59),
                ),
              ),
              if (unread)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 22),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: ZColors.primary,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text(match.unread > 9 ? '9+' : '${match.unread}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                  ),
                ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(match.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: ZColors.ink)),
                ),
                if (match.isVerified) ...[const SizedBox(width: 5), const VerifiedBadge(size: 18)],
              ]),
              const SizedBox(height: 4),
              Text(preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontStyle: retired ? FontStyle.italic : FontStyle.normal,
                      fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                      color: unread ? ZColors.ink : ZColors.muted)),
            ]),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(when,
                style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                    color: unread ? ZColors.primaryDark : ZColors.muted)),
            const SizedBox(height: 6),
            // Affiche explicitement qu'au moins un message entrant n'a pas encore été lu.
            if (unread)
              Semantics(
                label: 'Message non lu',
                child: Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.only(top: 4, right: 2, bottom: 6),
                  decoration: const BoxDecoration(color: ZColors.primary, shape: BoxShape.circle),
                ),
              )
            else
              const SizedBox(height: 24),
          ]),
        ]),
      ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) => ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const Skeleton(height: 50, radius: 25),
          const SizedBox(height: 20),
          Row(children: [
            for (var i = 0; i < 3; i++) ...[
              const Skeleton(width: _tileWidth, height: _tileHeight, radius: 18),
              const SizedBox(width: 12),
            ],
          ]),
          const SizedBox(height: 24),
          for (var i = 0; i < 4; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Row(children: [
                Skeleton(width: 64, height: 64, radius: 32),
                SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Skeleton(width: 140, height: 14, radius: 7),
                    SizedBox(height: 8),
                    Skeleton(height: 12, radius: 6),
                  ]),
                ),
              ]),
            ),
        ],
      );
}
