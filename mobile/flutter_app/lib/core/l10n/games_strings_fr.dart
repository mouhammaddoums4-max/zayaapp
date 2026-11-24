import 'games_strings.dart';

/// Textes français de l'espace Jeux (langue de référence).
class ZGameStringsFr extends ZGameStrings {
  const ZGameStringsFr();

  // ── Espace Jeux
  @override
  String get gamesTitle => 'Jeux';
  @override
  String get gamesEntrySubtitle => 'Détendez-vous, jouez à deux avec vos matchs';
  @override
  String get gamesIntro => 'Des jeux courts pour se détendre, et d’autres à partager avec vos matchs pour lancer '
      'la conversation.';
  @override
  String get gamesSoloSection => 'Jouer seul';
  @override
  String get gamesDuoSection => 'Jouer à deux';
  @override
  String get gamesDuoExplain => 'Dans une conversation, touchez + puis choisissez un jeu. Votre match reçoit une '
      'invitation et décide d’accepter ou non.';
  @override
  String get gamesLocalNote => 'Vos parties en solo restent sur votre téléphone.';
  @override
  String gameName(String gameId) => switch (gameId) {
        'path_puzzle' => 'Connexion mystère',
        'memory' => 'Mémoire',
        'would_you_rather' => 'Tu préfères ?',
        'word_scramble' => 'Mots mélangés',
        _ => 'Jeu',
      };
  @override
  String gameTagline(String gameId) => switch (gameId) {
        'path_puzzle' => 'Reliez les numéros dans l’ordre en remplissant toute la grille.',
        'memory' => 'Retournez les cartes deux par deux pour retrouver les paires.',
        'would_you_rather' => 'Deux propositions, un choix : découvrez ce qui vous ressemble.',
        'word_scramble' => 'Remettez les lettres dans l’ordre pour retrouver le mot.',
        _ => '',
      };
  @override
  String get gameDuoBadge => 'À deux';
  @override
  String difficulty(String level) => switch (level) {
        'easy' => 'Facile',
        'medium' => 'Moyen',
        'hard' => 'Difficile',
        _ => level,
      };

  // ── Commun
  @override
  String get play => 'Jouer';
  @override
  String get playAgain => 'Rejouer';
  @override
  String get next => 'Suivant';
  @override
  String get nextLevel => 'Niveau suivant';
  @override
  String get allLevels => 'Tous les niveaux';
  @override
  String get backToGames => 'Retour aux jeux';
  @override
  String get undo => 'Annuler';
  @override
  String get restart => 'Recommencer';
  @override
  String get hint => 'Indice';
  @override
  String get skip => 'Passer';
  @override
  String get clear => 'Effacer';
  @override
  String get stop => 'Arrêter';
  @override
  String get wellDone => 'Bravo !';
  @override
  String get timerOn => 'Afficher le chrono';
  @override
  String get timerOff => 'Masquer le chrono';
  @override
  String hintsUsed(int count) => switch (count) {
        0 => 'Sans indice',
        1 => '1 indice',
        _ => '$count indices',
      };
  @override
  String get saveError => 'Progression non enregistrée sur ce téléphone.';

  // ── Connexion mystère
  @override
  String get pathRules => 'Partez du 1 et passez par chaque numéro dans l’ordre, en glissant le doigt. '
      'Le chemin doit remplir toutes les cases.';
  @override
  String pathLevel(int number) => 'Niveau $number';
  @override
  String pathFilled(int filled, int total) => '$filled / $total cases';
  @override
  String pathLevelsDone(int done, int total) => '$done / $total réussis';
  @override
  String pathSolvedBody(String time) => 'Grille complétée en $time.';
  @override
  String get pathFillEverything => 'Remplissez toutes les cases avant d’arriver au dernier numéro.';
  @override
  String pathGoThrough(int number) => 'Passez d’abord par le $number.';
  @override
  String get pathLocked => 'Réussissez le niveau précédent pour débloquer celui-ci.';
  @override
  String get pathAllDone => 'Vous avez réussi tous les niveaux de cette difficulté.';
  @override
  String pathBoardLabel(int size, int filled, int total) =>
      'Grille de $size cases sur $size. $filled cases sur $total reliées.';
  @override
  String pathLevelLabel(int number, {required bool done, required bool locked}) =>
      'Niveau $number${done ? ', réussi' : ''}${locked ? ', verrouillé' : ''}';

  // ── Mémoire
  @override
  String memoryPairs(int count) => '$count paires';
  @override
  String memoryMoves(int count) => count > 1 ? '$count coups' : '$count coup';
  @override
  String memoryFound(int found, int total) => '$found / $total paires';
  @override
  String memorySolvedBody(int moves) => 'Toutes les paires trouvées en $moves coups.';
  @override
  String memoryBest(int moves) => 'Meilleur score : $moves coups';
  @override
  String get memoryNewBest => 'Nouveau record !';
  @override
  String get memoryHiddenCard => 'Carte cachée';
  @override
  String memorySymbol(String id) => switch (id) {
        'heart' => 'Cœur',
        'ring' => 'Bague',
        'home' => 'Maison',
        'travel' => 'Voyage',
        'coffee' => 'Café',
        'book' => 'Livre',
        'moon' => 'Lune',
        'sun' => 'Soleil',
        'flower' => 'Fleur',
        'music' => 'Musique',
        'meal' => 'Repas',
        'nature' => 'Nature',
        'beach' => 'Plage',
        'star' => 'Étoile',
        'gift' => 'Cadeau',
        'family' => 'Famille',
        _ => id,
      };

  // ── Tu préfères ?
  @override
  String questionOf(int index, int total) => 'Question $index sur $total';
  @override
  String get wyrOr => 'ou';
  @override
  String get wyrSummaryTitle => 'Vos choix';
  @override
  String get wyrSummaryBody => 'Ce sont vos préférences du moment : il n’y a pas de bonne ou de mauvaise réponse.';
  @override
  String wyrTheme(String theme) => switch (theme) {
        'travel' => 'Voyages',
        'family' => 'Famille',
        'daily' => 'Quotidien',
        'projects' => 'Projets',
        'values' => 'Valeurs',
        'leisure' => 'Loisirs',
        _ => theme,
      };
  @override
  List<WyrText> get wyrQuestions => const [
        WyrText('t01', 'travel', 'Un long voyage à deux', 'Une soirée tranquille à la maison'),
        WyrText('t02', 'travel', 'Découvrir une grande ville', 'Se reposer au bord de la mer'),
        WyrText('t03', 'travel', 'La route, avec des pauses en chemin', 'L’avion, pour arriver vite'),
        WyrText('t04', 'travel', 'Rendre visite à la famille au village', 'Découvrir un pays inconnu'),
        WyrText('t05', 'travel', 'Un voyage préparé longtemps à l’avance', 'Une escapade décidée la veille'),
        WyrText('t06', 'travel', 'La montagne et le calme', 'La plage et l’animation'),
        WyrText('f01', 'family', 'Une grande famille réunie le dimanche', 'Un petit cercle de proches'),
        WyrText('f02', 'family', 'Habiter près de ses parents', 'Habiter dans une autre ville'),
        WyrText('f03', 'family', 'Fêter les grandes occasions en famille', 'Les fêter à deux'),
        WyrText('f04', 'family', 'Préparer le repas ensemble', 'Chacun son jour en cuisine'),
        WyrText('f05', 'family', 'Demander conseil aux aînés', 'Décider d’abord à deux'),
        WyrText('f06', 'family', 'Recevoir souvent des invités', 'Garder la maison calme'),
        WyrText('d01', 'daily', 'Se lever tôt', 'Profiter de la soirée'),
        WyrText('d02', 'daily', 'Un message le matin', 'Un appel le soir'),
        WyrText('d03', 'daily', 'Faire le marché ensemble', 'Faire les courses chacun de son côté'),
        WyrText('d04', 'daily', 'Une maison toujours bien rangée', 'Une maison chaleureuse et vivante'),
        WyrText('d05', 'daily', 'Raconter sa journée en détail', 'Partager un moment de calme'),
        WyrText('d06', 'daily', 'Le thé', 'Le café'),
        WyrText('p01', 'projects', 'Acheter une maison', 'Construire la sienne'),
        WyrText('p02', 'projects', 'Créer son entreprise', 'Évoluer dans une grande entreprise'),
        WyrText('p03', 'projects', 'Économiser pour un grand projet', 'Profiter un peu plus aujourd’hui'),
        WyrText('p04', 'projects', 'Vivre en ville', 'Vivre au calme, loin du bruit'),
        WyrText('p05', 'projects', 'Apprendre une nouvelle langue', 'Apprendre un nouveau métier'),
        WyrText('p06', 'projects', 'Planifier les cinq prochaines années', 'Avancer étape par étape'),
        WyrText('v01', 'values', 'Dire la vérité tout de suite', 'Choisir le bon moment pour la dire'),
        WyrText('v02', 'values', 'Pardonner vite', 'Prendre le temps d’en parler'),
        WyrText('v03', 'values', 'Un geste attentionné', 'Un mot tendre'),
        WyrText('v04', 'values', 'Régler un désaccord tout de suite', 'Laisser retomber la tension d’abord'),
        WyrText('v05', 'values', 'Aider ses proches en toute discrétion', 'Rassembler tout le monde autour d’un projet'),
        WyrText('v06', 'values', 'La patience', 'La détermination'),
        WyrText('l01', 'leisure', 'Un bon film', 'Un bon livre'),
        WyrText('l02', 'leisure', 'Regarder un match de football', 'Faire une longue promenade'),
        WyrText('l03', 'leisure', 'Cuisiner un plat de chez nous', 'Découvrir une cuisine étrangère'),
        WyrText('l04', 'leisure', 'Une grande fête animée', 'Un dîner entre proches'),
        WyrText('l05', 'leisure', 'Danser à un mariage', 'Regarder les danseurs'),
        WyrText('l06', 'leisure', 'Du sport le matin', 'Une sieste l’après-midi'),
      ];

  // ── Mots mélangés
  @override
  String wordOf(int index, int total) => 'Mot $index sur $total';
  @override
  String wordTheme(String theme) => 'Thème : ${switch (theme) {
        'values' => 'les valeurs',
        'family' => 'la famille',
        'travel' => 'les voyages',
        'projects' => 'les projets',
        'relations' => 'la relation',
        _ => theme,
      }}';
  @override
  String get wordWrong => 'Ce n’est pas encore le bon mot. Réessayez !';
  @override
  String get wordFound => 'Trouvé !';
  @override
  String wordSolvedBody(int found, int total) => 'Vous avez trouvé $found mot${found > 1 ? 's' : ''} sur $total.';
  @override
  String wordAnswerWas(String word) => 'La réponse était : $word';
  @override
  String get wordTapLetters => 'Touchez les lettres dans l’ordre. Touchez une case remplie pour la vider.';
  @override
  List<WordText> get words => const [
        WordText('respect', 'values', 'RESPECT'),
        WordText('trust', 'values', 'CONFIANCE'),
        WordText('patience', 'values', 'PATIENCE'),
        WordText('wisdom', 'values', 'SAGESSE'),
        WordText('courage', 'values', 'COURAGE'),
        WordText('forgive', 'values', 'PARDON'),
        WordText('support', 'values', 'SOUTIEN'),
        WordText('promise', 'values', 'PROMESSE'),
        WordText('family', 'family', 'FAMILLE'),
        WordText('wedding', 'family', 'MARIAGE'),
        WordText('children', 'family', 'ENFANTS'),
        WordText('home', 'family', 'MAISON'),
        WordText('household', 'family', 'FOYER'),
        WordText('parents', 'family', 'PARENTS'),
        WordText('travel', 'travel', 'VOYAGE'),
        WordText('plane', 'travel', 'AVION'),
        WordText('beach', 'travel', 'PLAGE'),
        WordText('mountain', 'travel', 'MONTAGNE'),
        WordText('suitcase', 'travel', 'VALISE'),
        WordText('village', 'travel', 'VILLAGE'),
        WordText('project', 'projects', 'PROJET'),
        WordText('future', 'projects', 'AVENIR'),
        WordText('work', 'projects', 'TRAVAIL'),
        WordText('goal', 'projects', 'OBJECTIF'),
        WordText('budget', 'projects', 'BUDGET'),
        WordText('smile', 'relations', 'SOURIRE'),
        WordText('happiness', 'relations', 'BONHEUR'),
        WordText('kindness', 'relations', 'DOUCEUR'),
        WordText('tenderness', 'relations', 'TENDRESSE'),
        WordText('sharing', 'relations', 'PARTAGE'),
        WordText('dialogue', 'relations', 'DIALOGUE'),
        WordText('gift', 'relations', 'CADEAU'),
      ];

  // ── Jouer à deux
  @override
  String get duoPlusTooltip => 'Jouer ensemble';
  @override
  String duoPickerTitle(String name) => 'Jouer avec $name';
  @override
  String duoPickerSubtitle(String name) => '$name recevra une invitation et choisira d’accepter ou non.';
  @override
  String get duoInvite => 'Inviter';
  @override
  String duoInviteSent(String name) => 'Invitation envoyée à $name.';
  @override
  String duoInvitedYou(String name, String game) => '$name vous propose de jouer à « $game ».';
  @override
  String duoWaitingAccept(String name) => 'Invitation envoyée. En attente de la réponse de $name…';
  @override
  String get duoAccept => 'Accepter';
  @override
  String get duoDecline => 'Refuser';
  @override
  String get duoCancelInvite => 'Annuler l’invitation';
  @override
  String duoDeclined(String name) => '$name n’a pas souhaité jouer cette fois-ci.';
  @override
  String get duoExpired => 'L’invitation a expiré.';
  @override
  String duoInProgress(String game) => 'Partie en cours : $game';
  @override
  String get duoResume => 'Reprendre';
  @override
  String duoFinished(String game) => 'Partie terminée : $game';
  @override
  String get duoSeeResult => 'Voir le résultat';
  @override
  String get duoStopped => 'La partie a été arrêtée.';
  @override
  String duoWaitingAnswer(String name) => 'En attente de la réponse de $name…';
  @override
  String duoPartnerChoice(String name) => 'Choix de $name';
  @override
  String get duoYourChoice => 'Votre choix';
  @override
  String get duoSame => 'Même choix !';
  @override
  String get duoDifferent => 'Choix différents : de quoi en parler !';
  @override
  String duoCommon(int common, int total) => '$common choix en commun sur $total';
  @override
  String get duoDisclaimer => 'C’est un jeu : il ne mesure pas votre compatibilité et ne garantit rien.';
  @override
  String get duoBackToChat => 'Retour à la conversation';
  @override
  String get duoStopTitle => 'Arrêter la partie ?';
  @override
  String get duoStopBody => 'La partie sera terminée pour vous deux. Vous pourrez en commencer une autre plus tard.';
  @override
  String duoPartnerProgress(String name, int done, int total) => '$name : $done / $total';
  @override
  String duoPartnerNotDone(String name) => '$name n’a pas encore terminé. Le résultat se complétera tout seul.';
  @override
  String duoWordsScore(String name, int mine, int theirs, int total) =>
      'Vous : $mine / $total · $name : $theirs / $total';
  @override
  String get duoErrLimit => 'Vous avez envoyé beaucoup d’invitations aujourd’hui. Réessayez demain.';
  @override
  String get duoErrOpen => 'Une partie est déjà en cours dans cette conversation.';
  @override
  String get duoErrUnavailable => 'Les jeux ne sont pas disponibles dans cette conversation.';
  @override
  String get duoErrNetwork => 'Connexion impossible. Vérifiez votre réseau et réessayez.';
  @override
  String get duoNotFound => 'Cette partie n’est plus disponible.';
}
