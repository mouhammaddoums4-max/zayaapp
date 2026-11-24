import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Progression des jeux en solo, gardée sur le téléphone uniquement (rien n'est envoyé au serveur).
/// Toute lecture ou écriture tolère un stockage indisponible : le jeu continue, la progression n'est simplement
/// pas conservée.
class GamesProgress {
  const GamesProgress._();

  static const _pathDone = 'zaya_games_path_done';
  static const _pathCurrent = 'zaya_games_path_current_';
  static const _memoryBest = 'zaya_games_memory_best_';
  static const _timer = 'zaya_games_timer';
  static const _wyrAnswers = 'zaya_games_wyr_answers';
  static const _wyrSeries = 'zaya_games_wyr_series';
  static const _wordsSeen = 'zaya_games_words_seen';

  static Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  static Future<bool> _write(Future<bool> Function(SharedPreferences prefs) action) async {
    final prefs = await _prefs();
    if (prefs == null) return false;
    try {
      return await action(prefs);
    } catch (_) {
      return false;
    }
  }

  // ── Connexion mystère
  static Future<Set<String>> pathCompleted() async =>
      ((await _prefs())?.getStringList(_pathDone) ?? const <String>[]).toSet();

  static Future<bool> markPathCompleted(String levelId) => _write((prefs) {
        final done = {...?prefs.getStringList(_pathDone), levelId}.toList()..sort();
        prefs.remove('$_pathCurrent$levelId');
        return prefs.setStringList(_pathDone, done);
      });

  /// Chemin en cours d'un niveau (reprise après fermeture ou retour arrière).
  static Future<List<int>> pathInProgress(String levelId) async {
    final raw = (await _prefs())?.getString('$_pathCurrent$levelId');
    if (raw == null) return const <int>[];
    try {
      return (jsonDecode(raw) as List).cast<int>();
    } catch (_) {
      return const <int>[];
    }
  }

  static Future<bool> savePathInProgress(String levelId, List<int> path) => _write((prefs) => path.length <= 1
      ? prefs.remove('$_pathCurrent$levelId')
      : prefs.setString('$_pathCurrent$levelId', jsonEncode(path)));

  // ── Mémoire
  static Future<int?> memoryBest(String level) async => (await _prefs())?.getInt('$_memoryBest$level');

  /// Enregistre le score s'il bat le précédent. Retourne `true` en cas de nouveau record.
  static Future<bool> recordMemoryScore(String level, int moves) async {
    final best = await memoryBest(level);
    if (best != null && best <= moves) return false;
    await _write((prefs) => prefs.setInt('$_memoryBest$level', moves));
    return true;
  }

  // ── Chronomètre (facultatif, partagé par les jeux)
  static Future<bool> timerEnabled() async => (await _prefs())?.getBool(_timer) ?? false;
  static Future<bool> setTimerEnabled(bool enabled) => _write((prefs) => prefs.setBool(_timer, enabled));

  // ── Tu préfères ?
  static Future<Map<String, String>> wyrAnswers() async {
    final raw = (await _prefs())?.getString(_wyrAnswers);
    if (raw == null) return const <String, String>{};
    try {
      return (jsonDecode(raw) as Map).cast<String, String>();
    } catch (_) {
      return const <String, String>{};
    }
  }

  static Future<bool> saveWyrAnswer(String questionId, String choice) async {
    final answers = {...await wyrAnswers(), questionId: choice};
    return _write((prefs) => prefs.setString(_wyrAnswers, jsonEncode(answers)));
  }

  /// Série en cours (identifiants des questions), pour reprendre là où l'on s'était arrêté.
  static Future<List<String>> wyrSeries() async =>
      (await _prefs())?.getStringList(_wyrSeries) ?? const <String>[];
  static Future<bool> saveWyrSeries(List<String> ids) =>
      _write((prefs) => ids.isEmpty ? prefs.remove(_wyrSeries) : prefs.setStringList(_wyrSeries, ids));

  // ── Mots mélangés : mots déjà proposés (pour varier les séries suivantes)
  static Future<Set<String>> wordsSeen() async =>
      ((await _prefs())?.getStringList(_wordsSeen) ?? const <String>[]).toSet();
  static Future<bool> addWordsSeen(Iterable<String> ids) => _write((prefs) {
        final seen = {...?prefs.getStringList(_wordsSeen), ...ids}.toList();
        return prefs.setStringList(_wordsSeen, seen);
      });
  static Future<bool> resetWordsSeen() => _write((prefs) => prefs.remove(_wordsSeen));
}
