import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart' show blockedCategoryLabels;
import 'zaya2_api.dart';

/// Mieux se connaître : réponses facultatives sur le mariage. Chaque réponse est privée par défaut ;
/// la personne choisit qui peut la lire (moi seul, mes matchs, membres vérifiés), règle appliquée par le serveur.
class QuestionsScreen extends StatefulWidget {
  const QuestionsScreen({super.key, this.focusQuestionId});

  /// Question à ouvrir directement (surprise du jour).
  final int? focusQuestionId;

  @override
  State<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends State<QuestionsScreen> {
  late final Zaya2Api _api = Zaya2Api.of(context);
  late Future<(String, List<MarriageQuestion>)> _data = _api.questions();
  bool _focusDone = false;

  void _reload() => setState(() {
        _data = _api.questions();
      });

  String _visibilityLabel(String? v) => switch (v) {
        'matches' => tr(context, 'Mes matchs', 'My matches'),
        'verified' => tr(context, 'Membres vérifiés', 'Verified members'),
        _ => tr(context, 'Moi seul', 'Only me'),
      };

  Future<void> _edit(MarriageQuestion q) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AnswerEditor(question: q, api: _api, visibilityLabel: _visibilityLabel),
    );
    if (changed == true) _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(tr(context, 'Mieux se connaître', 'Get to know each other'))),
        body: FutureBuilder<(String, List<MarriageQuestion>)>(
          future: _data,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return ListView(padding: const EdgeInsets.all(16), children: [
                for (var i = 0; i < 4; i++) ...[const Skeleton(height: 96), const SizedBox(height: 12)],
              ]);
            }
            if (snap.hasError) {
              return EmptyState(
                icon: Icons.wifi_off,
                title: tr(context, 'Connexion interrompue', 'Connection lost'),
                message: friendlyError(snap.error!),
                action: FilledButton(onPressed: _reload, child: Text(tr(context, 'Réessayer', 'Try again'))),
              );
            }
            final (status, questions) = snap.data!;
            if (status != 'ready') {
              return EmptyState(
                icon: Icons.forum_outlined,
                title: tr(context, 'Questions indisponibles', 'Questions unavailable'),
                message: tr(context, 'Revenez un peu plus tard.', 'Please come back later.'),
              );
            }
            final focus = widget.focusQuestionId;
            if (!_focusDone && focus != null) {
              _focusDone = true;
              final q = questions.where((q) => q.id == focus).firstOrNull;
              if (q != null) WidgetsBinding.instance.addPostFrameCallback((_) => _edit(q));
            }
            return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
              FadeSlideIn(
                child: InfoBanner(
                  icon: Icons.lock_outline,
                  text: tr(
                      context,
                      'Vos réponses sont privées par défaut. Vous choisissez, pour chacune, qui peut la lire. '
                          'Elles ne servent jamais à la publicité.',
                      'Your answers are private by default. For each one, you choose who can read it. '
                          'They are never used for advertising.'),
                ),
              ),
              const SizedBox(height: 14),
              for (final (i, q) in questions.indexed)
                FadeSlideIn(
                  index: i + 1,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: PressScale(
                      onTap: () => _edit(q),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: q.answer == null ? ZColors.line : ZColors.primary.withValues(alpha: 0.4)),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(tr(context, q.textFr, q.textEn), style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 6),
                          Text(
                            q.answer ?? tr(context, 'Pas encore de réponse', 'No answer yet'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: q.answer == null
                                ? Theme.of(context).textTheme.bodyMedium
                                : GoogleFonts.inter(fontSize: 14, color: ZColors.ink),
                          ),
                          const SizedBox(height: 8),
                          Wrap(spacing: 6, runSpacing: 6, children: [
                            if (q.answer != null)
                              _Tag(icon: Icons.visibility_outlined, text: _visibilityLabel(q.visibility)),
                            if (q.sensitive)
                              _Tag(icon: Icons.shield_outlined, text: tr(context, 'Sensible', 'Sensitive')),
                          ]),
                        ]),
                      ),
                    ),
                  ),
                ),
            ]);
          },
        ),
      );
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: ZColors.primarySoft, borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: ZColors.primaryDark),
          const SizedBox(width: 4),
          Text(text, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: ZColors.primaryDark)),
        ]),
      );
}

class _AnswerEditor extends StatefulWidget {
  const _AnswerEditor({required this.question, required this.api, required this.visibilityLabel});
  final MarriageQuestion question;
  final Zaya2Api api;
  final String Function(String?) visibilityLabel;

  @override
  State<_AnswerEditor> createState() => _AnswerEditorState();
}

class _AnswerEditorState extends State<_AnswerEditor> {
  late final _text = TextEditingController(text: widget.question.answer ?? '');
  late String _visibility = widget.question.visibility ?? 'me';
  String? _blocked;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_text.text.trim().isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final blocked = await widget.api.answerQuestion(widget.question.id, _text.text, _visibility);
      if (!mounted) return;
      if (blocked != null) {
        setState(() => _blocked = blocked);
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) showZayaSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    try {
      await widget.api.deleteAnswer(widget.question.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showZayaSnack(context, friendlyError(e), error: true);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tr(context, q.textFr, q.textEn), style: Theme.of(context).textTheme.titleMedium),
          if (q.sensitive) ...[
            const SizedBox(height: 10),
            InfoBanner(
              icon: Icons.shield_outlined,
              text: tr(context, 'Question sensible : choisissez avec soin qui peut lire votre réponse.',
                  'Sensitive question: choose carefully who can read your answer.'),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _text,
            minLines: 3,
            maxLines: 6,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) {
              if (_blocked != null) setState(() => _blocked = null);
            },
            decoration: InputDecoration(hintText: tr(context, 'Votre réponse…', 'Your answer…')),
          ),
          if (_blocked != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InfoBanner(
                tone: BannerTone.danger,
                icon: Icons.error_outline,
                text: tr(
                    context,
                    'Réponse refusée : ${blockedCategoryLabels[_blocked] ?? 'contenu non autorisé'}. Les numéros et les liens ne sont pas permis.',
                    'Answer refused: phone numbers, links and forbidden content are not allowed.'),
              ),
            ),
          Text(tr(context, 'Qui peut lire cette réponse ?', 'Who can read this answer?'),
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              for (final v in const ['me', 'matches', 'verified'])
                ButtonSegment<String>(value: v, label: Text(widget.visibilityLabel(v), textAlign: TextAlign.center)),
            ],
            selected: {_visibility},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _visibility = s.first),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(tr(context, 'Enregistrer', 'Save')),
          ),
          if (q.answer != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: ZColors.danger),
              onPressed: _busy ? null : _delete,
              icon: const Icon(Icons.delete_outline),
              label: Text(tr(context, 'Supprimer ma réponse', 'Delete my answer')),
            ),
          ],
        ]),
      ),
    );
  }
}
