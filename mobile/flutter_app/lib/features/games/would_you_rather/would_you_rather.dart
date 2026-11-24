/// « Tu préfères ? » : choix des questions d'une série et déroulement. Dart pur, testé dans
/// test/games/would_you_rather_test.dart.
library;

import 'dart:math';

/// Réponses possibles, identiques en solo et à deux (`game_answers.answer`, migration 0080).
const wyrChoiceA = 'a';
const wyrChoiceB = 'b';

/// Nombre de questions d'une série.
const wyrSeriesLength = 8;

/// Tire [count] questions : d'abord celles auxquelles le membre n'a jamais répondu, puis les autres, au hasard.
List<String> pickWyrSeries(List<String> allIds, Set<String> answered, Random random, {int count = wyrSeriesLength}) {
  final fresh = allIds.where((id) => !answered.contains(id)).toList()..shuffle(random);
  final seen = allIds.where(answered.contains).toList()..shuffle(random);
  return [...fresh, ...seen].take(count).toList();
}

/// Une série en cours : les réponses sont données dans l'ordre.
class WyrRound {
  WyrRound(this.ids, {Map<int, String> answers = const <int, String>{}}) : _answers = {...answers};

  final List<String> ids;
  final Map<int, String> _answers;

  Map<int, String> get answers => Map<int, String>.unmodifiable(_answers);

  /// Première question sans réponse (= nombre de réponses si elles sont données dans l'ordre).
  int get index {
    for (var i = 0; i < ids.length; i++) {
      if (!_answers.containsKey(i)) return i;
    }
    return ids.length;
  }

  bool get isDone => index >= ids.length;
  String? get currentId => isDone ? null : ids[index];

  /// Enregistre le choix pour la question en cours. `false` si la série est finie ou le choix invalide.
  bool choose(String choice) {
    if (isDone || (choice != wyrChoiceA && choice != wyrChoiceB)) return false;
    _answers[index] = choice;
    return true;
  }
}

/// Nombre de questions où les deux membres ont fait le même choix (parmi celles où tous deux ont répondu).
int wyrCommonChoices(Map<int, String> mine, Map<int, String> theirs) =>
    mine.entries.where((e) => theirs[e.key] == e.value).length;
