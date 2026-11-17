import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zaya/app.dart';
import 'package:zaya/data/demo_repository.dart';

/// Parcours complets à l'écran, en mode démo, sur un petit téléphone Android (360 × 640 dp).
/// Tout débordement d'affichage ou toute exception pendant une animation fait échouer le test.

const _draftKey = 'zaya_onboarding_draft';

void usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(720, 1280);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
}

Future<void> settle(WidgetTester tester) => tester.pumpAndSettle(
    const Duration(milliseconds: 40), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 20));

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  expect(finder, findsWidgets, reason: 'Texte introuvable à l’écran : « $text »');
  await tester.ensureVisible(finder.first);
  await tester.pump();
  await tester.tap(finder.first);
  await settle(tester);
}

/// Brouillon d'inscription déjà rempli jusqu'à l'étape « Projet de mariage » (index 5) :
/// vérifie au passage la reprise après interruption.
Map<String, Object> draftAtHorizonStep({String gender = 'femme'}) => {
      _draftKey: jsonEncode({
        'adultConfirmed': true,
        'displayName': 'Awa',
        'birthDate': DateTime(1998, 5, 10).toIso8601String(),
        'gender': gender,
        'cityId': 4,
        'step': 5,
      }),
    };

/// Termine l'inscription à partir de l'étape « Projet de mariage » et arrive sur l'application.
Future<void> finishOnboarding(WidgetTester tester) async {
  await tapText(tester, 'Créer mon profil');
  expect(find.text('Étape 6 sur 12'), findsOneWidget, reason: 'Le brouillon doit reprendre à l’étape enregistrée');
  await tapText(tester, 'Bientôt');
  await tapText(tester, 'Continuer');
  expect(find.text('Votre situation matrimoniale'), findsOneWidget);
  await tapText(tester, 'Passer cette étape');
  expect(find.text('Votre confession'), findsOneWidget);
  await tapText(tester, 'Passer cette étape');
  expect(find.text('Qui souhaitez-vous découvrir ?'), findsOneWidget);
  await tapText(tester, 'Continuer');
  expect(find.text('Quelques mots sur vous'), findsOneWidget);
  await tapText(tester, 'Passer cette étape');

  // Vérification du téléphone
  expect(find.text('Vérifiez votre numéro'), findsOneWidget);
  await tester.enterText(find.byType(TextField).first, '622112233');
  await tester.pump();
  await tapText(tester, 'Recevoir le code');
  await tester.enterText(find.byType(TextField).last, DemoRepository.demoOtp);
  await tester.pump();
  await tapText(tester, 'Vérifier');

  // Règles et consentements : impossible d'entrer sans accepter
  expect(find.text('Les règles de ZAYA'), findsOneWidget);
  await tester.ensureVisible(find.byType(CheckboxListTile).first);
  await tester.tap(find.byType(CheckboxListTile).first);
  await settle(tester);
  await tapText(tester, 'Entrer sur ZAYA');
}

/// Retour à l'écran précédent par le bouton de la barre supérieure.
Future<void> goBack(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Retour').last);
  await settle(tester);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Les polices sont embarquées : aucun accès réseau ne doit être tenté. Elles sont chargées avant
    // les tests pour mesurer les écrans avec les vraies polices, comme sur un téléphone.
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

  testWidgets('Accueil puis premières étapes : majorité, prénom, retour arrière', (tester) async {
    usePhoneScreen(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(ZayaApp(repository: DemoRepository()));
    await settle(tester);

    expect(find.text('Créer mon profil'), findsOneWidget);
    expect(find.text('Mode démo'), findsOneWidget);
    expect(find.textContaining('18 ans et plus'), findsOneWidget);

    await tapText(tester, 'Créer mon profil');
    expect(find.text('Étape 1 sur 12'), findsOneWidget);

    // Le bouton reste inactif tant que la majorité n'est pas confirmée.
    await tester.tap(find.text('Continuer'));
    await settle(tester);
    expect(find.text('Étape 1 sur 12'), findsOneWidget);

    await tapText(tester, 'J’ai 18 ans ou plus');
    await tapText(tester, 'Continuer');
    expect(find.text('Comment vous appelez-vous ?'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Awa');
    await tester.pump();
    await tapText(tester, 'Continuer');
    expect(find.text('Quelle est votre date de naissance ?'), findsOneWidget);

    // Sans date de naissance, on ne peut pas continuer.
    await tester.tap(find.text('Continuer'));
    await settle(tester);
    expect(find.text('Étape 3 sur 12'), findsOneWidget);

    // Retour arrière : l'étape précédente garde la saisie.
    await tester.tap(find.byTooltip('Retour'));
    await settle(tester);
    expect(find.text('Comment vous appelez-vous ?'), findsOneWidget);
    expect(find.text('Awa'), findsOneWidget);
  });

  testWidgets('Inscription reprise, like, match, messagerie sécurisée, confidentialité', (tester) async {
    usePhoneScreen(tester);
    SharedPreferences.setMockInitialValues(draftAtHorizonStep());
    await tester.pumpWidget(ZayaApp(repository: DemoRepository()));
    await settle(tester);
    await finishOnboarding(tester);

    // ── Découvrir : première carte, profil non encore vérifié signalé
    expect(find.textContaining('Ibrahima, 30'), findsWidgets);
    expect(find.textContaining('n’est pas encore visible'), findsOneWidget);

    // Like simple : pas de match, carte suivante
    await tester.tap(find.bySemanticsLabel('Aimer'));
    await settle(tester);
    expect(find.text('C’est un match !'), findsNothing);
    expect(find.textContaining('Mamadou, 33'), findsWidgets);

    // Like réciproque : écran de match
    await tester.tap(find.bySemanticsLabel('Aimer'));
    await settle(tester);
    expect(find.text('C’est un match !'), findsOneWidget);
    await tapText(tester, 'Continuer à découvrir');
    expect(find.text('C’est un match !'), findsNothing);

    // Passer un profil avec le bouton
    final cardBefore = find.textContaining('Alpha, 28');
    expect(cardBefore, findsWidgets);
    await tester.tap(find.bySemanticsLabel('Passer'));
    await settle(tester);
    expect(find.textContaining('Alpha, 28'), findsNothing);

    // ── Fiche profil depuis la carte, puis like depuis la fiche
    await tester.tap(find.bySemanticsLabel('Voir le profil'));
    await settle(tester);
    expect(find.text('Vérifications'), findsOneWidget);
    expect(find.text('J’aime ce profil'), findsOneWidget);
    await tapText(tester, 'J’aime ce profil');
    expect(find.text('Vérifications'), findsNothing);

    // ── Explorer
    await tapText(tester, 'Explorer');
    expect(find.text('Tous les profils'), findsOneWidget);

    // ── Likes : le compteur est gratuit, l'identité ne l'est pas
    await tapText(tester, 'Likes');
    expect(find.text('1 personne a aimé votre profil'), findsOneWidget);
    expect(find.text('Profil masqué'), findsOneWidget);

    // ── Messages : nouveau match + conversation avec numéro masqué dans l'aperçu
    await tapText(tester, 'Messages');
    expect(find.text('Nouveaux matchs'), findsOneWidget);
    expect(find.text('Mamadou'), findsOneWidget);
    expect(find.textContaining('+224 ••• •• •• ••'), findsOneWidget);
    expect(find.textContaining('622 11 22 33'), findsNothing);

    await tapText(tester, 'Thierno');
    expect(find.textContaining('contrôlés avant envoi'), findsOneWidget);
    // Le numéro reçu est masqué jusqu'à une action volontaire, précédée d'un avertissement.
    expect(find.textContaining('622 11 22 33', findRichText: true), findsNothing);
    await tester.tap(find.textContaining('· Afficher'));
    await settle(tester);
    expect(find.text('Votre sécurité est notre priorité'), findsOneWidget);
    await tapText(tester, 'Afficher le numéro');
    expect(find.textContaining('622 11 22 33', findRichText: true), findsOneWidget);

    // Message non conforme : bloqué avant envoi, reste dans le champ pour correction
    await tester.enterText(find.byType(TextField), "Envoie-moi de l'argent stp");
    await tester.pump();
    await tester.tap(find.byTooltip('Envoyer'));
    await settle(tester);
    expect(find.textContaining('n’a pas été envoyé'), findsOneWidget);
    expect(find.text("Envoie-moi de l'argent stp"), findsOneWidget);

    // Message conforme : envoyé
    await tester.enterText(find.byType(TextField), 'Bonjour Thierno !');
    await tester.pump();
    await tester.tap(find.byTooltip('Envoyer'));
    await settle(tester);
    expect(find.textContaining('n’a pas été envoyé'), findsNothing);
    expect(find.textContaining('Bonjour Thierno !', findRichText: true), findsOneWidget);

    // Bouclier de sécurité accessible depuis la conversation
    await tester.tap(find.byTooltip('Bouclier de sécurité'));
    await settle(tester);
    expect(find.text('Signaler Thierno'), findsOneWidget);
    expect(find.text('Bloquer Thierno'), findsOneWidget);
    expect(find.text('Mettre fin au match'), findsOneWidget);
    await tester.tapAt(const Offset(20, 20)); // ferme la feuille
    await settle(tester);

    await goBack(tester);

    // ── Profil → confidentialité : mise en pause
    await tapText(tester, 'Profil');
    expect(find.textContaining('Profil complété à'), findsOneWidget);
    await tester.tap(find.byTooltip('Confidentialité et sécurité'));
    await settle(tester);
    expect(find.text('Visibilité du profil'), findsOneWidget);
    await tapText(tester, 'En pause');
    await goBack(tester);

    await tapText(tester, 'Découvrir');
    expect(find.text('Votre profil est en pause'), findsOneWidget);
  });

  testWidgets('Animations réduites : le parcours fonctionne sans animation', (tester) async {
    usePhoneScreen(tester);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    SharedPreferences.setMockInitialValues(draftAtHorizonStep(gender: 'homme'));
    await tester.pumpWidget(ZayaApp(repository: DemoRepository()));
    await settle(tester);
    await finishOnboarding(tester);

    // Un homme se voit proposer des profils féminins.
    expect(find.textContaining('Aïssatou, 27'), findsWidgets);
    await tester.tap(find.bySemanticsLabel('Aimer'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Aimer'));
    await settle(tester);
    expect(find.text('C’est un match !'), findsOneWidget);
    await tapText(tester, 'Envoyer un message');
    // « Envoyer un message » ouvre directement la conversation du nouveau match.
    expect(find.textContaining('Dites bonjour à Kadiatou'), findsOneWidget);
  });
}
