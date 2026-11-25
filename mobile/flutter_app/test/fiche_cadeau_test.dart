import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zaya/app.dart';
import 'package:zaya/data/demo_repository.dart';
import 'package:zaya/data/models.dart';
import 'package:zaya/features/discovery/profile_detail_screen.dart';
import 'package:zaya/features/home/home_shell.dart';

/// Fiche profil : « Offrir un cadeau » sur la fiche d'un autre membre, jamais sur la sienne (boutique, 0035).
void main() {
  // Vraies polices embarquées (comme sur un téléphone), sans accès réseau.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
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

  Future<void> ouvrirFiche(WidgetTester tester, String userId) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2.0;
    tester.platformDispatcher.localesTestValue = const [Locale('fr', 'FR')];
    tester.platformDispatcher.localeTestValue = const Locale('fr', 'FR');
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    SharedPreferences.setMockInitialValues({});
    final repo = DemoRepository();
    await repo.verifyOtp('+224622112233', DemoRepository.demoOtp);
    await repo.saveOnboarding(OnboardingDraft()
      ..displayName = 'Awa'
      ..birthDate = DateTime(1998, 5, 10)
      ..gender = 'femme'
      ..cityId = 4
      ..horizon = 'soon'
      ..ageMin = 18
      ..ageMax = 60);
    await tester.pumpWidget(ZayaApp(repository: repo));
    await tester.pumpAndSettle(const Duration(milliseconds: 40), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 20));
    Navigator.of(tester.element(find.byType(HomeShell)))
        .push(MaterialPageRoute<void>(builder: (_) => ProfileDetailScreen(userId: userId, name: 'Test')));
    await tester.pumpAndSettle(const Duration(milliseconds: 40), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 20));
  }

  testWidgets('le bouton cadeau apparaît sur la fiche d’un autre membre', (tester) async {
    await ouvrirFiche(tester, 'm1');
    expect(find.byTooltip('Offrir un cadeau'), findsOneWidget);
  });

  testWidgets('pas de cadeau à soi-même', (tester) async {
    await ouvrirFiche(tester, 'demo-me');
    expect(find.byTooltip('Offrir un cadeau'), findsNothing);
  });
}
