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

class _ConversationsScreenState extends State<ConversationsScreen> {
  late Future<List<MatchSummary>> _future = Session.read(context).repo.matches();

  void _reload() {
    final session = Session.read(context);
    setState(() {
      _future = session.repo.matches();
    });
    session.refreshBadges();
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
      body: FutureBuilder<List<MatchSummary>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const _ListSkeleton();
          final items = snapshot.data;
          if (snapshot.hasError || items == null) {
            return EmptyState(
              icon: Icons.wifi_off,
              title: 'Connexion interrompue',
              message: 'Impossible de charger vos conversations.',
              action: FilledButton(onPressed: _reload, child: const Text('Réessayer')),
            );
          }
          if (items.isEmpty) {
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
              if (talks.isNotEmpty)
                const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 0), child: SectionTitle('Conversations')),
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
