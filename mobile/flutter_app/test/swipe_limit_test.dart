import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zaya/features/discovery/swipe_limit_screen.dart';

/// Écran de limite de swipes (0016) : compte à rebours réel jusqu'à la reprise, accès à Premium.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false; // polices embarquées : aucun accès réseau
    await GoogleFonts.pendingFonts([
      GoogleFonts.sora(fontWeight: FontWeight.w600),
      GoogleFonts.sora(fontWeight: FontWeight.w700),
      GoogleFonts.inter(),
      GoogleFonts.inter(fontWeight: FontWeight.w500),
      GoogleFonts.inter(fontWeight: FontWeight.w600),
      GoogleFonts.inter(fontWeight: FontWeight.w700),
    ]);
  });

  testWidgets('quota atteint : temps restant au format hh:mm:ss et offre Premium', (tester) async {
    final reprise = DateTime.now().add(const Duration(hours: 7, minutes: 59, seconds: 30));
    await tester.pumpWidget(MaterialApp(home: SwipeLimitScreen(resetsAt: reprise)));
    await tester.pump();
    expect(find.text('Vous avez utilisé tous vos swipes'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^07:59:[0-5]\d$')), findsOneWidget);
    expect(find.text('Découvrir ZAYA Premium'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2)); // le compte à rebours avance sans erreur
  });

  testWidgets('reprise atteinte : les swipes sont de retour', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SwipeLimitScreen(resetsAt: DateTime.now().subtract(const Duration(seconds: 1))),
    ));
    await tester.pump();
    expect(find.text('Vos swipes sont de retour'), findsOneWidget);
    expect(find.text('Reprendre'), findsOneWidget);
    expect(find.text('Découvrir ZAYA Premium'), findsNothing);
  });
}
