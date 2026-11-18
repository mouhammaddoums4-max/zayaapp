import 'package:flutter_test/flutter_test.dart';
import 'package:zaya/core/content_rules.dart';

/// Mêmes exemples que les tests serveur de `contains_link` (supabase/tests/securite_tests.mjs, migration 0051).
void main() {
  test('liens détectés : protocole, www, domaines, raccourcisseurs, chemins, écritures détournées', () {
    for (final t in [
      'Regarde https://exemple.org/page', 'http://192.168.1.10:8080', 'Va sur www.monsite.gn',
      'Clique sur WWW . arnaque . com', 'mon-site.com', 'Profil sur facebook.com/awa.diallo',
      'bit.ly/3xYz', 'Écris-moi sur wa.me/224620000000', 'zaya.app', 'boutique.shop', 'intent://scan',
      'monsite.gn/inscription', 'site . com', 'arnaque point com', 'cadeau.online',
    ]) {
      expect(containsLink(t), isTrue, reason: t);
    }
  });

  test('phrases ordinaires acceptées : fins de phrase, e-mails, abréviations, nombres', () {
    for (final t in [
      'Bonjour, comment vas-tu ?', 'C’est bon. Top !', 'Merci. Info du jour : il pleut.', 'ok.Ma sœur arrive',
      'Bien.Me voilà', 'M.Diallo et Dr.Bah', 'Mon e-mail : awa.diallo@gmail.com', 'Il coûte 2.500.000 GNF',
      'Rendez-vous à 14h.30', 'etc. Comment allez-vous ?', 'Je suis à Conakry. Comment ça va ?',
    ]) {
      expect(containsLink(t), isFalse, reason: t);
    }
  });
}
