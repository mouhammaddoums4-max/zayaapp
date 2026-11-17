import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zaya/data/models.dart';
import 'package:zaya/features/discovery/profile_widgets.dart';

/// Galerie de la fiche profil : libellés honnêtes selon la raison du floutage (addendum V6.4 §2.2 et §3).
/// Photos sans chemin : la galerie s'affiche seule, sans session ni téléchargement.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Polices embarquées, chargées avant le test (sinon leur chargement relance un affichage après la fin).
    GoogleFonts.config.allowRuntimeFetching = false;
    await GoogleFonts.pendingFonts([
      GoogleFonts.inter(fontWeight: FontWeight.w700),
      GoogleFonts.sora(fontWeight: FontWeight.w700),
    ]);
  });

  testWidgets('photo floutée par le forfait : « Premium » et ouverture de l’offre ; floutée par la propriétaire : pas d’offre',
      (tester) async {
    var ouvertures = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProfilePhotoGallery(
          name: 'Mariama',
          photos: const [
            ProfilePhoto(id: 'a', visibility: 'public', access: 'original'),
            ProfilePhoto(id: 'b', visibility: 'public', access: 'blurred'),
            ProfilePhoto(id: 'c', visibility: 'blurred', access: 'blurred'),
            ProfilePhoto(id: 'd', visibility: 'private', access: 'none'),
          ],
          onUnlock: () => ouvertures++,
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('Premium'), findsOneWidget);
    expect(find.text('Floutée'), findsOneWidget);
    expect(find.text('Privée'), findsOneWidget);

    await tester.tap(find.text('Premium'));
    expect(ouvertures, 1);
    await tester.tap(find.text('Floutée'), warnIfMissed: false);
    await tester.tap(find.text('Privée'), warnIfMissed: false);
    expect(ouvertures, 1, reason: 'une photo protégée par sa propriétaire ne doit pas mener à l’offre Premium');
  });
}
