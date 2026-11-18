import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zaya/core/app_info.dart';
import 'package:zaya/core/l10n/l10n.dart';
import 'package:zaya/core/l10n/strings_en.dart';
import 'package:zaya/core/l10n/strings_fr.dart';
import 'package:zaya/data/models.dart';
import 'package:zaya/features/settings/help_content.dart';
import 'package:zaya/features/settings/legal_screen.dart';
import 'package:zaya/features/settings/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Langue de l’interface (§22.15)', () {
    test('français par défaut ; une langue non traduite ne peut pas être choisie', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final c = LanguageController();
      await c.restore();
      expect(c.language, AppLanguage.fr);
      for (final l in [AppLanguage.pular, AppLanguage.maninka, AppLanguage.soso]) {
        expect(l.isTranslated, isFalse, reason: '${l.code} ne doit pas être annoncée avant relecture');
        await c.select(l);
        expect(c.language, AppLanguage.fr);
      }
      expect(AppLanguage.en.isTranslated, englishInterfaceComplete);
    });

    test('le choix est mémorisé et repris au lancement suivant', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{LanguageController.prefsKey: 'fr'});
      final c = LanguageController(initial: AppLanguage.fr);
      await c.restore();
      expect(c.language, AppLanguage.fr);
      expect(c.locale.languageCode, 'fr');
    });

    test('une langue mémorisée mais pas (encore) disponible n’est pas appliquée', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{LanguageController.prefsKey: 'sus'});
      final c = LanguageController();
      await c.restore();
      expect(c.language, AppLanguage.fr);
    });

    test('aide : questions venues de Supabase, regroupées par rubrique dans l’ordre choisi', () {
      final sections = groupHelp(const [
        HelpArticle(section: 'Compte', question: 'Q1', answer: 'R1'),
        HelpArticle(section: 'Sécurité', question: 'Q2', answer: 'R2'),
        HelpArticle(section: 'Compte', question: 'Q3', answer: 'R3'),
      ]);
      expect(sections.map((s) => s.title), ['Compte', 'Sécurité']);
      expect(sections.first.articles.map((a) => a.question), ['Q1', 'Q3']);
    });

    test('noms des langues présents en français et en anglais', () {
      const fr = ZStringsFr();
      const en = ZStringsEn();
      for (final l in AppLanguage.values) {
        expect(fr.languageName(l), isNotEmpty);
        expect(en.languageName(l), isNotEmpty);
      }
    });
  });

  group('Réglages', () {
    test('mon numéro, lisible pour moi seul', () {
      expect(formatOwnPhone('224620000001'), '+224 620 00 00 01');
      expect(formatOwnPhone('+224 620 00 00 01'), '+224 620 00 00 01');
      expect(formatOwnPhone('33612345678'), '+33612345678');
    });

    test('la version affichée correspond à pubspec.yaml', () {
      final line = File('pubspec.yaml').readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
      expect(line.trim(), 'version: $appVersion+$appBuildNumber');
    });
  });

  group('Documents légaux', () {
    LegalDocument doc(String kind, String version, String lang, DateTime at) =>
        LegalDocument(kind: kind, version: version, lang: lang, content: '$kind $version $lang', publishedAt: at);

    final all = [
      doc('tos', 'v0-draft', 'fr', DateTime(2026, 11, 1)),
      doc('tos', 'v1', 'fr', DateTime(2026, 11, 10)),
      doc('privacy', 'v1', 'fr', DateTime(2026, 11, 10)),
      doc('privacy', 'v1', 'en', DateTime(2026, 11, 12)),
    ];

    test('la version la plus récente, dans ma langue si elle existe', () {
      expect(pickLegalDocument(all, 'tos', 'fr').doc?.version, 'v1');
      final privacy = pickLegalDocument(all, 'privacy', 'en');
      expect(privacy.doc?.lang, 'en');
      expect(privacy.fallback, isFalse);
    });

    test('sinon le français, en le signalant ; rien si le document n’existe pas', () {
      final tos = pickLegalDocument(all, 'tos', 'en');
      expect(tos.doc?.lang, 'fr');
      expect(tos.fallback, isTrue);
      expect(pickLegalDocument(all, 'community', 'fr').doc, isNull);
    });

    test('une version « v0 » est un brouillon', () {
      expect(all.first.isDraft, isTrue);
      expect(all[1].isDraft, isFalse);
    });
  });
}
