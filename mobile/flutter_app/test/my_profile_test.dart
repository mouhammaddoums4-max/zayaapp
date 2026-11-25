import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zaya/app.dart';
import 'package:zaya/data/demo_repository.dart';

import 'app_flow_test.dart' show draftAtHorizonStep, finishOnboarding, settle, tapText, usePhoneScreen;

/// « Je n'arrive pas à voir mes photos » (propriétaire, 25/11/2026) : Mon profil montre toutes mes photos, la
/// principale, l'ajout, la suppression et l'aperçu public.
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

  testWidgets('Mon profil : mes photos, principale, suppression, conseils et aperçu', (tester) async {
    usePhoneScreen(tester);
    SharedPreferences.setMockInitialValues(draftAtHorizonStep());
    final repo = DemoRepository();
    await tester.pumpWidget(ZayaApp(repository: repo));
    await settle(tester);
    await finishOnboarding(tester);
    await repo.addPhoto(Uint8List(0));
    await repo.addPhoto(Uint8List(0));

    await tapText(tester, 'Profil');
    await tester.tap(find.textContaining('mon profil  →'));
    await settle(tester);
    expect(find.text('Aperçu'), findsOneWidget);
    expect(find.text('Modifier'), findsOneWidget);
    expect(find.text('Profil complet'), findsOneWidget);
    expect(find.bySemanticsLabel('Photo principale'), findsOneWidget);
    expect(find.bySemanticsLabel('Photo'), findsOneWidget);
    expect(find.bySemanticsLabel('Ajouter une photo'), findsOneWidget);
    expect(find.textContaining('2/6 photos'), findsOneWidget);

    // Conseils photo.
    await tapText(tester, 'Conseils photo');
    expect(find.text('Des photos qui inspirent confiance'), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await settle(tester);

    // La seconde photo devient principale.
    await tester.ensureVisible(find.bySemanticsLabel('Photo'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Photo'));
    await settle(tester);
    await tapText(tester, 'Mettre en photo principale');
    expect(find.bySemanticsLabel('Photo principale'), findsOneWidget);

    // Suppression : avertissement sous le minimum de photos, puis une seule photo restante.
    await tester.ensureVisible(find.bySemanticsLabel('Photo principale'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Photo principale'));
    await settle(tester);
    await tapText(tester, 'Supprimer cette photo');
    expect(find.textContaining('ne sera plus proposé'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Supprimer'));
    await settle(tester);
    expect(find.textContaining('1/6 photos'), findsOneWidget);

    // Aperçu : le profil tel que les autres le voient.
    await tapText(tester, 'Aperçu');
    expect(find.text('Voici comment les autres membres voient votre profil.'), findsOneWidget);
    expect(find.textContaining('Awa'), findsWidgets);
  });
}
