import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zaya/app.dart';
import 'package:zaya/core/widgets.dart';
import 'package:zaya/data/demo_repository.dart';
import 'package:zaya/data/models.dart';

import 'app_flow_test.dart' show draftAtHorizonStep, finishOnboarding, settle, tapText, usePhoneScreen;

/// Démo dont le membre est Premium (la fleur ne part que pour un membre Premium, comme sur le serveur).
class _PremiumDemo extends DemoRepository {
  @override
  Future<MyProfile?> loadMyProfile() async {
    final p = await super.loadMyProfile();
    p?.isPremium = true;
    return p;
  }
}

/// Demandes du propriétaire (25/11/2026) : sélection et suppression de conversations, point vert « en ligne »,
/// Fleur Premium réellement envoyée. Les règles serveur sont testées dans supabase/tests (migration 0070).
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

  Future<void> start(WidgetTester tester, DemoRepository repo) async {
    usePhoneScreen(tester);
    SharedPreferences.setMockInitialValues(draftAtHorizonStep());
    await tester.pumpWidget(ZayaApp(repository: repo));
    await settle(tester);
    await finishOnboarding(tester);
  }

  testWidgets('Conversations : point vert, sélection par appui long, suppression pour moi', (tester) async {
    await start(tester, DemoRepository());
    await tapText(tester, 'Messages');
    expect(find.text('Thierno'), findsOneWidget);
    expect(find.byType(OnlineDot), findsWidgets, reason: 'Thierno est en ligne en démo');

    await tester.longPress(find.text('Thierno'));
    await settle(tester);
    expect(find.text('1 sélectionnée'), findsOneWidget);
    await tester.tap(find.byTooltip('Supprimer pour moi'));
    await settle(tester);
    expect(find.text('Supprimer cette conversation ?'), findsOneWidget);
    expect(find.textContaining('de votre côté uniquement'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Supprimer'));
    await settle(tester);
    expect(find.text('Conversation supprimée'), findsOneWidget);
    expect(find.text('Thierno'), findsNothing);
    expect(find.text('1 sélectionnée'), findsNothing, reason: 'la sélection se ferme après la suppression');
  });

  testWidgets('Conversations : un appui pendant la sélection coche au lieu d’ouvrir ; la croix annule', (tester) async {
    await start(tester, DemoRepository());
    await tapText(tester, 'Messages');
    await tester.longPress(find.text('Thierno'));
    await settle(tester);
    await tester.tap(find.text('Thierno'));
    await settle(tester);
    expect(find.text('1 sélectionnée'), findsNothing, reason: 'second appui : décoché, la sélection se ferme');
    expect(find.byType(TextField), findsOneWidget, reason: 'aucune conversation ouverte (seule la recherche)');
    await tester.longPress(find.text('Thierno'));
    await settle(tester);
    await tester.tap(find.byTooltip('Annuler la sélection'));
    await settle(tester);
    expect(find.text('Messages'), findsWidgets);
    expect(find.text('Thierno'), findsOneWidget, reason: 'rien n’est supprimé');
  });

  testWidgets('Fleur Premium : envoyée à la personne affichée', (tester) async {
    await start(tester, _PremiumDemo());
    await tester.tap(find.bySemanticsLabel('Envoyer une fleur (Premium)'));
    await settle(tester);
    expect(find.textContaining('Fleur envoyée à'), findsOneWidget);
  });

  testWidgets('Fleur sans Premium : l’offre Premium s’ouvre, rien n’est envoyé', (tester) async {
    await start(tester, DemoRepository());
    await tester.tap(find.bySemanticsLabel('Envoyer une fleur (Premium)'));
    await settle(tester);
    expect(find.textContaining('Fleur envoyée à'), findsNothing);
    expect(find.text('Envoyer des fleurs pour vous faire remarquer'), findsOneWidget);
  });
}
