import 'models.dart';

class _Post {
  _Post({
    required this.id,
    required this.communityId,
    required this.authorId,
    required this.kind,
    required this.body,
    required this.createdAt,
    Set<String>? reactions,
  }) : reactions = reactions ?? <String>{};

  final String id;
  final String communityId;
  final String authorId;
  final String kind;
  String body;
  final DateTime createdAt;
  bool edited = false;
  bool commentsEnabled = true;
  String status = 'published';
  final Set<String> reactions;
}

class _Comment {
  _Comment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String postId;
  final String authorId;
  String body;
  final DateTime createdAt;
  bool edited = false;
  String status = 'published';
}

/// Communauté du mode démo : publications fictives et mêmes règles que le serveur
/// (profil vérifié pour écrire, limites de fréquence, filtre avant publication, blocages, masquage).
class DemoCommunityStore {
  DemoCommunityStore({
    required this.meId,
    required this.myName,
    required this.isVerified,
    required this.isBlocked,
    required this.violation,
  }) {
    reset();
  }

  final String meId;
  final String Function() myName;
  final bool Function() isVerified;
  final bool Function(String userId) isBlocked;

  /// Catégorie de contenu interdit, ou null si le texte est accepté.
  final String? Function(String text) violation;

  static const postsPerDay = 5;
  static const commentsPerHour = 20;

  /// Auteurs fictifs (prénoms inventés) ; aucune photo n'est affichée dans la Communauté.
  static const _authors = <String, String>{
    'ca-1': 'Fanta',
    'ca-2': 'Lansana',
    'ca-3': 'Néné',
    'ca-4': 'Abdoulaye',
    'ca-5': 'Kadi',
  };

  static const _catalog = <Community>[
    Community(
        id: 'com-1',
        slug: 'preparation-mariage',
        name: 'Préparation au mariage',
        description: 'Les questions à se poser, les étapes, les sujets à aborder avant de s’engager.',
        icon: 'favorite'),
    Community(
        id: 'com-2',
        slug: 'vie-de-couple',
        name: 'Communication et vie de couple',
        description: 'Écoute, désaccords, respect : partager ce qui aide à construire une relation solide.',
        icon: 'forum'),
    Community(
        id: 'com-3',
        slug: 'conseils-experiences',
        name: 'Conseils et expériences',
        description: 'Rencontres, premiers rendez-vous, précautions : apprendre de l’expérience des autres.',
        icon: 'lightbulb'),
    Community(
        id: 'com-4',
        slug: 'famille-parentalite',
        name: 'Famille et parentalité',
        description: 'Présenter son projet à sa famille, fonder un foyer, accueillir des enfants.',
        icon: 'family'),
    Community(
        id: 'com-5',
        slug: 'developpement-personnel',
        name: 'Éducation et développement personnel',
        description: 'Études, travail, projets : grandir pour soi et pour le couple.',
        icon: 'school'),
    Community(
        id: 'com-6',
        slug: 'evenements-locaux',
        name: 'Événements et activités locales',
        description: 'Ateliers, conférences et rencontres encadrées près de chez vous.',
        icon: 'event'),
    Community(
        id: 'com-7',
        slug: 'questions-reponses',
        name: 'Questions et réponses',
        description: 'Une question sur ZAYA, la sécurité ou la vie à deux ? Posez-la ici.',
        icon: 'help'),
    Community(
        id: 'com-8',
        slug: 'langues-regions',
        name: 'Communautés linguistiques et régionales',
        description: 'Échanger dans sa langue et autour de sa région.',
        icon: 'translate'),
  ];

  int _seq = 0;
  final Map<String, Set<String>> _members = <String, Set<String>>{};
  final Map<String, String> _notif = <String, String>{};
  final List<_Post> _posts = <_Post>[];
  final List<_Comment> _comments = <_Comment>[];
  final Set<String> _saved = <String>{};
  final Set<String> _hiddenPosts = <String>{};
  final Set<String> _hiddenComments = <String>{};

  /// Remet la communauté dans son état initial (nouvelle session de démonstration).
  void reset() {
    final now = DateTime.now();
    _members
      ..clear()
      ..addAll(<String, Set<String>>{
        'com-1': {'ca-1', 'ca-3', 'ca-4'},
        'com-2': {'ca-2', 'ca-3'},
        'com-3': {'ca-1', 'ca-3', 'ca-4'},
        'com-4': {'ca-4'},
        'com-7': {'ca-2', 'ca-5'},
      });
    _notif.clear();
    _saved.clear();
    _hiddenPosts.clear();
    _hiddenComments.clear();
    _posts
      ..clear()
      ..addAll([
        _Post(
          id: 'post-1',
          communityId: 'com-1',
          authorId: 'ca-1',
          kind: 'question',
          createdAt: now.subtract(const Duration(minutes: 40)),
          body: 'Quels sujets avez-vous abordés avant de vous engager ? Je pense aux finances, au lieu de vie et '
              'aux enfants. Qu’est-ce qui vous a le plus aidés ?',
          reactions: {'ca-2', 'ca-3'},
        ),
        _Post(
          id: 'post-2',
          communityId: 'com-2',
          authorId: 'ca-2',
          kind: 'advice',
          createdAt: now.subtract(const Duration(hours: 3)),
          body: 'Un conseil qui m’a servi : parler des désaccords à tête reposée, jamais au milieu d’une dispute. '
              'On se fixe un moment calme et chacun parle sans être interrompu.',
          reactions: {'ca-1', 'ca-3', 'ca-5'},
        ),
        _Post(
          id: 'post-3',
          communityId: 'com-3',
          authorId: 'ca-3',
          kind: 'experience',
          createdAt: now.subtract(const Duration(days: 1, hours: 2)),
          body: 'Premier rendez-vous dans un café de Kaloum, en journée, avec ma sœur au courant de l’heure et du '
              'lieu. Je me suis sentie en confiance du début à la fin. Ces précautions ne gâchent rien !',
          reactions: {'ca-1'},
        ),
        _Post(
          id: 'post-4',
          communityId: 'com-4',
          authorId: 'ca-4',
          kind: 'question',
          createdAt: now.subtract(const Duration(days: 2, hours: 5)),
          body: 'Comment avez-vous présenté votre projet de mariage à vos parents ? Les miens souhaitent rencontrer '
              'la famille très vite et je voudrais d’abord mieux connaître la personne.',
        ),
        _Post(
          id: 'post-5',
          communityId: 'com-7',
          authorId: 'ca-5',
          kind: 'question',
          createdAt: now.subtract(const Duration(days: 4)),
          body: 'Est-ce que les autres membres voient mon numéro de téléphone ? Je préfère qu’il reste privé.',
          reactions: {'ca-2'},
        ),
      ]);
    _comments
      ..clear()
      ..addAll([
        _Comment(
          id: 'cm-1',
          postId: 'post-1',
          authorId: 'ca-2',
          createdAt: now.subtract(const Duration(minutes: 25)),
          body: 'Les finances, clairement : qui paie quoi, comment on épargne. En parler tôt évite beaucoup de '
              'malentendus.',
        ),
        _Comment(
          id: 'cm-2',
          postId: 'post-1',
          authorId: 'ca-3',
          createdAt: now.subtract(const Duration(minutes: 12)),
          body: 'Le lieu de vie aussi : chez les parents ou à part ? Chez nous, ça a été décisif.',
        ),
        _Comment(
          id: 'cm-3',
          postId: 'post-3',
          authorId: 'ca-4',
          createdAt: now.subtract(const Duration(hours: 20)),
          body: 'Très bon réflexe. Et chacun rentre par ses propres moyens.',
        ),
        _Comment(
          id: 'cm-4',
          postId: 'post-5',
          authorId: 'ca-2',
          createdAt: now.subtract(const Duration(days: 3)),
          body: 'Non, il n’apparaît jamais sur le profil. Et si quelqu’un l’écrit dans un message, il reste masqué '
              'jusqu’à ce que tu choisisses de l’afficher.',
        ),
      ]);
  }

  String? authorName(String userId) => _authors[userId];

  String _nameOf(String userId) => userId == meId ? myName() : (_authors[userId] ?? 'Membre');

  Never _fail(String code) => throw Exception(code);

  void _requireWriter() {
    if (!isVerified()) _fail('VERIFICATION_REQUIRED');
  }

  bool _visible(_Post p) =>
      p.status == 'published' && !_hiddenPosts.contains(p.id) && (p.authorId == meId || !isBlocked(p.authorId));

  bool _commentVisible(_Comment c) =>
      c.status == 'published' && !_hiddenComments.contains(c.id) && (c.authorId == meId || !isBlocked(c.authorId));

  _Post _visiblePost(String postId) {
    for (final p in _posts) {
      if (p.id == postId && _visible(p)) return p;
    }
    _fail('POST_NOT_FOUND');
  }

  CommunityPost _toPost(_Post p) {
    final community = _catalog.firstWhere((c) => c.id == p.communityId);
    return CommunityPost(
      id: p.id,
      communityId: p.communityId,
      communityName: community.name,
      authorId: p.authorId,
      authorName: _nameOf(p.authorId),
      authorVerified: true,
      kind: p.kind,
      body: p.body,
      commentsEnabled: p.commentsEnabled,
      createdAt: p.createdAt,
      edited: p.edited,
      reactionCount: p.reactions.length,
      commentCount: _comments.where((c) => c.postId == p.id && _commentVisible(c)).length,
      reacted: p.reactions.contains(meId),
      saved: _saved.contains(p.id),
      isMine: p.authorId == meId,
    );
  }

  // ── Communautés
  List<Community> communities() => [
        for (final c in _catalog)
          c.copyWith(
            memberCount: (_members[c.id] ?? const <String>{}).length,
            joined: _members[c.id]?.contains(meId) ?? false,
            notifLevel: _notif[c.id],
          ),
      ];

  void join(String communityId) {
    if (!_catalog.any((c) => c.id == communityId)) _fail('COMMUNITY_NOT_FOUND');
    _members.putIfAbsent(communityId, () => <String>{}).add(meId);
    _notif.putIfAbsent(communityId, () => 'important');
  }

  void leave(String communityId) {
    _members[communityId]?.remove(meId);
    _notif.remove(communityId);
  }

  void setNotifications(String communityId, String level) {
    if (!(_members[communityId]?.contains(meId) ?? false)) _fail('NOT_A_MEMBER');
    _notif[communityId] = level;
  }

  // ── Lecture
  List<CommunityPost> feed({String? communityId, DateTime? before}) {
    final joined = {
      for (final e in _members.entries)
        if (e.value.contains(meId)) e.key,
    };
    final posts = _posts.where((p) {
      if (!_visible(p)) return false;
      if (before != null && !p.createdAt.isBefore(before)) return false;
      if (communityId != null) return p.communityId == communityId;
      return joined.isEmpty || joined.contains(p.communityId);
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return posts.take(20).map(_toPost).toList();
  }

  CommunityPost post(String postId) => _toPost(_visiblePost(postId));

  List<CommunityPost> saved() => [
        for (final p in _posts.reversed)
          if (_saved.contains(p.id) && _visible(p)) _toPost(p),
      ];

  List<PostComment> comments(String postId) {
    _visiblePost(postId);
    return [
      for (final c in _comments)
        if (c.postId == postId && _commentVisible(c))
          PostComment(
            id: c.id,
            authorId: c.authorId,
            authorName: _nameOf(c.authorId),
            authorVerified: true,
            body: c.body,
            createdAt: c.createdAt,
            edited: c.edited,
            isMine: c.authorId == meId,
          ),
    ];
  }

  // ── Écriture
  PublishResult create({required String communityId, required String kind, required String body}) {
    _requireWriter();
    if (!_catalog.any((c) => c.id == communityId)) _fail('COMMUNITY_NOT_FOUND');
    final text = body.trim();
    if (text.isEmpty || text.length > 2000) _fail('INVALID_POST');
    final dayAgo = DateTime.now().subtract(const Duration(days: 1));
    if (_posts.where((p) => p.authorId == meId && p.createdAt.isAfter(dayAgo)).length >= postsPerDay) {
      _fail('RATE_LIMITED');
    }
    final category = violation(text);
    if (category != null) return PublishResult.blocked(category);
    join(communityId);
    final id = 'my-post-${_seq++}';
    _posts.add(
        _Post(id: id, communityId: communityId, authorId: meId, kind: kind, body: text, createdAt: DateTime.now()));
    return PublishResult.published(id);
  }

  PublishResult edit(String postId, String body) {
    _requireWriter();
    final post = _visiblePost(postId);
    if (post.authorId != meId) _fail('POST_NOT_FOUND');
    final text = body.trim();
    if (text.isEmpty || text.length > 2000) _fail('INVALID_POST');
    final category = violation(text);
    if (category != null) return PublishResult.blocked(category);
    if (text != post.body) {
      post
        ..body = text
        ..edited = true;
    }
    return PublishResult.published(postId);
  }

  void delete(String postId) {
    final post = _visiblePost(postId);
    if (post.authorId != meId) _fail('POST_NOT_FOUND');
    post.status = 'deleted';
    _saved.remove(postId);
  }

  void setComments(String postId, bool enabled) {
    final post = _visiblePost(postId);
    if (post.authorId != meId) _fail('POST_NOT_FOUND');
    post.commentsEnabled = enabled;
  }

  int react(String postId, bool on) {
    final post = _visiblePost(postId);
    if (on) {
      post.reactions.add(meId);
    } else {
      post.reactions.remove(meId);
    }
    return post.reactions.length;
  }

  void save(String postId, bool on) {
    if (!on) {
      _saved.remove(postId);
      return;
    }
    _visiblePost(postId);
    _saved.add(postId);
  }

  void hide(String postId) => _hiddenPosts.add(postId);

  PublishResult addComment(String postId, String body) {
    _requireWriter();
    final post = _visiblePost(postId);
    if (!post.commentsEnabled) _fail('COMMENTS_DISABLED');
    final text = body.trim();
    if (text.isEmpty || text.length > 1000) _fail('INVALID_COMMENT');
    final hourAgo = DateTime.now().subtract(const Duration(hours: 1));
    if (_comments.where((c) => c.authorId == meId && c.createdAt.isAfter(hourAgo)).length >= commentsPerHour) {
      _fail('RATE_LIMITED');
    }
    final category = violation(text);
    if (category != null) return PublishResult.blocked(category);
    final id = 'my-comment-${_seq++}';
    _comments.add(_Comment(id: id, postId: postId, authorId: meId, body: text, createdAt: DateTime.now()));
    return PublishResult.published(id);
  }

  _Comment _myComment(String commentId) {
    for (final c in _comments) {
      if (c.id == commentId && c.authorId == meId && c.status == 'published') return c;
    }
    _fail('COMMENT_NOT_FOUND');
  }

  PublishResult editComment(String commentId, String body) {
    _requireWriter();
    final comment = _myComment(commentId);
    final text = body.trim();
    if (text.isEmpty || text.length > 1000) _fail('INVALID_COMMENT');
    final category = violation(text);
    if (category != null) return PublishResult.blocked(category);
    comment
      ..body = text
      ..edited = true;
    return PublishResult.published(commentId);
  }

  void deleteComment(String commentId) => _myComment(commentId).status = 'deleted';

  void reportPost(String postId) {
    final post = _visiblePost(postId);
    if (post.authorId == meId) _fail('INVALID_TARGET');
    _hiddenPosts.add(postId);
  }

  void reportComment(String commentId) {
    final comment = _comments.where((c) => c.id == commentId).firstOrNull;
    if (comment == null || comment.authorId == meId) _fail('INVALID_TARGET');
    _hiddenComments.add(commentId);
  }
}
