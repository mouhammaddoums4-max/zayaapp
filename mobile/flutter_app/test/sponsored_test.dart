import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zaya/features/ads/ads_service.dart';
import 'package:zaya/features/ads/sponsored_card.dart';

/// Régie simulée : renvoie les campagnes données et note les affichages et clics signalés.
class _FakeAds implements AdsService {
  _FakeAds(this.ads);
  final List<SponsoredAd> ads;
  final impressions = <String>[];
  final clicks = <String>[];

  @override
  Future<List<SponsoredAd>> sponsored(String placement, {int limit = 1}) async => ads;
  @override
  Future<void> recordImpression(String campaignId, String placement) async => impressions.add('$campaignId@$placement');
  @override
  Future<bool> recordClick(String campaignId, String placement) async {
    clicks.add(campaignId);
    return true;
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Polices embarquées chargées d'avance, comme dans app_flow_test.dart.
    GoogleFonts.config.allowRuntimeFetching = false;
    await GoogleFonts.pendingFonts([
      GoogleFonts.inter(),
      GoogleFonts.inter(fontWeight: FontWeight.w600),
      GoogleFonts.inter(fontWeight: FontWeight.w700),
      GoogleFonts.sora(fontWeight: FontWeight.w600),
      GoogleFonts.sora(fontWeight: FontWeight.w700),
    ]);
  });

  Widget host(Widget child) => MaterialApp(home: Scaffold(body: ListView(children: [child])));

  testWidgets('une campagne : « Sponsorisé », annonceur, texte ; affichage signalé une seule fois', (tester) async {
    final ads = _FakeAds(const [
      SponsoredAd(
        campaignId: 'c1',
        advertiserName: 'Boutique fictive',
        headline: 'Tenues de cérémonie',
        body: 'Collection mariage 2027.',
        ctaLabel: 'Voir la collection',
        destinationUrl: 'https://exemple.test/collection',
      ),
    ]);
    await tester.pumpWidget(host(SponsoredSlot(placement: 'profile', service: ads)));
    await tester.pumpAndSettle();
    expect(find.text('Sponsorisé'), findsOneWidget);
    expect(find.text('Boutique fictive'), findsOneWidget);
    expect(find.text('Tenues de cérémonie'), findsOneWidget);
    expect(find.text('Voir la collection'), findsOneWidget);
    expect(ads.impressions, ['c1@profile']);
    await tester.pump();
    expect(ads.impressions, hasLength(1), reason: 'un affichage par apparition, pas par image');
  });

  testWidgets('aucune campagne : l’emplacement ne prend aucune place', (tester) async {
    await tester.pumpWidget(host(SponsoredSlot(placement: 'profile', service: _FakeAds(const []))));
    await tester.pumpAndSettle();
    expect(find.text('Sponsorisé'), findsNothing);
    expect(find.byType(SponsoredCard), findsNothing, reason: 'aucune carte, aucune place prise');
  });

  test('mode démo : aucune publicité', () async {
    expect(await const NoAdsService().sponsored('community_feed'), isEmpty);
  });
}
