import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zaya/app.dart';
import 'package:zaya/data/demo_repository.dart';

import 'app_flow_test.dart' show draftAtHorizonStep, finishOnboarding, settle, tapText, usePhoneScreen;

/// Messagerie : réactions, réponse citée (démo, sans réseau). Le repère « Messages non lus » n’est pas couvert ici.
void main() {
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

  testWidgets('Réagir, répondre à un message et retrouver la citation', (tester) async {
    usePhoneScreen(tester);
    SharedPreferences.setMockInitialValues(draftAtHorizonStep());
    await tester.pumpWidget(ZayaApp(repository: DemoRepository()));
    await settle(tester);
    await finishOnboarding(tester);
    await tapText(tester, 'Messages');
    await tapText(tester, 'Thierno');

    // Les messages de départ sont déjà lus par la démo ? Le repère n'apparaît que s'il y a du non lu.
    expect(find.text('Très bien, merci. Si tu veux, voici mon numéro :'), findsNothing);

    // Appui long : les six réactions, Répondre et Copier sont proposés.
    await tester.longPress(find.textContaining('Heureux de ce match'));
    await settle(tester);
    for (final emoji in ['❤️', '😂', '😮', '😢', '🙏', '👍']) {
      expect(find.text(emoji), findsOneWidget, reason: emoji);
    }
    expect(find.text('Répondre'), findsOneWidget);
    expect(find.text('Copier'), findsOneWidget);

    // Réaction « 👍 » : une pastille apparaît sous la bulle ; un second appui sur la pastille la retire.
    await tester.tap(find.text('👍'));
    await settle(tester);
    expect(find.text('👍'), findsOneWidget, reason: 'pastille de réaction');
    await tester.tap(find.text('👍'));
    await settle(tester);
    expect(find.text('👍'), findsNothing);

    // Double appui : ❤️ direct.
    await tester.tap(find.textContaining('Heureux de ce match'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.textContaining('Heureux de ce match'));
    await settle(tester);
    expect(find.text('❤️'), findsOneWidget);

    // Répondre : bandeau au-dessus du champ, puis citation dans la bulle envoyée.
    await tester.longPress(find.textContaining('Heureux de ce match'));
    await settle(tester);
    await tester.tap(find.text('Répondre'));
    await settle(tester);
    expect(find.textContaining('Réponse à'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Merci, avec plaisir !');
    await tester.pump();
    await tester.tap(find.byTooltip('Envoyer'));
    await settle(tester);
    expect(find.textContaining('Réponse à'), findsNothing, reason: 'le bandeau disparaît après l’envoi');
    expect(find.text('Merci, avec plaisir !'), findsOneWidget);
    // La citation reprend le message d'origine (une fois dans le fil, une fois dans la citation).
    expect(find.textContaining('Heureux de ce match'), findsNWidgets(2));
  });
}
