import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/l10n/l10n.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import 'chat_screen.dart';

/// Matchs terminés (CARTE_ECRANS E01, cahier des charges §32) : explication, puis la liste.
/// Ni photo ni accès au profil : seul le nom reste, pour relire l'historique et signaler si besoin.
class EndedMatchesScreen extends StatefulWidget {
  const EndedMatchesScreen({super.key});

  @override
  State<EndedMatchesScreen> createState() => _EndedMatchesScreenState();
}

class _EndedMatchesScreenState extends State<EndedMatchesScreen> {
  late Future<List<EndedMatch>> _ended = Session.read(context).repo.endedMatches();

  void _reload() {
    final next = Session.read(context).repo.endedMatches();
    setState(() {
      _ended = next;
    });
  }

  Future<void> _open(EndedMatch m) async {
    final s = context.s;
    await Navigator.of(context).push(zRoute<void>(ChatScreen(
      ended: true,
      match: MatchSummary(matchId: m.matchId, userId: m.userId, displayName: m.displayName ?? s.accountClosed),
    )));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      appBar: AppBar(title: Text(s.endedMatchesTitle)),
      body: FutureBuilder<List<EndedMatch>>(
        future: _ended,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.wifi_off,
              title: s.loadError,
              message: '',
              action: OutlinedButton(onPressed: _reload, child: Text(s.retry)),
            );
          }
          final ended = snapshot.data ?? const <EndedMatch>[];
          return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 28), children: [
            InfoBanner(icon: Icons.info_outline, text: s.endedMatchesExplain),
            const SizedBox(height: 14),
            if (ended.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Column(children: [
                  const Icon(Icons.heart_broken_outlined, size: 44, color: ZColors.muted),
                  const SizedBox(height: 12),
                  Text(s.endedMatchesEmptyTitle, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(s.endedMatchesEmptyBody,
                      textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                ]),
              )
            else
              for (var i = 0; i < ended.length; i++)
                FadeSlideIn(
                  index: i,
                  child: _EndedTile(match: ended[i], onTap: () => _open(ended[i])),
                ),
          ]);
        },
      ),
    );
  }
}

class _EndedTile extends StatelessWidget {
  const _EndedTile({required this.match, required this.onTap});
  final EndedMatch match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final name = match.displayName ?? s.accountClosed;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: ZColors.line,
        child: match.accountClosed
            ? const Icon(Icons.person_off_outlined, color: ZColors.muted)
            : Text(name.characters.first.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w700, color: ZColors.muted)),
      ),
      title: Text(name, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(s.endedMatchSubtitle(formatDate(match.endedAt), byMe: match.endedByMe)),
      trailing: const Icon(Icons.chevron_right, color: ZColors.muted),
      onTap: onTap,
    );
  }
}
