import 'package:flutter_test/flutter_test.dart';
import 'package:zaya/core/phone_mask.dart';

List<String> phonesIn(String text) => [
      for (final s in splitPhones(text))
        if (s.isPhone) s.text,
    ];

void main() {
  group('Détection des numéros de téléphone (V6.3 §34.1)', () {
    test('formats guinéens et internationaux', () {
      expect(phonesIn('Appelle-moi au +224 622 11 22 33 ce soir'), ['+224 622 11 22 33']);
      expect(phonesIn('mon numéro 622112233'), ['622112233']);
      expect(phonesIn('622-11-22-33'), ['622-11-22-33']);
      expect(phonesIn('6 2 2 1 1 2 2 3 3'), ['6 2 2 1 1 2 2 3 3']);
      expect(phonesIn('00224622112233 merci'), ['00224622112233']);
      expect(phonesIn('WhatsApp : +33 6 12 34 56 78.'), ['+33 6 12 34 56 78']);
    });

    test('ne masque pas les dates, montants, références ni petits nombres', () {
      expect(containsPhone('On se voit le 12/05/2026 ?'), isFalse);
      expect(containsPhone('Le loyer est de 15 000 000 GNF par an'), isFalse);
      expect(containsPhone('Ça coûte 2 500 000 francs'), isFalse);
      expect(containsPhone('Commande n° 20261116001'), isFalse);
      expect(containsPhone('Référence : 458 221 963 00'), isFalse);
      expect(containsPhone('J’ai 27 ans et 2 enfants'), isFalse);
      expect(containsPhone('Rendez-vous à 18h30 au café'), isFalse);
      expect(containsPhone('En 2026 ou 2027'), isFalse);
    });

    test('le texte autour du numéro est conservé tel quel', () {
      final segments = splitPhones('Voici mon numéro : +224 622 11 22 33, à bientôt');
      expect(segments.map((s) => s.text).join(), 'Voici mon numéro : +224 622 11 22 33, à bientôt');
      expect(segments.where((s) => s.isPhone), hasLength(1));
    });

    test('plusieurs numéros dans un même message', () {
      expect(phonesIn('Orange 622112233 ou MTN 664 55 66 77'), ['622112233', '664 55 66 77']);
    });
  });

  group('Masquage', () {
    test('conserve l’indicatif, masque le reste', () {
      expect(maskPhone('+224 622 11 22 33'), '+224 ••• •• •• ••');
      expect(maskPhone('622112233'), '••• •• •• ••');
      expect(maskPhone('00224622112233'), startsWith('00224'));
    });

    test('le numéro masqué ne contient plus aucun chiffre du numéro local', () {
      expect(maskPhone('+224 622 11 22 33').contains('622'), isFalse);
    });
  });
}
