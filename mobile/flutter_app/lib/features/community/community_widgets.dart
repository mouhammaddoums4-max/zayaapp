import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../safety/safety_sheets.dart';
import 'compose_post_screen.dart';

IconData communityIcon(String key) => switch (key) {
      'favorite' => Icons.favorite_border,
      'forum' => Icons.forum_outlined,
      'lightbulb' => Icons.lightbulb_outline,
      'family' => Icons.family_restroom,
      'school' => Icons.school_outlined,
      'event' => Icons.event_outlined,
      'help' => Icons.help_outline,
      'translate' => Icons.translate,
      _ => Icons.groups_outlined,
    };

IconData postKindIcon(String kind) => switch (kind) {
      'advice' => Icons.lightbulb_outline,
      'experience' => Icons.auto_stories_outlined,
      _ => Icons.help_outline,
    };

/// Modification d'une publication, renvoyée à la liste qui l'affiche pour qu'elle se mette à jour.
class PostChange {
  const PostChange._({this.post, this.removed = false, this.blockedAuthorId});

  /// La publication a changé (réaction, enregistrement, texte, commentaires).
  factory PostChange.updated(CommunityPost post) => PostChange._(post: post);

  /// La publication disparaît de la liste (supprimée, masquée, signalée).
  factory PostChange.removed() => const PostChange._(removed: true);

  /// L'auteur a été bloqué : toutes ses publications disparaissent.
  factory PostChange.authorBlocked(String authorId) => PostChange._(removed: true, blockedAuthorId: authorId);

  final CommunityPost? post;
  final bool removed;
  final String? blockedAuthorId;
}

List<CommunityPost> applyPostChange(List<CommunityPost> posts, CommunityPost target, PostChange change) {
  final blocked = change.blockedAuthorId;
  if (blocked != null) return posts.where((p) => p.authorId != blocked).toList();
  if (change.removed) return posts.where((p) => p.id != target.id).toList();
  final updated = change.post!;
  return [for (final p in posts) p.id == target.id ? updated : p];
}

/// Règles de la communauté (CDC V2.3 §2.4 et §2.6).
Future<void> showCommunityRules(BuildContext context) {
  const rules = <(IconData, String, String)>[
    (Icons.favorite_border, 'Bienveillance', 'Pas d’insultes, de menaces, de harcèlement ni de discours haineux.'),
    (Icons.no_adult_content, 'Aucun contenu sexuel', 'Ni nudité, ni contenu explicite, ni sollicitation.'),
    (Icons.payments_outlined, 'Jamais d’argent', 'Pas d’arnaque, de demande d’argent ni de publicité non autorisée.'),
    (Icons.lock_outline, 'Vie privée', 'Pas de coordonnées, ni de photos ou de conversations d’autres personnes.'),
    (
      Icons.people_outline,
      'Pas de recherche de partenaire',
      'La communauté sert à échanger. Les rencontres se font dans Découvrir.',
    ),
  ];
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text('Règles de la communauté', style: Theme.of(sheetContext).textTheme.titleLarge),
          const SizedBox(height: 14),
          for (final rule in rules)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: ZColors.primarySoft, borderRadius: BorderRadius.circular(12)),
                  child: Icon(rule.$1, color: ZColors.primaryDark, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(rule.$2, style: Theme.of(sheetContext).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(rule.$3, style: Theme.of(sheetContext).textTheme.bodyMedium),
                  ]),
                ),
              ]),
            ),
          const InfoBanner(
            icon: Icons.visibility_outlined,
            text: 'Les autres membres voient votre nom de profil et votre badge, jamais votre photo. '
                'Les publications signalées sont examinées par l’équipe de modération.',
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => Navigator.of(sheetContext).pop(), child: const Text('J’ai compris')),
        ]),
      ),
    ),
  );
}

/// Pastille de type de publication (question, conseil, expérience).
class PostKindChip extends StatelessWidget {
  const PostKindChip({super.key, required this.kind});
  final String kind;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (kind) {
      'advice' => (const Color(0xFFFFF4D6), const Color(0xFF5C4100)),
      'experience' => (const Color(0xFFE3F5EE), ZColors.success),
      _ => (ZColors.primarySoft, ZColors.primaryDark),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(postKindIcon(kind), size: 14, color: foreground),
        const SizedBox(width: 5),
        Text(postKindLabels[kind] ?? kind,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: foreground)),
      ]),
    );
  }
}

/// Bouton « J'aime » : le cœur rebondit et le compteur défile à chaque changement.
class ReactionButton extends StatelessWidget {
  const ReactionButton({super.key, required this.reacted, required this.count, required this.onTap});
  final bool reacted;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final duration = ZMotion.of(context, ZMotion.medium);
    return Semantics(
      button: true,
      label: '${reacted ? 'Retirer mon j’aime' : 'J’aime'} ($count)',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            AnimatedSwitcher(
              duration: duration,
              transitionBuilder: (child, animation) => ScaleTransition(
                scale:
                    Tween<double>(begin: 0.5, end: 1).chain(CurveTween(curve: Curves.easeOutBack)).animate(animation),
                child: child,
              ),
              child: Icon(reacted ? Icons.favorite : Icons.favorite_border,
                  key: ValueKey<bool>(reacted), color: reacted ? ZColors.primary : ZColors.muted, size: 22),
            ),
            const SizedBox(width: 6),
            AnimatedSwitcher(
              duration: duration,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(animation),
                  child: child,
                ),
              ),
              child: Text('$count',
                  key: ValueKey<int>(count),
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w600, color: reacted ? ZColors.primaryDark : ZColors.muted)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Carte d'une publication, avec ses actions (réagir, commenter, enregistrer, options).
/// Les changements remontent par [onChanged] : la liste parente reste la seule source de vérité.
class PostTile extends StatelessWidget {
  const PostTile({super.key, required this.post, required this.onChanged, this.onOpen, this.expanded = false});

  final CommunityPost post;
  final ValueChanged<PostChange> onChanged;
  final VoidCallback? onOpen;

  /// Texte complet (écran de détail) au lieu d'un aperçu de 6 lignes.
  final bool expanded;

  Future<void> _react(BuildContext context) async {
    final repo = Session.read(context).repo;
    final next = post.copyWith(
      reacted: !post.reacted,
      reactionCount: math.max(0, post.reactionCount + (post.reacted ? -1 : 1)),
    );
    HapticFeedback.lightImpact();
    onChanged(PostChange.updated(next));
    try {
      final count = await repo.reactToPost(post.id, next.reacted);
      onChanged(PostChange.updated(next.copyWith(reactionCount: count)));
    } catch (e) {
      onChanged(PostChange.updated(post));
      if (context.mounted) showZayaSnack(context, friendlyError(e), error: true);
    }
  }

  Future<void> _save(BuildContext context) async {
    final repo = Session.read(context).repo;
    final next = post.copyWith(saved: !post.saved);
    onChanged(PostChange.updated(next));
    try {
      await repo.savePost(post.id, next.saved);
      if (context.mounted) {
        showZayaSnack(context, next.saved ? 'Publication enregistrée.' : 'Publication retirée de vos enregistrements.');
      }
    } catch (e) {
      onChanged(PostChange.updated(post));
      if (context.mounted) showZayaSnack(context, friendlyError(e), error: true);
    }
  }

  Future<void> _menu(BuildContext context) async {
    final change = await showPostMenu(context, post);
    if (change != null) onChanged(change);
  }

  @override
  Widget build(BuildContext context) {
    final meta = '${post.communityName} · ${formatRelative(post.createdAt)}${post.edited ? ' · modifié' : ''}';
    final commentLabel = post.commentCount == 0 ? 'Commenter' : '${post.commentCount}';
    return Material(
      color: Colors.white,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: ZColors.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              ProfileAvatar(name: post.authorName, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(
                      child: Text(post.authorName,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: ZColors.ink)),
                    ),
                    if (post.authorVerified) ...[const SizedBox(width: 4), const VerifiedBadge(size: 16)],
                  ]),
                  const SizedBox(height: 1),
                  Text(meta,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium),
                ]),
              ),
              IconButton(
                icon: const Icon(Icons.more_horiz, color: ZColors.muted),
                tooltip: 'Options de la publication',
                onPressed: () => _menu(context),
              ),
            ]),
            const SizedBox(height: 10),
            PostKindChip(kind: post.kind),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                post.body,
                maxLines: expanded ? null : 6,
                overflow: expanded ? null : TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 15, color: ZColors.ink, height: 1.45),
              ),
            ),
            const SizedBox(height: 4),
            Transform.translate(
              offset: const Offset(-10, 0),
              child: Row(children: [
                ReactionButton(reacted: post.reacted, count: post.reactionCount, onTap: () => _react(context)),
                Semantics(
                  button: true,
                  label: post.commentCount == 0 ? 'Commenter' : '${post.commentCount} commentaires',
                  excludeSemantics: true,
                  onTap: onOpen,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(99),
                    onTap: onOpen,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.chat_bubble_outline, size: 20, color: ZColors.muted),
                        const SizedBox(width: 6),
                        Text(commentLabel,
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: ZColors.muted)),
                      ]),
                    ),
                  ),
                ),
                if (!post.commentsEnabled)
                  const Tooltip(
                    message: 'Commentaires désactivés par l’auteur',
                    child: Icon(Icons.speaker_notes_off_outlined, size: 18, color: ZColors.muted),
                  ),
                const Spacer(),
                IconButton(
                  icon: AnimatedSwitcher(
                    duration: ZMotion.of(context, ZMotion.fast),
                    child: Icon(post.saved ? Icons.bookmark : Icons.bookmark_border,
                        key: ValueKey<bool>(post.saved), color: post.saved ? ZColors.primary : ZColors.muted),
                  ),
                  tooltip: post.saved ? 'Retirer des enregistrements' : 'Enregistrer',
                  onPressed: () => _save(context),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Options d'une publication. Retourne le changement à appliquer, ou null si rien n'a changé.
Future<PostChange?> showPostMenu(BuildContext context, CommunityPost post) async {
  final repo = Session.read(context).repo;
  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (post.isMine) ...[
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Modifier'),
            onTap: () => Navigator.of(sheetContext).pop('edit'),
          ),
          ListTile(
            leading: Icon(post.commentsEnabled ? Icons.speaker_notes_off_outlined : Icons.chat_bubble_outline),
            title: Text(post.commentsEnabled ? 'Désactiver les commentaires' : 'Activer les commentaires'),
            onTap: () => Navigator.of(sheetContext).pop('comments'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: ZColors.danger),
            title: const Text('Supprimer', style: TextStyle(color: ZColors.danger)),
            onTap: () => Navigator.of(sheetContext).pop('delete'),
          ),
        ] else ...[
          ListTile(
            leading: const Icon(Icons.visibility_off_outlined),
            title: const Text('Masquer cette publication'),
            subtitle: const Text('Elle disparaît de votre fil uniquement.'),
            onTap: () => Navigator.of(sheetContext).pop('hide'),
          ),
          ListTile(
            leading: const Icon(Icons.flag_outlined, color: ZColors.danger),
            title: const Text('Signaler la publication'),
            onTap: () => Navigator.of(sheetContext).pop('report'),
          ),
          ListTile(
            leading: const Icon(Icons.block, color: ZColors.danger),
            title: Text('Bloquer ${post.authorName}'),
            onTap: () => Navigator.of(sheetContext).pop('block'),
          ),
        ],
      ]),
    ),
  );
  if (action == null || !context.mounted) return null;

  try {
    switch (action) {
      case 'edit':
        final saved = await Navigator.of(context).push<bool>(zRoute<bool>(ComposePostScreen(editing: post)));
        if (saved != true) return null;
        return PostChange.updated(await repo.communityPost(post.id));
      case 'comments':
        await repo.setPostComments(post.id, !post.commentsEnabled);
        if (context.mounted) {
          showZayaSnack(context, post.commentsEnabled ? 'Commentaires désactivés.' : 'Commentaires activés.');
        }
        return PostChange.updated(post.copyWith(commentsEnabled: !post.commentsEnabled));
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Supprimer la publication ?'),
            content: const Text('Elle disparaîtra pour tous les membres, avec ses commentaires.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Annuler')),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: ZColors.danger),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Supprimer'),
              ),
            ],
          ),
        );
        if (ok != true) return null;
        await repo.deletePost(post.id);
        if (context.mounted) showZayaSnack(context, 'Publication supprimée.');
        return PostChange.removed();
      case 'hide':
        await repo.hidePost(post.id);
        if (context.mounted) showZayaSnack(context, 'Publication masquée.');
        return PostChange.removed();
      case 'report':
        final sent = await showContentReportSheet(
          context,
          title: 'Signaler cette publication',
          subtitle: 'Votre signalement est confidentiel. La publication disparaît aussitôt de votre fil.',
          submit: (reason, details) => repo.reportPost(post.id, reason: reason, details: details),
        );
        return sent ? PostChange.removed() : null;
      case 'block':
        final blocked = await confirmBlock(context, userId: post.authorId, name: post.authorName);
        return blocked ? PostChange.authorBlocked(post.authorId) : null;
    }
  } catch (e) {
    if (context.mounted) showZayaSnack(context, friendlyError(e), error: true);
  }
  return null;
}

/// Squelette d'une carte de publication pendant le chargement.
class PostSkeleton extends StatelessWidget {
  const PostSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ZColors.line),
        ),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Skeleton(width: 40, height: 40, radius: 20),
            SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Skeleton(width: 120, height: 13, radius: 6),
                SizedBox(height: 6),
                Skeleton(width: 180, height: 11, radius: 6),
              ]),
            ),
          ]),
          SizedBox(height: 14),
          Skeleton(height: 12, radius: 6),
          SizedBox(height: 8),
          Skeleton(height: 12, radius: 6),
          SizedBox(height: 8),
          Skeleton(width: 200, height: 12, radius: 6),
        ]),
      );
}
