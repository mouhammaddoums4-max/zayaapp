import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zaya/features/shop/shop_screen.dart';
import 'package:zaya/features/shop/shop_service.dart';

const _rose = ShopItem(id: 'r', code: 'rose', kind: 'gift', nameFr: 'Rose', emoji: '🌹', priceCoins: 10);
const _ring = ShopItem(id: 'b', code: 'bague', kind: 'gift', nameFr: 'Bague', emoji: '💍', rarity: 'legendary');
const _smile = ShopItem(
    id: 's',
    code: 'sourire',
    kind: 'compliment',
    nameFr: 'Ton sourire',
    emoji: '😊',
    messageFr: 'Ton sourire donne envie de mieux te connaître.',
    priceCoins: 5);

/// Serveur simulé : solde et refus décidés ici, comme send_shop_item.
class _FakeShop implements ShopService {
  int coins = 12;
  final sent = <String>[];

  @override
  Future<ShopCatalog> catalog() async => ShopCatalog(enabled: true, coins: coins, items: const [_rose, _ring, _smile]);

  @override
  Future<int> send(ShopItem item, String toUserId) async {
    if (coins < item.priceCoins!) throw Exception('INSUFFICIENT_COINS');
    coins -= item.priceCoins!;
    sent.add('${item.code}>$toUserId');
    return coins;
  }

  @override
  Future<List<ShopHistoryEntry>> history({bool sent = false}) async => sent
      ? const []
      : [ShopHistoryEntry(item: _smile, otherId: 'u2', otherName: 'Aïcha', at: DateTime(2026, 11, 25))];
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

  testWidgets('consultation : solde en pièces achetées, prix fixés par l’équipe, « Bientôt » sans prix', (tester) async {
    final shop = _FakeShop();
    await tester.pumpWidget(MaterialApp(home: ShopScreen(service: shop)));
    await tester.pumpAndSettle();
    expect(find.text('Solde : 12 pièces'), findsOneWidget);
    expect(find.text('L’achat de pièces n’est pas encore ouvert.'), findsOneWidget);
    expect(find.text('10 pièces'), findsOneWidget);
    expect(find.text('Bientôt'), findsOneWidget);
    await tester.tap(find.text('Rose'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ouvrez le profil d’un membre'), findsOneWidget, reason: 'aucun destinataire choisi');
    expect(shop.sent, isEmpty);
  });

  testWidgets('offrir : confirmation avec le prix, envoi, nouveau solde ; refus si solde insuffisant', (tester) async {
    final shop = _FakeShop();
    await tester.pumpWidget(
        MaterialApp(home: ShopScreen(service: shop, recipientId: 'u2', recipientName: 'Aïcha')));
    await tester.pumpAndSettle();
    expect(find.text('Offrir à Aïcha'), findsOneWidget);
    await tester.tap(find.text('Rose'));
    await tester.pumpAndSettle();
    expect(find.text('Offrir « Rose » à Aïcha ?'), findsOneWidget);
    expect(find.textContaining('10 pièces seront débitées'), findsOneWidget);
    await tester.tap(find.text('Offrir'));
    await tester.pumpAndSettle();
    expect(shop.sent, ['rose>u2']);
    expect(find.text('Solde : 2 pièces'), findsOneWidget);

    await tester.tap(find.text('Rose'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Offrir'));
    await tester.pumpAndSettle();
    expect(find.text('Solde de pièces insuffisant.'), findsOneWidget);
    expect(shop.sent, hasLength(1));

    await tester.tap(find.text('Compliments'));
    await tester.pumpAndSettle();
    expect(find.text('« Ton sourire donne envie de mieux te connaître. »'), findsOneWidget);
  });

  testWidgets('mes cadeaux : reçus avec l’expéditeur', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ShopHistoryScreen(service: _FakeShop())));
    await tester.pumpAndSettle();
    expect(find.text('Ton sourire'), findsOneWidget);
    expect(find.textContaining('De Aïcha'), findsOneWidget);
    await tester.tap(find.text('Envoyés'));
    await tester.pumpAndSettle();
    expect(find.text('Aucun cadeau pour le moment.'), findsOneWidget);
  });
}
