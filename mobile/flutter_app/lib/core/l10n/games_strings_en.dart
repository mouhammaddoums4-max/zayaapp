import 'games_strings.dart';

/// English texts of the Games space. Shown only once the whole interface is translated (`englishInterfaceComplete`).
class ZGameStringsEn extends ZGameStrings {
  const ZGameStringsEn();

  // ── Games space
  @override
  String get gamesTitle => 'Games';
  @override
  String get gamesEntrySubtitle => 'Relax, and play together with your matches';
  @override
  String get gamesIntro => 'Short games to unwind, and others to share with your matches to get the conversation '
      'going.';
  @override
  String get gamesSoloSection => 'Play on your own';
  @override
  String get gamesDuoSection => 'Play together';
  @override
  String get gamesDuoExplain => 'In a conversation, tap + and choose a game. Your match receives an invitation and '
      'decides whether to accept.';
  @override
  String get gamesLocalNote => 'Your solo games stay on your phone.';
  @override
  String gameName(String gameId) => switch (gameId) {
        'path_puzzle' => 'Mystery link',
        'memory' => 'Memory',
        'would_you_rather' => 'Would you rather?',
        'word_scramble' => 'Word scramble',
        _ => 'Game',
      };
  @override
  String gameTagline(String gameId) => switch (gameId) {
        'path_puzzle' => 'Link the numbers in order while filling the whole grid.',
        'memory' => 'Turn the cards over two at a time to find the pairs.',
        'would_you_rather' => 'Two options, one choice: find out what suits you.',
        'word_scramble' => 'Put the letters back in order to find the word.',
        _ => '',
      };
  @override
  String get gameDuoBadge => 'For two';
  @override
  String difficulty(String level) => switch (level) {
        'easy' => 'Easy',
        'medium' => 'Medium',
        'hard' => 'Hard',
        _ => level,
      };

  // ── Common
  @override
  String get play => 'Play';
  @override
  String get playAgain => 'Play again';
  @override
  String get next => 'Next';
  @override
  String get nextLevel => 'Next level';
  @override
  String get allLevels => 'All levels';
  @override
  String get backToGames => 'Back to games';
  @override
  String get undo => 'Undo';
  @override
  String get restart => 'Restart';
  @override
  String get hint => 'Hint';
  @override
  String get skip => 'Skip';
  @override
  String get clear => 'Clear';
  @override
  String get stop => 'Stop';
  @override
  String get wellDone => 'Well done!';
  @override
  String get timerOn => 'Show the timer';
  @override
  String get timerOff => 'Hide the timer';
  @override
  String hintsUsed(int count) => switch (count) {
        0 => 'No hints',
        1 => '1 hint',
        _ => '$count hints',
      };
  @override
  String get saveError => 'Progress not saved on this phone.';

  // ── Mystery link
  @override
  String get pathRules => 'Start from 1 and go through every number in order by sliding your finger. '
      'The path must fill every cell.';
  @override
  String pathLevel(int number) => 'Level $number';
  @override
  String pathFilled(int filled, int total) => '$filled / $total cells';
  @override
  String pathLevelsDone(int done, int total) => '$done / $total solved';
  @override
  String pathSolvedBody(String time) => 'Grid completed in $time.';
  @override
  String get pathFillEverything => 'Fill every cell before reaching the last number.';
  @override
  String pathGoThrough(int number) => 'Go through number $number first.';
  @override
  String get pathLocked => 'Solve the previous level to unlock this one.';
  @override
  String get pathAllDone => 'You have solved every level of this difficulty.';
  @override
  String pathBoardLabel(int size, int filled, int total) =>
      'Grid of $size by $size cells. $filled of $total cells linked.';
  @override
  String pathLevelLabel(int number, {required bool done, required bool locked}) =>
      'Level $number${done ? ', solved' : ''}${locked ? ', locked' : ''}';

  // ── Memory
  @override
  String memoryPairs(int count) => '$count pairs';
  @override
  String memoryMoves(int count) => count > 1 ? '$count moves' : '$count move';
  @override
  String memoryFound(int found, int total) => '$found / $total pairs';
  @override
  String memorySolvedBody(int moves) => 'All pairs found in $moves moves.';
  @override
  String memoryBest(int moves) => 'Best score: $moves moves';
  @override
  String get memoryNewBest => 'New record!';
  @override
  String get memoryHiddenCard => 'Hidden card';
  @override
  String memorySymbol(String id) => switch (id) {
        'heart' => 'Heart',
        'ring' => 'Ring',
        'home' => 'Home',
        'travel' => 'Travel',
        'coffee' => 'Coffee',
        'book' => 'Book',
        'moon' => 'Moon',
        'sun' => 'Sun',
        'flower' => 'Flower',
        'music' => 'Music',
        'meal' => 'Meal',
        'nature' => 'Nature',
        'beach' => 'Beach',
        'star' => 'Star',
        'gift' => 'Gift',
        'family' => 'Family',
        _ => id,
      };

  // ── Would you rather?
  @override
  String questionOf(int index, int total) => 'Question $index of $total';
  @override
  String get wyrOr => 'or';
  @override
  String get wyrSummaryTitle => 'Your choices';
  @override
  String get wyrSummaryBody => 'These are your preferences of the moment: there is no right or wrong answer.';
  @override
  String wyrTheme(String theme) => switch (theme) {
        'travel' => 'Travel',
        'family' => 'Family',
        'daily' => 'Everyday life',
        'projects' => 'Projects',
        'values' => 'Values',
        'leisure' => 'Leisure',
        _ => theme,
      };
  @override
  List<WyrText> get wyrQuestions => const [
        WyrText('t01', 'travel', 'A long trip together', 'A quiet evening at home'),
        WyrText('t02', 'travel', 'Exploring a big city', 'Resting by the sea'),
        WyrText('t03', 'travel', 'The road, with stops along the way', 'The plane, to get there fast'),
        WyrText('t04', 'travel', 'Visiting family in the village', 'Discovering an unknown country'),
        WyrText('t05', 'travel', 'A trip planned well in advance', 'A getaway decided the day before'),
        WyrText('t06', 'travel', 'Mountains and quiet', 'The beach and its buzz'),
        WyrText('f01', 'family', 'A big family gathered on Sundays', 'A small circle of loved ones'),
        WyrText('f02', 'family', 'Living near your parents', 'Living in another town'),
        WyrText('f03', 'family', 'Celebrating big occasions with family', 'Celebrating them as a couple'),
        WyrText('f04', 'family', 'Cooking together', 'Each taking turns in the kitchen'),
        WyrText('f05', 'family', 'Asking the elders for advice', 'Deciding as a couple first'),
        WyrText('f06', 'family', 'Having guests over often', 'Keeping the house quiet'),
        WyrText('d01', 'daily', 'Getting up early', 'Enjoying the evening'),
        WyrText('d02', 'daily', 'A message in the morning', 'A call in the evening'),
        WyrText('d03', 'daily', 'Going to the market together', 'Each doing the shopping alone'),
        WyrText('d04', 'daily', 'An always tidy home', 'A warm and lively home'),
        WyrText('d05', 'daily', 'Telling each other about your day', 'Sharing a quiet moment'),
        WyrText('d06', 'daily', 'Tea', 'Coffee'),
        WyrText('p01', 'projects', 'Buying a house', 'Building your own'),
        WyrText('p02', 'projects', 'Starting your own business', 'Growing in a large company'),
        WyrText('p03', 'projects', 'Saving for a big project', 'Enjoying a little more today'),
        WyrText('p04', 'projects', 'Living in the city', 'Living somewhere quiet, away from the noise'),
        WyrText('p05', 'projects', 'Learning a new language', 'Learning a new trade'),
        WyrText('p06', 'projects', 'Planning the next five years', 'Moving forward step by step'),
        WyrText('v01', 'values', 'Telling the truth straight away', 'Choosing the right moment to tell it'),
        WyrText('v02', 'values', 'Forgiving quickly', 'Taking time to talk it through'),
        WyrText('v03', 'values', 'A thoughtful gesture', 'A tender word'),
        WyrText('v04', 'values', 'Settling a disagreement right away', 'Letting the tension ease first'),
        WyrText('v05', 'values', 'Helping loved ones discreetly', 'Bringing everyone together around a project'),
        WyrText('v06', 'values', 'Patience', 'Determination'),
        WyrText('l01', 'leisure', 'A good film', 'A good book'),
        WyrText('l02', 'leisure', 'Watching a football match', 'Taking a long walk'),
        WyrText('l03', 'leisure', 'Cooking a dish from home', 'Discovering a foreign cuisine'),
        WyrText('l04', 'leisure', 'A big lively party', 'A dinner with close friends'),
        WyrText('l05', 'leisure', 'Dancing at a wedding', 'Watching the dancers'),
        WyrText('l06', 'leisure', 'Exercise in the morning', 'A nap in the afternoon'),
      ];

  // ── Word scramble
  @override
  String wordOf(int index, int total) => 'Word $index of $total';
  @override
  String wordTheme(String theme) => 'Theme: ${switch (theme) {
        'values' => 'values',
        'family' => 'family',
        'travel' => 'travel',
        'projects' => 'projects',
        'relations' => 'relationships',
        _ => theme,
      }}';
  @override
  String get wordWrong => 'Not the right word yet. Try again!';
  @override
  String get wordFound => 'Found it!';
  @override
  String wordSolvedBody(int found, int total) => 'You found $found word${found > 1 ? 's' : ''} out of $total.';
  @override
  String wordAnswerWas(String word) => 'The answer was: $word';
  @override
  String get wordTapLetters => 'Tap the letters in order. Tap a filled box to empty it.';
  @override
  List<WordText> get words => const [
        WordText('respect', 'values', 'RESPECT'),
        WordText('trust', 'values', 'TRUST'),
        WordText('patience', 'values', 'PATIENCE'),
        WordText('wisdom', 'values', 'WISDOM'),
        WordText('courage', 'values', 'COURAGE'),
        WordText('forgive', 'values', 'FORGIVE'),
        WordText('support', 'values', 'SUPPORT'),
        WordText('promise', 'values', 'PROMISE'),
        WordText('family', 'family', 'FAMILY'),
        WordText('wedding', 'family', 'WEDDING'),
        WordText('children', 'family', 'CHILDREN'),
        WordText('home', 'family', 'HOME'),
        WordText('household', 'family', 'HOUSEHOLD'),
        WordText('parents', 'family', 'PARENTS'),
        WordText('travel', 'travel', 'TRAVEL'),
        WordText('plane', 'travel', 'PLANE'),
        WordText('beach', 'travel', 'BEACH'),
        WordText('mountain', 'travel', 'MOUNTAIN'),
        WordText('suitcase', 'travel', 'SUITCASE'),
        WordText('village', 'travel', 'VILLAGE'),
        WordText('project', 'projects', 'PROJECT'),
        WordText('future', 'projects', 'FUTURE'),
        WordText('work', 'projects', 'WORK'),
        WordText('goal', 'projects', 'GOAL'),
        WordText('budget', 'projects', 'BUDGET'),
        WordText('smile', 'relations', 'SMILE'),
        WordText('happiness', 'relations', 'HAPPINESS'),
        WordText('kindness', 'relations', 'KINDNESS'),
        WordText('tenderness', 'relations', 'TENDERNESS'),
        WordText('sharing', 'relations', 'SHARING'),
        WordText('dialogue', 'relations', 'DIALOGUE'),
        WordText('gift', 'relations', 'GIFT'),
      ];

  // ── Play together
  @override
  String get duoPlusTooltip => 'Play together';
  @override
  String duoPickerTitle(String name) => 'Play with $name';
  @override
  String duoPickerSubtitle(String name) => '$name will receive an invitation and choose whether to accept.';
  @override
  String get duoInvite => 'Invite';
  @override
  String duoInviteSent(String name) => 'Invitation sent to $name.';
  @override
  String duoInvitedYou(String name, String game) => '$name invites you to play “$game”.';
  @override
  String duoWaitingAccept(String name) => 'Invitation sent. Waiting for $name to answer…';
  @override
  String get duoAccept => 'Accept';
  @override
  String get duoDecline => 'Decline';
  @override
  String get duoCancelInvite => 'Cancel the invitation';
  @override
  String duoDeclined(String name) => '$name would rather not play this time.';
  @override
  String get duoExpired => 'The invitation has expired.';
  @override
  String duoInProgress(String game) => 'Game in progress: $game';
  @override
  String get duoResume => 'Resume';
  @override
  String duoFinished(String game) => 'Game over: $game';
  @override
  String get duoSeeResult => 'See the result';
  @override
  String get duoStopped => 'The game was stopped.';
  @override
  String duoWaitingAnswer(String name) => 'Waiting for $name’s answer…';
  @override
  String duoPartnerChoice(String name) => '$name’s choice';
  @override
  String get duoYourChoice => 'Your choice';
  @override
  String get duoSame => 'Same choice!';
  @override
  String get duoDifferent => 'Different choices: something to talk about!';
  @override
  String duoCommon(int common, int total) => '$common choices in common out of $total';
  @override
  String get duoDisclaimer => 'It is a game: it does not measure your compatibility and guarantees nothing.';
  @override
  String get duoBackToChat => 'Back to the conversation';
  @override
  String get duoStopTitle => 'Stop the game?';
  @override
  String get duoStopBody => 'The game will end for both of you. You can start another one later.';
  @override
  String duoPartnerProgress(String name, int done, int total) => '$name: $done / $total';
  @override
  String duoPartnerNotDone(String name) => '$name has not finished yet. The result will complete itself.';
  @override
  String duoWordsScore(String name, int mine, int theirs, int total) =>
      'You: $mine / $total · $name: $theirs / $total';
  @override
  String get duoErrLimit => 'You have sent many invitations today. Try again tomorrow.';
  @override
  String get duoErrOpen => 'A game is already in progress in this conversation.';
  @override
  String get duoErrUnavailable => 'Games are not available in this conversation.';
  @override
  String get duoErrNetwork => 'Unable to connect. Check your network and try again.';
  @override
  String get duoNotFound => 'This game is no longer available.';
}
