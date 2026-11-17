import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../profile/verification_screen.dart';
import '../safety/safety_sheets.dart';
import 'community_widgets.dart';

/// Une publication et ses commentaires. Se ferme en renvoyant un [PostChange] quand la publication
/// doit disparaître de la liste (supprimée, masquée, signalée, auteur bloqué) ; sinon `null`.
class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key, required this.post});
  final CommunityPost post;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late CommunityPost _post = widget.post;
  List<PostComment>? _comments;
  String? _error;
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  PostComment? _editing;
  String? _blockedCategory;

  /// Erreur d'envoi affichée au-dessus du champ (un message en bas d'écran masquerait le bouton d'envoi).
  String? _sendError;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Fait défiler jusqu'au dernier commentaire, pour montrer celui qui vient d'être publié.
  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      if (ZMotion.reduced(context)) {
        _scroll.jumpTo(target);
      } else {
        _scroll.animateTo(target, duration: ZMotion.slow, curve: ZMotion.emphasized);
      }
    });
  }

  Future<void> _loadComments() async {
    final repo = Session.read(context).repo;
    try {
      final comments = await repo.postComments(_post.id);
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _error = null;
        _post = _post.copyWith(commentCount: comments.length);
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  void _onPostChange(PostChange change) {
    if (change.removed) {
      Navigator.of(context).pop(change);
    } else {
      setState(() => _post = change.post!);
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    final repo = Session.read(context).repo;
    final editing = _editing;
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      final result =
          editing == null ? await repo.addComment(_post.id, text) : await repo.editComment(editing.id, text);
      if (!mounted) return;
      if (result.isBlocked) {
        setState(() => _blockedCategory = result.blockedCategory);
        return;
      }
      _input.clear();
      setState(() {
        _blockedCategory = null;
        _editing = null;
      });
      FocusScope.of(context).unfocus();
      await _loadComments();
      if (editing == null) _scrollToEnd();
    } catch (e) {
      if (mounted) setState(() => _sendError = friendlyError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startEditing(PostComment comment) {
    setState(() {
      _editing = comment;
      _blockedCategory = null;
    });
    _input.text = comment.body;
    _input.selection = TextSelection.collapsed(offset: _input.text.length);
    _focus.requestFocus();
  }

  void _cancelEditing() {
    _input.clear();
    setState(() {
      _editing = null;
      _blockedCategory = null;
    });
  }

  Future<void> _commentMenu(PostComment comment) async {
    final repo = Session.read(context).repo;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (comment.isMine) ...[
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Modifier'),
              onTap: () => Navigator.of(sheetContext).pop('edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: ZColors.danger),
              title: const Text('Supprimer', style: TextStyle(color: ZColors.danger)),
              onTap: () => Navigator.of(sheetContext).pop('delete'),
            ),
          ] else ...[
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: ZColors.danger),
              title: const Text('Signaler le commentaire'),
              onTap: () => Navigator.of(sheetContext).pop('report'),
            ),
            ListTile(
              leading: const Icon(Icons.block, color: ZColors.danger),
              title: Text('Bloquer ${comment.authorName}'),
              onTap: () => Navigator.of(sheetContext).pop('block'),
            ),
          ],
        ]),
      ),
    );
    if (action == null || !mounted) return;
    try {
      switch (action) {
        case 'edit':
          _startEditing(comment);
        case 'delete':
          await repo.deleteComment(comment.id);
          if (mounted) showZayaSnack(context, 'Commentaire supprimé.');
          await _loadComments();
        case 'report':
          final sent = await showContentReportSheet(
            context,
            title: 'Signaler ce commentaire',
            subtitle: 'Votre signalement est confidentiel. Le commentaire disparaît aussitôt pour vous.',
            submit: (reason, details) => repo.reportComment(comment.id, reason: reason, details: details),
          );
          if (sent) await _loadComments();
        case 'block':
          final blocked = await confirmBlock(context, userId: comment.authorId, name: comment.authorName);
          if (!blocked || !mounted) return;
          if (comment.authorId == _post.authorId) {
            Navigator.of(context).pop(PostChange.authorBlocked(comment.authorId));
          } else {
            await _loadComments();
          }
      }
    } catch (e) {
      if (mounted) showZayaSnack(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = Session.of(context).me;
    final comments = _comments;
    final blocked = _blockedCategory;
    return Scaffold(
      appBar: AppBar(title: const Text('Publication')),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: RefreshIndicator(
              color: ZColors.primary,
              onRefresh: _loadComments,
              child: ListView(controller: _scroll, padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), children: [
                PostTile(post: _post, expanded: true, onChanged: _onPostChange),
                const SizedBox(height: 14),
                SectionTitle(comments == null ? 'Commentaires' : 'Commentaires (${comments.length})'),
                if (_error != null)
                  InfoBanner(tone: BannerTone.danger, icon: Icons.error_outline, text: _error!)
                else if (comments == null)
                  const Column(children: [
                    Skeleton(height: 64),
                    SizedBox(height: 10),
                    Skeleton(height: 64),
                  ])
                else if (comments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Text(
                      _post.commentsEnabled
                          ? 'Aucun commentaire pour le moment. Partagez votre avis avec bienveillance.'
                          : 'Aucun commentaire.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                else
                  for (var i = 0; i < comments.length; i++)
                    FadeSlideIn(
                      key: ValueKey<String>(comments[i].id),
                      index: i,
                      distance: 10,
                      child: _CommentTile(comment: comments[i], onMenu: () => _commentMenu(comments[i])),
                    ),
              ]),
            ),
          ),
          if (_post.commentsEnabled) ...[
            if (me != null && !me.isVerified)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: InfoBanner(
                  tone: BannerTone.warning,
                  icon: Icons.verified_outlined,
                  text: 'Pour commenter, votre profil doit d’abord être vérifié.',
                  action: TextButton(
                    style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 30),
                        foregroundColor: const Color(0xFF5C4100)),
                    onPressed: () => Navigator.of(context).push(zRoute<void>(const VerificationScreen())),
                    child: const Text('Vérifier mon profil  →', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            if (blocked != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: InfoBanner(
                  tone: BannerTone.danger,
                  icon: Icons.error_outline,
                  text: 'Votre commentaire n’a pas été publié : la charte ZAYA interdit '
                      '${blockedCategoryLabels[blocked] ?? 'ce type de contenu'}. Modifiez-le avant de l’envoyer.',
                ),
              ),
            if (_sendError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: InfoBanner(tone: BannerTone.danger, icon: Icons.error_outline, text: _sendError!),
              ),
            if (_editing != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
                child: Row(children: [
                  const Icon(Icons.edit_outlined, size: 18, color: ZColors.primaryDark),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Modification du commentaire',
                        style: TextStyle(fontWeight: FontWeight.w600, color: ZColors.primaryDark)),
                  ),
                  IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      tooltip: 'Annuler la modification',
                      onPressed: _cancelEditing),
                ]),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    focusNode: _focus,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 1000,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(color: blocked != null ? ZColors.danger : ZColors.ink),
                    decoration: const InputDecoration(hintText: 'Votre commentaire…', counterText: ''),
                    onChanged: (_) {
                      if (_blockedCategory != null || _sendError != null) {
                        setState(() {
                          _blockedCategory = null;
                          _sendError = null;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: ZColors.primaryDark,
                    disabledBackgroundColor: ZColors.primaryDark,
                    minimumSize: const Size(52, 52),
                  ),
                  icon: _sending
                      ? const SizedBox(
                          width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(_editing == null ? Icons.send : Icons.check, color: Colors.white),
                  tooltip: _editing == null ? 'Publier le commentaire' : 'Enregistrer la modification',
                  onPressed: _sending ? null : _send,
                ),
              ]),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: InfoBanner(
                icon: Icons.speaker_notes_off_outlined,
                text: 'Les commentaires sont désactivés par l’auteur de cette publication.',
              ),
            ),
        ]),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment, required this.onMenu});
  final PostComment comment;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final meta = '${formatRelative(comment.createdAt)}${comment.edited ? ' · modifié' : ''}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ProfileAvatar(name: comment.authorName, size: 34),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onLongPress: onMenu,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              decoration: BoxDecoration(
                color: comment.isMine ? ZColors.primarySoft : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: comment.isMine ? ZColors.primarySoft : ZColors.line),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(
                        child: Text(comment.isMine ? 'Vous' : comment.authorName,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: ZColors.ink)),
                      ),
                      if (comment.authorVerified && !comment.isMine) ...[
                        const SizedBox(width: 4),
                        const VerifiedBadge(size: 14),
                      ],
                    ]),
                    const SizedBox(height: 3),
                    Text(comment.body, style: GoogleFonts.inter(fontSize: 14, color: ZColors.ink, height: 1.4)),
                    const SizedBox(height: 4),
                    Text(meta, style: GoogleFonts.inter(fontSize: 11.5, color: ZColors.muted)),
                  ]),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.more_vert, size: 18, color: ZColors.muted),
                  tooltip: 'Options du commentaire',
                  onPressed: onMenu,
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
