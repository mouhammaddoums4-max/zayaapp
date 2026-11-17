import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zaya/data/models.dart';
import 'package:zaya/features/discovery/photo_viewer.dart';
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

  testWidgets('libellés honnêtes ; une photo nette ou floutée s’ouvre en grand, jamais une photo privée', (tester) async {
    final ouvertes = <String>[];
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
          onOpen: (p) => ouvertes.add(p.id),
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('Premium'), findsOneWidget, reason: 'floutée par le forfait');
    expect(find.text('Floutée'), findsOneWidget, reason: 'floutée par la propriétaire : Premium ne la rend pas nette');
    expect(find.text('Privée'), findsOneWidget);

    await tester.tap(find.text('Premium'));
    await tester.tap(find.text('Floutée'));
    await tester.tap(find.text('Privée'), warnIfMissed: false);
    expect(ouvertes, ['b', 'c'], reason: 'la photo privée ne doit pas s’ouvrir');
  });

  test('la visionneuse ne montre jamais les photos privées', () {
    const photos = [
      ProfilePhoto(id: 'a', visibility: 'public', access: 'original'),
      ProfilePhoto(id: 'd', visibility: 'private', access: 'none'),
      ProfilePhoto(id: 'b', visibility: 'public', access: 'blurred'),
    ];
    expect(PhotoViewerScreen.viewable(photos).map((p) => p.id), ['a', 'b']);
  });
}
