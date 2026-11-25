import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zaya/app.dart';
import 'package:zaya/data/demo_repository.dart';
import 'package:zaya/features/auth/pin_pad.dart';
import 'package:zaya/features/home/home_shell.dart';

import 'app_flow_test.dart' show draftAtHorizonStep, finishOnboarding, scrollToText, settle, tapText, usePhoneScreen;

/// Connexion par numéro + code à 4 chiffres (décision du propriétaire, 25/11/2026), en démo : mêmes règles que le
/// serveur (supabase/tests/code_connexion_tests.mjs).
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'), (call) async => Directory.systemTemp.path);
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

  /// Tape un code sur le clavier à code (le code part au 4ᵉ chiffre).
  Future<void> enterPin(WidgetTester tester, String pin) async {
    for (final d in pin.split('')) {
      await tester.tap(find.descendant(of: find.byType(PinPad), matching: find.text(d)));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.pump(const Duration(milliseconds: 150));
    await settle(tester);
  }

  Future<void> signOutTo(WidgetTester tester) async {
    await Session.read(tester.element(find.byType(HomeShell))).signOut();
    await settle(tester);
  }

  testWidgets('Inscription : le code est choisi à l’arrivée ; un code trop facile est refusé', (tester) async {
    usePhoneScreen(tester);
    SharedPreferences.setMockInitialValues(draftAtHorizonStep());
    await tester.pumpWidget(ZayaApp(repository: DemoRepository(initialPin: null)));
    await settle(tester);
    await finishOnboarding(tester);
    expect(find.text('Choisissez votre code'), findsOneWidget);
    await enterPin(tester, '1234');
    expect(find.textContaining('trop facile'), findsOneWidget);
    await enterPin(tester, '5829');
    expect(find.text('Confirmez votre code'), findsOneWidget);
    await enterPin(tester, '5820');
    expect(find.textContaining('pas identiques'), findsOneWidget);
    await enterPin(tester, '5829');
    await enterPin(tester, '5829');
    expect(find.text('Messages'), findsWidgets, reason: 'retour dans l’application');
  });

  testWidgets('Reconnexion : numéro puis code, sans SMS ; code faux signalé avec les essais restants', (tester) async {
    usePhoneScreen(tester);
    SharedPreferences.setMockInitialValues(draftAtHorizonStep());
    await tester.pumpWidget(ZayaApp(repository: DemoRepository()));
    await settle(tester);
    await finishOnboarding(tester);
    await signOutTo(tester);

    await tapText(tester, 'J’ai déjà un compte');
    await tester.enterText(find.byType(TextField), '622 11 22 33');
    await tapText(tester, 'Continuer');
    expect(find.text('Entrez votre code'), findsOneWidget);
    expect(find.text('+224 6•• •• 22 33'), findsOneWidget, reason: 'numéro partiellement masqué');
    await enterPin(tester, '0000');
    expect(find.textContaining('Encore 4 essais'), findsOneWidget);
    await enterPin(tester, DemoRepository.demoPin);
    expect(find.text('Messages'), findsWidgets);
  });

  testWidgets('Numéro inconnu : proposition de créer son profil', (tester) async {
    usePhoneScreen(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(ZayaApp(repository: DemoRepository()));
    await settle(tester);
    await tapText(tester, 'J’ai déjà un compte');
    await tester.enterText(find.byType(TextField), '699 99 99 99');
    await tapText(tester, 'Continuer');
    expect(find.text('Aucun compte avec ce numéro'), findsOneWidget);
    await tapText(tester, 'Créer mon profil');
    expect(find.textContaining('Étape'), findsWidgets, reason: 'inscription ouverte');
  });

  testWidgets('Code oublié : SMS de vérification, puis nouveau code', (tester) async {
    usePhoneScreen(tester);
    SharedPreferences.setMockInitialValues(draftAtHorizonStep());
    await tester.pumpWidget(ZayaApp(repository: DemoRepository()));
    await settle(tester);
    await finishOnboarding(tester);
    await signOutTo(tester);

    await tapText(tester, 'J’ai déjà un compte');
    await tester.enterText(find.byType(TextField), '622112233');
    await tapText(tester, 'Continuer');
    await tapText(tester, 'Code oublié ?');
    expect(find.text('Vérifions votre numéro'), findsOneWidget);
    await tapText(tester, 'Recevoir le code');
    await tester.enterText(find.byType(TextField).last, DemoRepository.demoOtp);
    await tester.pump();
    await tapText(tester, 'Vérifier');
    expect(find.text('Choisissez un nouveau code'), findsOneWidget);
    await enterPin(tester, '7391');
    await enterPin(tester, '7391');
    expect(find.text('Messages'), findsWidgets);
  });

  testWidgets('Réglages : changer son code (ancien code exigé)', (tester) async {
    usePhoneScreen(tester);
    SharedPreferences.setMockInitialValues(draftAtHorizonStep());
    await tester.pumpWidget(ZayaApp(repository: DemoRepository()));
    await settle(tester);
    await finishOnboarding(tester);
    await tapText(tester, 'Profil');
    await tester.tap(find.byTooltip('Réglages'));
    await settle(tester);
    await scrollToText(tester, 'Code de connexion');
    await tapText(tester, 'Code de connexion');
    expect(find.text('Votre code actuel'), findsOneWidget);
    await enterPin(tester, '1111');
    expect(find.text('Choisissez un nouveau code'), findsOneWidget);
    await enterPin(tester, '4826');
    await enterPin(tester, '4826');
    expect(find.text('Code actuel incorrect.'), findsOneWidget, reason: 'mauvais ancien code : refus du serveur');
    expect(find.text('Votre code actuel'), findsOneWidget, reason: 'l’ancien code est redemandé');
    await enterPin(tester, DemoRepository.demoPin);
    await enterPin(tester, '4826');
    await enterPin(tester, '4826');
    expect(find.textContaining('Code enregistré'), findsOneWidget);
  });
}
