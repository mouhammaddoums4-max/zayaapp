import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zaya/app.dart';
import 'package:zaya/data/demo_repository.dart';
import 'package:zaya/data/models.dart';

import 'app_flow_test.dart' show draftAtHorizonStep, finishOnboarding, goBack, settle, tapText, usePhoneScreen;

/// ZAYA 2.0 en mode démo : accès depuis le profil, Match du jour, surprise, question, défis, Pulse, invitation,
/// et avertissement anti-arnaque dans la messagerie. Les règles réelles sont testées côté serveur (supabase/tests).
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Le cache disque des photos demande un dossier temporaire : simulé, sans plugin.
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

  test('détection anti-arnaque (même règles que le serveur) : avertit sans faux positif courant', () {
    expect(demoScamCategory('Tu as un compte Orange Money ?'), 'mobile_money');
    expect(demoScamCategory('Donne-moi ton numéro de compte bancaire'), 'bank_details');
    expect(demoScamCategory('J’ai besoin d’argent urgent'), 'money_request');
    expect(demoScamCategory('Investis en bitcoin avec moi'), 'investment');
    for (final ok in ['Je travaille dans une banque', 'J’ai besoin de temps', 'Je t’envoie une photo de ma famille']) {
      expect(demoScamCategory(ok), isNull, reason: ok);
    }
  });

  testWidgets('ZAYA+ : surprise, question privée, défi, Pulse et code d’invitation', (tester) async {
    usePhoneScreen(tester);
    SharedPreferences.setMockInitialValues(draftAtHorizonStep());
    await tester.pumpWidget(ZayaApp(repository: DemoRepository()));
    await settle(tester);
    await finishOnboarding(tester);

    await tapText(tester, 'Profil');
    await tapText(tester, 'ZAYA+');
    expect(find.text('Match du jour'), findsOneWidget);
    expect(find.textContaining('pas une garantie de compatibilité'), findsOneWidget);

    // Surprise : chances réelles affichées avant l'ouverture, puis une question à laquelle répondre.
    expect(find.textContaining('Chances réelles'), findsOneWidget);
    await tapText(tester, 'Ouvrir la surprise');
    expect(find.textContaining('une question pour mieux vous connaître'), findsOneWidget);
    await tapText(tester, 'Répondre');
    // L'éditeur de la question tirée s'ouvre directement ; réponse privée par défaut, visibilité au choix.
    expect(find.text('Où aimeriez-vous vivre après le mariage ?'), findsWidgets);
    await tester.enterText(find.byType(TextField).last, 'À Conakry, près de nos familles.');
    await tapText(tester, 'Mes matchs');
    await tapText(tester, 'Enregistrer');
    await settle(tester);
    expect(find.text('À Conakry, près de nos familles.'), findsOneWidget);
    expect(find.text('Mes matchs'), findsOneWidget, reason: 'visibilité affichée sur la réponse');
    await goBack(tester);

    // Défis : « Découvrez 5 profils » est réalisé en démo, on le valide une fois.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await settle(tester);
    expect(find.text('Découvrez 5 profils'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Valider').last);
    await settle(tester);
    expect(find.text('Validé'), findsWidgets);

    // Pulse : désactivé par défaut ; une fois accepté, les nouveaux membres apparaissent.
    await tapText(tester, 'Pulse');
    expect(find.textContaining('Désactivé par défaut'), findsOneWidget);
    expect(find.textContaining('Aucun nouveau membre vérifié'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await settle(tester);
    expect(find.textContaining('Aucun nouveau membre vérifié'), findsNothing);
    expect(find.text('Conakry — Ratoma'), findsWidgets, reason: 'chiffres réels par ville');
    await goBack(tester);

    // Invitation : code personnel affiché, conditions expliquées, aucune récompense promise tant qu'elle n'est pas fixée.
    await tapText(tester, 'Inviter un proche');
    expect(find.text('DEMO1A2B3C'), findsOneWidget);
    expect(find.textContaining('Les récompenses ne sont pas encore ouvertes'), findsOneWidget);
  });

  testWidgets('Messagerie : une demande d’argent par Mobile Money affiche un avertissement', (tester) async {
    usePhoneScreen(tester);
    SharedPreferences.setMockInitialValues(draftAtHorizonStep());
    await tester.pumpWidget(ZayaApp(repository: DemoRepository()));
    await settle(tester);
    await finishOnboarding(tester);
    await tapText(tester, 'Messages');
    await tapText(tester, 'Thierno');
    await tester.enterText(find.byType(TextField), 'Tu as un compte Orange Money ?');
    await tester.pump();
    await tester.tap(find.byTooltip('Envoyer'));
    await settle(tester);
    expect(find.text('Tu as un compte Orange Money ?'), findsOneWidget, reason: 'le message passe');
    expect(find.textContaining('n’envoyez jamais d’argent par Mobile Money'), findsOneWidget);
  });
}
