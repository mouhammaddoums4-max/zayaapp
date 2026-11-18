import 'package:flutter_test/flutter_test.dart';
import 'package:zaya/data/models.dart';
import 'package:zaya/features/chat/chat_screen.dart';

/// Messagerie : ordre des messages, séparateurs de date, emojis seuls.
void main() {
  test('messages remis du plus ancien au plus récent : le dernier envoyé reste en bas', () {
    final t = DateTime(2026, 11, 18, 9);
    ChatMessage m(String id, int minutes) =>
        ChatMessage(id: id, senderId: 'a', body: id, createdAt: t.add(Duration(minutes: minutes)));
    final duPlusRecent = [m('3', 30), m('2', 20), m('1', 10)];
    expect(chronologique(duPlusRecent).map((x) => x.id), ['1', '2', '3']);
    expect(duPlusRecent.first.id, '3', reason: 'la liste d’origine n’est pas modifiée');
    expect(chronologique([m('1', 10), m('2', 20)]).map((x) => x.id), ['1', '2'], reason: 'déjà dans l’ordre');
  });

  test('séparateurs de date : Aujourd’hui, Hier, jour de la semaine, puis la date', () {
    final maintenant = DateTime(2026, 11, 18, 10); // mercredi
    expect(libelleJour(DateTime(2026, 11, 18, 7), maintenant: maintenant), 'Aujourd’hui');
    expect(libelleJour(DateTime(2026, 11, 17, 23), maintenant: maintenant), 'Hier');
    expect(libelleJour(DateTime(2026, 11, 16), maintenant: maintenant), 'Lundi');
    expect(libelleJour(DateTime(2026, 11, 12), maintenant: maintenant), 'Jeudi');
    expect(libelleJour(DateTime(2026, 11, 1), maintenant: maintenant), '1er novembre');
    expect(libelleJour(DateTime(2025, 12, 25), maintenant: maintenant), '25 décembre 2025');
  });

  test('emojis seuls : reconnus (y compris drapeaux et familles), jamais du texte ou des chiffres', () {
    expect(queDesEmojis('😊'), isTrue);
    expect(queDesEmojis(' ❤️ 😍 '), isTrue);
    expect(queDesEmojis('🇬🇳'), isTrue);
    expect(queDesEmojis('👨‍👩‍👧'), isTrue);
    expect(queDesEmojis('Merci 😊'), isFalse);
    expect(queDesEmojis('123'), isFalse);
    expect(queDesEmojis(''), isFalse);
    expect(queDesEmojis('😊😊😊😊😊😊😊'), isFalse, reason: 'au-delà de 6, taille normale');
  });
}
