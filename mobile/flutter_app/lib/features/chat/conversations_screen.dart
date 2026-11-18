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
import 'chat_screen.dart';
import 'ended_matches_screen.dart';

/// Onglet Messages : nouveaux matchs en haut, conversations en dessous.
/// La messagerie est réservée aux matchs réciproques.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages'), actions: [
        IconButton(
          icon: const Icon(Icons.heart_broken_outlined),
          tooltip: context.s.endedMatchesTitle,
          onPressed: () async {
            await Navigator.of(context).push(zRoute<void>(const EndedMatchesScreen()));
            if (mounted) _reload();
          },
        ),
        const SizedBox(width: 4),
      ]),
      body: FutureBuilder<_Donnees>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const _ListSkeleton();
          final donnees = snapshot.data;
          final items = donnees?.matches;
          if (snapshot.hasError || donnees == null || items == null) {
            return EmptyState(
              icon: Icons.wifi_off,
              title: 'Connexion interrompue',
              message: 'Impossible de charger vos conversations.',
              action: FilledButton(onPressed: _reload, child: const Text('Réessayer')),
            );
          }
          if (items.isEmpty && donnees.demandes.isEmpty) {
            return EmptyState(
              icon: Icons.chat_bubble_outline,
              title: 'Aucune conversation',
              message: 'La messagerie s’ouvre après un match : lorsque deux personnes s’aiment mutuellement.',
              action: OutlinedButton(onPressed: widget.onDiscover, child: const Text('Découvrir des profils')),
            );
          }
          final fresh = [
            for (final m in items)
              if (m.lastAt == null) m,
          ];
          final talks = [
            for (final m in items)
              if (m.lastAt != null) m,
          ];
          return RefreshIndicator(
            color: ZColors.primary,
            onRefresh: () async => _reload(),
            child: ListView(children: [
              if (donnees.demandes.isNotEmpty) ...[
                const Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 0), child: SectionTitle('Demandes pour reprendre')),
                for (final d in donnees.demandes)
                  ListTile(
                    leading: RemoteAvatar(name: d.displayName, photoPath: d.photoPath, size: 44),
                    title: Text(d.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text('souhaite reprendre la conversation'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Refuser',
                        onPressed: () => _repondre(d, accepter: false),
                      ),
                      IconButton(
                        icon: const Icon(Icons.favorite, color: ZColors.primary),
                        tooltip: 'Accepter',
                        onPressed: () => _repondre(d, accepter: true),
                      ),
                    ]),
                  ),
              ],
              if (fresh.isNotEmpty) ...[
                const Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 0), child: SectionTitle('Nouveaux matchs')),
                SizedBox(
                  height: 112,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: fresh.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (context, i) => FadeSlideIn(
                      index: i,
                      child: _NewMatch(match: fresh[i], onTap: () => _open(fresh[i])),
                    ),
                  ),
                ),
              ],
              if (talks.isNotEmpty || donnees.places != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: SectionTitle(
                    donnees.places == null
                        ? 'Conversations'
                        : 'Conversations actives (${donnees.places!.active}/${donnees.places!.limit})',
                    trailing: donnees.places == null
                        ? null
                        : Text(_placesLibres(donnees.places!),
                            style: const TextStyle(fontWeight: FontWeight.w600, color: ZColors.muted)),
                  ),
                ),
              for (var i = 0; i < talks.length; i++)
                FadeSlideIn(
                  index: i,
                  child: _ConversationTile(
                    match: talks[i],
                    preview: talks[i].lastMessage == null ? 'Message retiré' : _preview(talks[i].lastMessage!),
                    when: _when(talks[i].lastAt),
                    onTap: () => _open(talks[i]),
                  ),
                ),
              if (talks.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: Text(
                    'Dites bonjour à vos nouveaux matchs : un premier message simple et sincère est souvent le meilleur.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
            ]),
          );
        },
      ),
    );
  }
}

class _NewMatch extends StatelessWidget {
  const _NewMatch({required this.match, required this.onTap});
  final MatchSummary match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Nouveau match : ${match.displayName}',
        child: PressScale(
          onTap: onTap,
          child: SizedBox(
            width: 76,
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(gradient: ZColors.brandGradient, shape: BoxShape.circle),
                child: Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: RemoteAvatar(name: match.displayName, photoPath: match.photoPath, size: 64),
                ),
              ),
              const SizedBox(height: 6),
              Text(match.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: ZColors.ink)),
            ]),
          ),
        ),
      );
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.match, required this.preview, required this.when, required this.onTap});
  final MatchSummary match;
  final String preview;
  final String when;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = match.unread > 0;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          RemoteAvatar(name: match.displayName, photoPath: match.photoPath, size: 56),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(match.displayName,
                      overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
                ),
                if (match.isVerified) ...[const SizedBox(width: 4), const VerifiedBadge(size: 16)],
              ]),
              const SizedBox(height: 3),
              Text(preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                      color: unread ? ZColors.ink : ZColors.muted)),
            ]),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(when, style: GoogleFonts.inter(fontSize: 12, color: unread ? ZColors.primaryDark : ZColors.muted)),
            const SizedBox(height: 5),
            if (unread)
              Container(
                constraints: const BoxConstraints(minWidth: 20),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: ZColors.primary, borderRadius: BorderRadius.circular(99)),
                child: Text('${match.unread}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
              )
            else
              const SizedBox(height: 18),
          ]),
        ]),
      ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) => ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Row(children: [
            Skeleton(width: 56, height: 56, radius: 28),
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
      );
}
