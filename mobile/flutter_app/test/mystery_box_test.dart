import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zaya/features/ads/rewarded_ads.dart';
import 'package:zaya/features/mystery/mystery_box_screen.dart';
import 'package:zaya/features/mystery/mystery_box_service.dart';
import 'package:zaya/features/wallet/wallet_screen.dart';

const _prizes = [
  MysteryPrize(
      code: 'swipes_20',
      kind: 'extra_swipes',
      amount: 20,
      labelFr: '20 swipes supplémentaires',
      labelEn: '20 extra swipes',
      probabilityPercent: 65),
  MysteryPrize(
      code: 'swipes_50',
      kind: 'extra_swipes',
      amount: 50,
      labelFr: '50 swipes supplémentaires',
      labelEn: '50 extra swipes',
      probabilityPercent: 30),
  MysteryPrize(
      code: 'premium_7',
      kind: 'premium_days',
      amount: 7,
      labelFr: '7 jours de Premium Étincelle',
      labelEn: '7 days of Premium Spark',
      probabilityPercent: 5),
];

/// Serveur simulé : le tirage est imposé par le test ; un second appel renvoie le même lot, comme open_mystery_box.
class _FakeBox implements MysteryBoxService {
  _FakeBox({this.opened = false});
  bool opened;
  int openCalls = 0;
  static const _won = MysteryPrize(
      code: 'swipes_50', kind: 'extra_swipes', amount: 50, labelFr: '50 swipes supplémentaires', labelEn: '50 extra swipes');

  MysteryBoxState get _state => MysteryBoxState(
      enabled: true, eligible: true, opened: opened, prize: opened ? _won : null, prizes: opened ? const [] : _prizes);

  @override
  Future<MysteryBoxState> status() async => _state;

  @override
  Future<MysteryBoxState> open() async {
    openCalls++;
    opened = true;
    return _state;
  }
}

class _FakeRewards implements RewardsService {
  _FakeRewards(this.walletValue);
  final Wallet walletValue;
  @override
  Future<RewardOffer> offer(String reward) async => const RewardOffer.none();
  @override
  Future<Wallet> wallet() async => walletValue;
  @override
  Future<bool> showRewardedAd(String reward) async => false;
  @override
  Future<bool> waitForCredit(String reward, {required int remainingBefore, Duration timeout = Duration.zero}) async =>
      false;
}

/// La boîte flotte en continu (pumpAndSettle ne finirait jamais) : on avance l'horloge image par image.
Future<void> _advance(WidgetTester tester, [int frames = 40]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
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

  test('lecture de mystery_box_status : lots, chances et lot obtenu', () {
    final st = MysteryBoxState.fromJson({
      'enabled': true,
      'eligible': true,
      'opened': false,
      'prize': null,
      'prizes': [
        {'code': 'swipes_20', 'kind': 'extra_swipes', 'amount': 20, 'label_fr': '20 swipes', 'label_en': '20 swipes',
         'probability_percent': 65.0},
      ],
    });
    expect(st.available, isTrue);
    expect(st.prizes.single.probabilityPercent, 65);
    final opened = MysteryBoxState.fromJson({
      'enabled': true,
      'eligible': true,
      'opened': true,
      'status': 'already_opened',
      'prize': {'code': 'premium_7', 'kind': 'premium_days', 'amount': 7, 'label_fr': '7 jours', 'label_en': '7 days'},
      'prizes': const [],
    });
    expect(opened.available, isFalse);
    expect(opened.prize!.label('en'), '7 days');
    expect(const MysteryBoxState().available, isFalse, reason: 'mode démo ou réglage désactivé : aucune boîte');
  });

  testWidgets('chances réelles affichées avant l’ouverture ; ouverture unique ; lot révélé', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final box = _FakeBox();
    await tester.pumpWidget(MaterialApp(home: MysteryBoxScreen(service: box)));
    await _advance(tester, 5);
    expect(find.text('Votre boîte mystère de bienvenue'), findsOneWidget);
    expect(find.text('20 swipes supplémentaires : 65 %'), findsOneWidget);
    expect(find.text('50 swipes supplémentaires : 30 %'), findsOneWidget);
    expect(find.text('7 jours de Premium Étincelle : 5 %'), findsOneWidget);

    // Deux appuis rapprochés : un seul appel au serveur.
    await tester.tap(find.text('Ouvrir ma boîte'));
    await tester.tap(find.text('Ouvrir ma boîte'), warnIfMissed: false);
    await _advance(tester);
    expect(box.openCalls, 1);
    expect(find.text('Vous avez gagné'), findsOneWidget);
    expect(find.text('50 swipes supplémentaires'), findsOneWidget);
    expect(find.textContaining('C’est déjà ajouté à votre compte'), findsOneWidget);
    expect(find.text('Ouvrir ma boîte'), findsNothing, reason: 'plus de bouton : la boîte est ouverte');
    expect(find.text('Votre boîte est déjà ouverte.'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('boîte déjà ouverte : le même lot, sans bouton d’ouverture', (tester) async {
    final box = _FakeBox(opened: true);
    await tester.pumpWidget(MaterialApp(home: MysteryBoxScreen(service: box)));
    await _advance(tester, 20);
    expect(find.text('Votre boîte est déjà ouverte.'), findsOneWidget);
    expect(find.text('50 swipes supplémentaires'), findsOneWidget);
    expect(find.text('Ouvrir ma boîte'), findsNothing);
    expect(box.openCalls, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('portefeuille : accès à la boîte tant qu’elle est fermée, cadeaux dans leur propre catégorie',
      (tester) async {
    final box = _FakeBox();
    final rewards = _FakeRewards(Wallet(
      bonusSwipes: 50,
      history: [
        WalletEntry(
            category: 'bonus', asset: 'swipes', amount: 50, reason: 'Boîte mystère de bienvenue', at: DateTime(2026, 11, 18)),
      ],
    ));
    await tester.pumpWidget(MaterialApp(home: WalletScreen(service: rewards, mystery: box)));
    await tester.pumpAndSettle();
    expect(find.text('Un cadeau vous attend'), findsOneWidget);
    expect(find.text('Cadeaux ZAYA'), findsOneWidget);
    expect(find.text('50 swipes supplémentaires gagnés'), findsOneWidget);
    expect(find.byIcon(Icons.card_giftcard), findsWidgets);

    await tester.tap(find.text('Un cadeau vous attend'));
    await _advance(tester, 20);
    expect(find.text('Ouvrir ma boîte'), findsOneWidget);
    await tester.tap(find.text('Ouvrir ma boîte'));
    await _advance(tester);
    await tester.tap(find.text('Continuer'));
    await _advance(tester, 20);
    expect(find.text('Un cadeau vous attend'), findsNothing, reason: 'boîte ouverte : le raccourci disparaît');
    await tester.pumpWidget(const SizedBox());
  });
}
