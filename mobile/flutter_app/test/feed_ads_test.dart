import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zaya/features/ads/ad_settings.dart';
import 'package:zaya/features/ads/ads_service.dart';
import 'package:zaya/features/ads/feed_ads.dart';
import 'package:zaya/features/ads/google_ads.dart';
import 'package:zaya/features/ads/sponsored_card.dart';

/// Régie simulée : campagnes directes imposées par le test ; affichages notés.
class _FakeAds implements AdsService {
  _FakeAds(this.ads);
  final List<SponsoredAd> ads;
  final impressions = <String>[];
  int calls = 0;

  @override
  Future<List<SponsoredAd>> sponsored(String placement, {int limit = 1}) async {
    calls++;
    return ads;
  }

  @override
  Future<void> recordImpression(String campaignId, String placement) async => impressions.add('$campaignId@$placement');
  @override
  Future<bool> recordClick(String campaignId, String placement) async => true;
}

const _campaign = SponsoredAd(campaignId: 'c1', advertiserName: 'Traiteur fictif', headline: 'Repas de mariage');

AdSettings _settings({bool direct = true, bool admob = true, int every = 3}) => AdSettings.fromJson({
      'direct': direct,
      'admob': admob,
      'community_every': every,
      'explore_every': every,
      'banner_placements': ['community', 'profile'],
      'banner_unit_android': 'ca-app-pub-test/banner',
      'interstitial_unit_android': 'ca-app-pub-test/inter',
      'interstitial_every_swipes': 12,
      'interstitial_min_minutes': 5,
    });

/// À la place du SDK Google (absent des tests) : un simple repère.
Widget _fakeGoogle(AdSettings s, String placement) => Text('GOOGLE:$placement');

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
    await GoogleFonts.pendingFonts([
      GoogleFonts.inter(),
      GoogleFonts.inter(fontWeight: FontWeight.w600),
      GoogleFonts.inter(fontWeight: FontWeight.w700),
      GoogleFonts.sora(fontWeight: FontWeight.w600),
      GoogleFonts.sora(fontWeight: FontWeight.w700),
    ]);
  });

  test('réglages du serveur : emplacements autorisés, rythme, désactivation', () {
    final s = _settings();
    expect(s.bannerAllowed('community'), isTrue);
    expect(s.bannerAllowed('explore'), isFalse, reason: 'emplacement non listé par le serveur');
    expect(s.everyFor('community_feed'), 3);
    expect(s.interstitialEnabled, isTrue);
    expect(AdSettings.disabled.everyFor('community_feed'), 0);
    expect(AdSettings.disabled.bannerAllowed('community'), isFalse);
    expect(const AdSettings(admob: true, bannerPlacements: {'community'}).bannerAllowed('community'), isFalse,
        reason: 'sans identifiant de bloc, aucune bannière');
  });

  test('interstitiel : après N swipes et jamais deux fois en moins de M minutes', () {
    const rule = InterstitialRule(everySwipes: 12, minMinutes: 5);
    final now = DateTime(2026, 11, 24, 12);
    expect(rule.shouldShow(swipesSinceLast: 11, lastShown: null, now: now), isFalse);
    expect(rule.shouldShow(swipesSinceLast: 12, lastShown: null, now: now), isTrue);
    expect(rule.shouldShow(swipesSinceLast: 30, lastShown: now.subtract(const Duration(minutes: 2)), now: now), isFalse);
    expect(rule.shouldShow(swipesSinceLast: 12, lastShown: now.subtract(const Duration(minutes: 6)), now: now), isTrue);
    expect(const InterstitialRule(everySwipes: 0, minMinutes: 1).shouldShow(swipesSinceLast: 99, lastShown: null, now: now),
        isFalse);
  });

  test('fil : campagnes directes d’abord, puis Google ; rien si tout est éteint', () async {
    final feed = FeedAds(feed: 'community_feed', ads: _FakeAds(const [_campaign]), settings: () async => _settings());
    await feed.load();
    expect(feed.slotAfter(1), isNull);
    expect(feed.slotAfter(2), 0, reason: 'après la 3e publication : la campagne directe');
    expect(feed.slotAfter(5), 1, reason: 'après la 6e : une bannière Google');

    final noGoogle = FeedAds(
        feed: 'community_feed', ads: _FakeAds(const [_campaign]), settings: () async => _settings(admob: false));
    await noGoogle.load();
    expect(noGoogle.slotAfter(2), 0);
    expect(noGoogle.slotAfter(5), isNull, reason: 'pas de cadre vide quand Google est désactivé');

    final ads = _FakeAds(const [_campaign]);
    final off = FeedAds(feed: 'community_feed', ads: ads, settings: () async => AdSettings.disabled);
    await off.load();
    expect(off.slotAfter(2), isNull);
    expect(ads.calls, 0, reason: 'régie éteinte : aucune requête de campagne');
  });

  testWidgets('emplacements du fil : carte « Sponsorisé » comptée une fois, puis bannière Google', (tester) async {
    final service = _FakeAds(const [_campaign]);
    final feed = FeedAds(
        feed: 'community_feed', ads: service, settings: () async => _settings(), googleBuilder: _fakeGoogle);
    await feed.load();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(children: [FeedAdSlot(ads: feed, slot: 0), FeedAdSlot(ads: feed, slot: 1)]),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Sponsorisé'), findsOneWidget);
    expect(find.text('Traiteur fictif'), findsOneWidget);
    expect(find.text('GOOGLE:community'), findsOneWidget);
    expect(service.impressions, ['c1@community_feed']);
    await tester.pump();
    expect(service.impressions, hasLength(1));
  });

  testWidgets('emplacement du profil : Google en repli seulement sans campagne directe', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(children: [
          SponsoredSlot(
            placement: 'profile',
            service: _FakeAds(const []),
            settings: () async => _settings(),
            googleBuilder: _fakeGoogle,
          ),
        ]),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('GOOGLE:profile'), findsOneWidget);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(children: [
          SponsoredSlot(
            key: const ValueKey<String>('avec-campagne'),
            placement: 'profile',
            service: _FakeAds(const [_campaign]),
            settings: () async => _settings(),
            googleBuilder: _fakeGoogle,
          ),
        ]),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Sponsorisé'), findsOneWidget);
    expect(find.textContaining('GOOGLE'), findsNothing, reason: 'la campagne directe passe avant Google');
  });

  testWidgets('cadre Google : toujours marqué « Publicité »', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AdFrame(child: SizedBox(width: 300, height: 250)))));
    expect(find.text('Publicité'), findsOneWidget);
  });
}
