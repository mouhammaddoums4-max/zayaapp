import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zaya/app.dart';
import 'package:zaya/core/app_info.dart';
import 'package:zaya/data/demo_repository.dart';
import 'package:zaya/data/models.dart';
import 'package:zaya/features/app/app_update.dart';
import 'package:zaya/features/app/rating_prompt.dart';

/// Mode démo dont les réglages publics (app_config) sont imposés par le test.
class _ConfiguredDemo extends DemoRepository {
  _ConfiguredDemo(this.config);
  final Map<String, Object?> config;

  @override
  Future<Map<String, Object?>> publicConfig() async => config;
}

Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle(
    const Duration(milliseconds: 40), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 20));

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Polices embarquées chargées d'avance, comme dans app_flow_test.dart.
    GoogleFonts.config.allowRuntimeFetching = false;
    await GoogleFonts.pendingFonts([
      GoogleFonts.inter(),
      GoogleFonts.inter(fontWeight: FontWeight.w500),
      GoogleFonts.inter(fontWeight: FontWeight.w600),
      GoogleFonts.inter(fontWeight: FontWeight.w700),
      GoogleFonts.sora(fontWeight: FontWeight.w600),
      GoogleFonts.sora(fontWeight: FontWeight.w700),
    ]);
  });

  group('Versions', () {
    test('comparaison numérique, parties manquantes à zéro', () {
      expect(compareVersions('0.1.0', '0.1.0'), 0);
      expect(compareVersions('0.1', '0.1.0'), 0);
      expect(compareVersions('0.1.0', '0.2.0'), lessThan(0));
      expect(compareVersions('0.10.0', '0.9.9'), greaterThan(0), reason: 'pas un tri alphabétique');
      expect(compareVersions('1.0.0+3', '1.0.0'), 0, reason: 'le numéro de build est ignoré');
    });

    test('à jour, mise à jour proposée, mise à jour obligatoire', () {
      expect(evaluateUpdate(const {}).level, UpdateLevel.none, reason: 'sans réglage, rien n’est imposé');
      expect(evaluateUpdate(const {'latest_app_version': '0.1.0', 'min_app_version': '0.1.0'}).level, UpdateLevel.none);
      final available = evaluateUpdate(const {'latest_app_version': '0.2.0', 'min_app_version': '0.1.0'});
      expect(available.level, UpdateLevel.available);
      expect(available.latest, '0.2.0');
      final required = evaluateUpdate(
          const {'latest_app_version': '0.3.0', 'min_app_version': '0.2.0', 'app_update_url': 'https://exemple.test'});
      expect(required.level, UpdateLevel.required);
      expect(required.url, 'https://exemple.test');
    });
  });

  group('Demande d’avis', () {
    final first = DateTime(2026, 11, 1);
    const rules = RatingRules(minDays: 7, minSessions: 5, intervalDays: 90);

    test('jamais pour un nouveau membre', () {
      expect(
          shouldAskForRating(rules: rules, firstOpen: first, sessions: 2, lastAsked: null, now: DateTime(2026, 11, 20)),
          isFalse);
      expect(
          shouldAskForRating(rules: rules, firstOpen: first, sessions: 9, lastAsked: null, now: DateTime(2026, 11, 3)),
          isFalse);
    });

    test('après quelques jours et ouvertures, puis pas avant l’intervalle', () {
      final now = DateTime(2026, 11, 20);
      expect(shouldAskForRating(rules: rules, firstOpen: first, sessions: 6, lastAsked: null, now: now), isTrue);
      expect(
          shouldAskForRating(
              rules: rules, firstOpen: first, sessions: 6, lastAsked: now.subtract(const Duration(days: 30)), now: now),
          isFalse);
      expect(
          shouldAskForRating(
              rules: rules, firstOpen: first, sessions: 6, lastAsked: now.subtract(const Duration(days: 91)), now: now),
          isTrue);
    });

    test('désactivable depuis app_config', () {
      final off = RatingRules.fromConfig(const {'rating_prompt_enabled': false});
      expect(shouldAskForRating(rules: off, firstOpen: first, sessions: 50, lastAsked: null, now: DateTime(2027, 1, 1)),
          isFalse);
      final custom = RatingRules.fromConfig(const {'rating_min_sessions': 12});
      expect(custom.minSessions, 12);
      expect(custom.minDays, 7, reason: 'valeur par défaut si la clé manque');
    });
  });

  testWidgets('version trop ancienne : écran de mise à jour obligatoire, même sans être connecté', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(ZayaApp(repository: _ConfiguredDemo(const {'min_app_version': '9.0.0'})));
    await _settle(tester);
    expect(find.text('Mise à jour nécessaire'), findsOneWidget);
    expect(find.text('Mettre à jour'), findsOneWidget);
  });

  testWidgets('nouvelle version : proposée une seule fois, puis visible dans les Réglages', (tester) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final repo = _ConfiguredDemo(const {'latest_app_version': '9.9.9', 'min_app_version': '0.1.0'});
    await repo.verifyOtp('+224622112233', DemoRepository.demoOtp);
    final draft = OnboardingDraft()
      ..displayName = 'Awa'
      ..birthDate = DateTime(1998, 5, 10)
      ..gender = 'femme'
      ..cityId = 4;
    await repo.saveOnboarding(draft);

    await tester.pumpWidget(ZayaApp(repository: repo));
    await _settle(tester);
    expect(find.text('Nouvelle version disponible'), findsOneWidget);
    await tester.tap(find.text('Plus tard'));
    await _settle(tester);
    expect(find.text('Nouvelle version disponible'), findsNothing);

    // Relance de l'application : déjà proposée pour cette version, plus de fenêtre.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(ZayaApp(repository: repo));
    await _settle(tester);
    expect(find.text('Nouvelle version disponible'), findsNothing);

    await tester.tap(find.text('Profil').last);
    await _settle(tester);
    await tester.tap(find.byTooltip('Réglages'));
    await _settle(tester);
    expect(find.text('Version 9.9.9 disponible : mettre à jour'), findsOneWidget);

    // Fin propre : les minuteries de l'accueil (bouton Boost) se terminent avec l'arbre.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });
}
