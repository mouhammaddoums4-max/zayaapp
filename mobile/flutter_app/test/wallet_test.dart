import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zaya/features/ads/rewarded_ad_button.dart';
import 'package:zaya/features/ads/rewarded_ads.dart';
import 'package:zaya/features/mystery/mystery_box_service.dart';
import 'package:zaya/features/wallet/wallet_screen.dart';

/// Régie simulée : offre et portefeuille imposés par le test ; aucune vraie publicité.
class _FakeRewards implements RewardsService {
  _FakeRewards({required this.offerValue, this.walletValue = const Wallet()});
  RewardOffer offerValue;
  final Wallet walletValue;
  final bool watchResult = true;
  int shown = 0;

  @override
  Future<RewardOffer> offer(String reward) async => offerValue;
  @override
  Future<Wallet> wallet() async => walletValue;
  @override
  Future<bool> showRewardedAd(String reward) async {
    shown++;
    return watchResult;
  }

  @override
  Future<bool> waitForCredit(String reward, {required int remainingBefore, Duration timeout = Duration.zero}) async {
    offerValue = RewardOffer(
        available: true,
        amount: offerValue.amount,
        remainingToday: remainingBefore - 1,
        labelFr: offerValue.labelFr,
        labelEn: offerValue.labelEn);
    return true;
  }
}

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

  Widget host(Widget child) => MaterialApp(home: Scaffold(body: ListView(children: [child])));

  testWidgets('pas d’offre (AdMob désactivé, limite atteinte) : aucun bouton', (tester) async {
    await tester.pumpWidget(host(RewardedAdButton(
        reward: 'extra_swipes', onCredited: (_) {}, service: _FakeRewards(offerValue: const RewardOffer.none()))));
    await tester.pumpAndSettle();
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('offre : récompense annoncée, confirmation demandée, crédit après vérification', (tester) async {
    final fake = _FakeRewards(
        offerValue:
            const RewardOffer(available: true, amount: 10, remainingToday: 3, labelFr: 'Swipes supplémentaires'));
    int? credited;
    await tester
        .pumpWidget(host(RewardedAdButton(reward: 'extra_swipes', onCredited: (n) => credited = n, service: fake)));
    await tester.pumpAndSettle();
    expect(find.text('Regarder une publicité : Swipes supplémentaires +10'), findsOneWidget);
    expect(find.text('encore 3 aujourd’hui'), findsOneWidget);

    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();
    expect(find.text('Regarder une publicité ?'), findsOneWidget, reason: 'consentement avant chaque publicité');
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(fake.shown, 0, reason: 'refus : aucune publicité affichée');

    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Regarder'));
    await tester.pumpAndSettle();
    expect(fake.shown, 1);
    expect(credited, 10);
    expect(find.text('encore 2 aujourd’hui'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('portefeuille : trois catégories séparées et historique', (tester) async {
    final fake = _FakeRewards(
      offerValue: const RewardOffer.none(),
      walletValue: Wallet(
        adSwipes: 20,
        coins: 0,
        history: [
          WalletEntry(
              category: 'ad_credit',
              asset: 'swipes',
              amount: 10,
              reason: 'Publicité récompensée',
              at: DateTime(2026, 11, 18))
        ],
      ),
    );
    await tester.pumpWidget(MaterialApp(home: WalletScreen(service: fake, mystery: const NoMysteryBox())));
    await tester.pumpAndSettle();
    expect(find.text('Crédits publicitaires'), findsOneWidget);
    expect(find.text('20 swipes supplémentaires gagnés'), findsOneWidget);
    expect(find.text('Pièces'), findsOneWidget);
    expect(find.text('Solde : 0 pièces'), findsOneWidget);
    expect(find.text('Offre Gratuit'), findsOneWidget);
    expect(find.text('Publicité récompensée'), findsOneWidget);
    expect(find.text('+10'), findsOneWidget);
  });
}
