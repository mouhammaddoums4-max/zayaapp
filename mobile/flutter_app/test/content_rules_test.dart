import 'package:flutter_test/flutter_test.dart';
import 'package:zaya/core/content_rules.dart';
import 'package:zaya/core/phone_mask.dart';
import 'package:zaya/data/models.dart';

/// Mêmes cas que le test serveur « détection des coordonnées » (supabase/tests/run.mjs).
void main() {
  group('Coordonnées interdites dans la Communauté', () {
    test('numéros, e-mails et liens de messagerie détectés', () {
      for (final text in [
        'Appelle-moi au 622 11 22 33',
        'mon numéro +224622112233',
        'écris-moi : awa.diallo@gmail.com',
        'mon whatsapp : wa.me/224622112233',
        'contacte-moi sur t.me/awa',
      ]) {
        expect(containsContactDetails(text), isTrue, reason: text);
      }
    });

    test('montants, dates et petits nombres acceptés', () {
      for (final text in [
        'La dot était de 5 000 000 GNF',
        'Budget : 25 000 000 de francs',
        'Rendez-vous le 12/05/2026 à 18h30',
        'Nous avons 2 enfants de 4 et 7 ans',
        'En 2025 nous nous sommes mariés',
      ]) {
        expect(containsContactDetails(text), isFalse, reason: text);
      }
    });

    test('dans la messagerie, un montant « de francs » n’est pas masqué comme un numéro', () {
      expect(containsPhone('Le loyer est de 15 000 000 de francs par an'), isFalse);
    });
  });

  group('Dates relatives', () {
    final now = DateTime(2026, 11, 17, 12);
    test('de « à l’instant » à la date complète', () {
      expect(formatRelative(now.subtract(const Duration(seconds: 20)), now: now), 'à l’instant');
      expect(formatRelative(now.subtract(const Duration(minutes: 5)), now: now), 'il y a 5 min');
      expect(formatRelative(now.subtract(const Duration(hours: 3)), now: now), 'il y a 3 h');
      expect(formatRelative(now.subtract(const Duration(hours: 30)), now: now), 'hier');
      expect(formatRelative(now.subtract(const Duration(days: 4)), now: now), 'il y a 4 j');
      expect(formatRelative(DateTime(2026, 10, 1, 9), now: now), '01/10/2026');
    });
  });
}
