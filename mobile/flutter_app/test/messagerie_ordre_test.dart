import 'package:flutter_test/flutter_test.dart';
import 'package:zaya/data/models.dart';
import 'package:zaya/features/chat/chat_screen.dart';

/// Le dernier message envoyé doit toujours être en bas de la conversation, même quand la source (flux temps réel
/// de Supabase) renvoie les messages du plus récent au plus ancien.
void main() {
  test('messages remis du plus ancien au plus récent', () {
    final t = DateTime(2026, 11, 18, 9);
    ChatMessage m(String id, int minutes) =>
        ChatMessage(id: id, senderId: 'a', body: id, createdAt: t.add(Duration(minutes: minutes)));
    final duPlusRecent = [m('3', 30), m('2', 20), m('1', 10)];
    expect(chronologique(duPlusRecent).map((x) => x.id), ['1', '2', '3']);
    expect(duPlusRecent.first.id, '3', reason: 'la liste d’origine n’est pas modifiée');
    expect(chronologique([m('1', 10), m('2', 20)]).map((x) => x.id), ['1', '2'], reason: 'déjà dans l’ordre');
  });
}
