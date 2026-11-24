import 'package:material_ui/material_ui.dart';

import 'games_strings_en.dart';
import 'games_strings_fr.dart';
import 'l10n.dart';

/// Une question de « Tu préfères ? ». [id] est stable d'une langue à l'autre : c'est lui qui est enregistré
/// (sur le téléphone en solo, sur le serveur en partie à deux), jamais le texte.
class WyrText {
  const WyrText(this.id, this.theme, this.a, this.b);
  final String id;

  /// `travel`, `family`, `daily`, `projects`, `values`, `leisure`.
  final String theme;
  final String a;
  final String b;
}

/// Un mot de « Mots mélangés » : lettres A–Z sans accent, pour des tuiles lisibles.
class WordText {
  const WordText(this.id, this.theme, this.word);
  final String id;
  final String theme;
  final String word;
}

/// Textes de l'espace Jeux (AGENTS.md : textes centralisés, français puis anglais). Fichiers séparés des autres
/// textes de l'application pour que plusieurs sessions puissent travailler en parallèle sans conflit.
abstract class ZGameStrings {
  const ZGameStrings();

  // ── Espace Jeux
  String get gamesTitle;
  String get gamesEntrySubtitle;
  String get gamesIntro;
  String get gamesSoloSection;
  String get gamesDuoSection;
  String get gamesDuoExplain;
  String get gamesLocalNote;
  String gameName(String gameId);
  String gameTagline(String gameId);
  String get gameDuoBadge;
  String difficulty(String level);

  // ── Commun
  String get play;
  String get playAgain;
  String get next;
  String get nextLevel;
  String get allLevels;
  String get backToGames;
  String get undo;
  String get restart;
  String get hint;
  String get skip;
  String get clear;
  String get stop;
  String get wellDone;
  String get timerOn;
  String get timerOff;
  String hintsUsed(int count);
  String get saveError;

  // ── Connexion mystère
  String get pathRules;
  String pathLevel(int number);
  String pathFilled(int filled, int total);
  String pathLevelsDone(int done, int total);
  String pathSolvedBody(String time);
  String get pathFillEverything;
  String pathGoThrough(int number);
  String get pathLocked;
  String get pathAllDone;
  String pathBoardLabel(int size, int filled, int total);
  String pathLevelLabel(int number, {required bool done, required bool locked});

  // ── Mémoire
  String memoryPairs(int count);
  String memoryMoves(int count);
  String memoryFound(int found, int total);
  String memorySolvedBody(int moves);
  String memoryBest(int moves);
  String get memoryNewBest;
  String get memoryHiddenCard;
  String memorySymbol(String id);

  // ── Tu préfères ?
  String questionOf(int index, int total);
  String get wyrOr;
  String get wyrSummaryTitle;
  String get wyrSummaryBody;
  String wyrTheme(String theme);
  List<WyrText> get wyrQuestions;

  // ── Mots mélangés
  String wordOf(int index, int total);
  String wordTheme(String theme);
  String get wordWrong;
  String get wordFound;
  String wordSolvedBody(int found, int total);
  String wordAnswerWas(String word);
  String get wordTapLetters;
  List<WordText> get words;

  // ── Jouer à deux
  String get duoPlusTooltip;
  String duoPickerTitle(String name);
  String duoPickerSubtitle(String name);
  String get duoInvite;
  String duoInviteSent(String name);
  String duoInvitedYou(String name, String game);
  String duoWaitingAccept(String name);
  String get duoAccept;
  String get duoDecline;
  String get duoCancelInvite;
  String duoDeclined(String name);
  String get duoExpired;
  String duoInProgress(String game);
  String get duoResume;
  String duoFinished(String game);
  String get duoSeeResult;
  String get duoStopped;
  String duoWaitingAnswer(String name);
  String duoPartnerChoice(String name);
  String get duoYourChoice;
  String get duoSame;
  String get duoDifferent;
  String duoCommon(int common, int total);
  String get duoDisclaimer;
  String get duoBackToChat;
  String get duoStopTitle;
  String get duoStopBody;
  String duoPartnerProgress(String name, int done, int total);
  String duoPartnerNotDone(String name);
  String duoWordsScore(String name, int mine, int theirs, int total);
  String get duoErrLimit;
  String get duoErrOpen;
  String get duoErrUnavailable;
  String get duoErrNetwork;
  String get duoNotFound;
}

/// Raccourci : `context.gs.gamesTitle`.
extension ZGameStringsContext on BuildContext {
  ZGameStrings get gs {
    final language = LanguageScope.maybeOf(this)?.language;
    return language == AppLanguage.en && language!.isTranslated ? const ZGameStringsEn() : const ZGameStringsFr();
  }
}

/// Durée « m:ss » (chronomètre des jeux).
String formatGameDuration(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
