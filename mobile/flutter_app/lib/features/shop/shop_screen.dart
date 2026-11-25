import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import 'shop_service.dart';

/// Ouvre la boutique pour offrir un cadeau ou un compliment à ce membre (depuis son profil ou une conversation).
Future<void> openGiftShop(BuildContext context, {required String userId, required String name}) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ShopScreen(recipientId: userId, recipientName: name)));

/// Boutique (régie v1 §6–7) : cadeaux virtuels et compliments, payés en pièces achetées. Prix, solde, limite et
/// blocages sont décidés par le serveur. Sans destinataire, la boutique se consulte seulement.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key, this.recipientId, this.recipientName, this.service});
  final String? recipientId;
  final String? recipientName;
  final ShopService? service;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  late final ShopService _shop = widget.service ?? ShopService.forRepository(Session.read(context).repo);
  late Future<ShopCatalog> _catalog = _shop.catalog();
  int? _coins;

  void _reload() {
    final next = _shop.catalog();
    setState(() {
      _catalog = next;
      _coins = null;
    });
  }

  String _errorText(Object e) {
    final s = context.s;
    final m = e.toString();
    if (m.contains('INSUFFICIENT_COINS')) return s.shopInsufficient;
    if (m.contains('DAILY_LIMIT')) return s.shopLimit;
    if (m.contains('TARGET_UNAVAILABLE') || m.contains('INVALID_TARGET')) return s.shopUnavailable;
    if (m.contains('PRICE_NOT_SET')) return s.shopNotOnSale;
    if (m.contains('FEATURE_DISABLED')) return s.shopDisabled;
    return friendlyError(e);
  }

  Future<void> _tap(ShopItem item, String lang) async {
    final s = context.s;
    final messenger = ScaffoldMessenger.of(context);
    final to = widget.recipientId;
    final name = widget.recipientName ?? '';
    if (to == null) {
      messenger.showSnackBar(SnackBar(content: Text(s.shopBrowseHint)));
      return;
    }
    if (!item.onSale) {
      messenger.showSnackBar(SnackBar(content: Text(s.shopNotOnSale)));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.shopConfirm(item.name(lang), name)),
        content: Text(s.shopConfirmBody(item.priceCoins!)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(s.shopSend)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final coins = await _shop.send(item, to);
      if (!mounted) return;
      setState(() => _coins = coins);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(s.shopSent)));
    } catch (e) {
      if (mounted) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(_errorText(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final lang = LanguageScope.maybeOf(context)?.language.code ?? 'fr';
    final title = widget.recipientName == null ? s.shopTitle : s.shopSendTo(widget.recipientName!);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            IconButton(
              tooltip: s.shopHistoryTitle,
              icon: const Icon(Icons.redeem_outlined),
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: (_) => ShopHistoryScreen(service: _shop))),
            ),
          ],
          bottom: TabBar(tabs: [Tab(text: s.shopGifts), Tab(text: s.shopCompliments)]),
        ),
        body: FutureBuilder<ShopCatalog>(
          future: _catalog,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return EmptyState(
                icon: Icons.wifi_off,
                title: s.loadError,
                message: '',
                action: OutlinedButton(onPressed: _reload, child: Text(s.retry)),
              );
            }
            final c = snap.data ?? const ShopCatalog();
            if (!c.enabled || c.items.isEmpty) {
              return EmptyState(icon: Icons.storefront_outlined, title: s.shopDisabled, message: '');
            }
            final coins = _coins ?? c.coins;
            return Column(children: [
              _CoinsBar(coins: coins, paymentsOpen: c.paymentsOpen),
              Expanded(
                child: TabBarView(children: [
                  GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 160, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.82),
                    itemCount: c.gifts.length,
                    itemBuilder: (context, i) =>
                        _GiftTile(item: c.gifts[i], lang: lang, onTap: () => _tap(c.gifts[i], lang)),
                  ),
                  ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: c.compliments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _ComplimentTile(
                        item: c.compliments[i], lang: lang, onTap: () => _tap(c.compliments[i], lang)),
                  ),
                ]),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

class _CoinsBar extends StatelessWidget {
  const _CoinsBar({required this.coins, required this.paymentsOpen});
  final int coins;
  final bool paymentsOpen;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(color: ZColors.primarySoft, borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        const Icon(Icons.toll, color: ZColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.walletCoinsBalance(coins),
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: ZColors.ink)),
            if (!paymentsOpen) Text(s.walletCoinsClosed, style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
        // Le bouton d'achat de pièces arrivera avec les moyens de paiement (décisions C7 et C8) ; d'ici là, seul
        // le message ci-contre s'affiche, sans bouton inactif.
      ]),
    );
  }
}

class _Price extends StatelessWidget {
  const _Price({required this.item});
  final ShopItem item;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: item.onSale ? ZColors.primary : ZColors.line,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(item.onSale ? s.shopPrice(item.priceCoins!) : s.shopNotOnSale,
          style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w700, color: item.onSale ? Colors.white : ZColors.muted)),
    );
  }
}

class _Visual extends StatelessWidget {
  const _Visual({required this.item, required this.size});
  final ShopItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = item.imageUrl;
    if (url != null) {
      return Image.network(url,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Text(item.emoji ?? '🎁', style: TextStyle(fontSize: size * 0.8)));
    }
    return Text(item.emoji ?? '🎁', style: TextStyle(fontSize: size * 0.8));
  }
}

class _GiftTile extends StatelessWidget {
  const _GiftTile({required this.item, required this.lang, required this.onTap});
  final ShopItem item;
  final String lang;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: item.rarity == 'common' ? ZColors.line : ZColors.premium),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              _Visual(item: item, size: 52),
              const SizedBox(height: 8),
              Text(item.name(lang),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: ZColors.ink)),
              const SizedBox(height: 6),
              _Price(item: item),
            ]),
          ),
        ),
      );
}

class _ComplimentTile extends StatelessWidget {
  const _ComplimentTile({required this.item, required this.lang, required this.onTap});
  final ShopItem item;
  final String lang;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18), side: const BorderSide(color: ZColors.line)),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              _Visual(item: item, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.name(lang), style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 3),
                  Text('« ${item.message(lang) ?? ''} »', style: Theme.of(context).textTheme.bodyMedium),
                ]),
              ),
              const SizedBox(width: 8),
              _Price(item: item),
            ]),
          ),
        ),
      );
}

/// Cadeaux et compliments reçus et envoyés.
class ShopHistoryScreen extends StatelessWidget {
  const ShopHistoryScreen({super.key, required this.service});
  final ShopService service;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.shopHistoryTitle),
          bottom: TabBar(tabs: [Tab(text: s.shopReceived), Tab(text: s.shopSentTab)]),
        ),
        body: TabBarView(children: [
          _HistoryList(future: service.history(), sent: false),
          _HistoryList(future: service.history(sent: true), sent: true),
        ]),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.future, required this.sent});
  final Future<List<ShopHistoryEntry>> future;
  final bool sent;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final lang = LanguageScope.maybeOf(context)?.language.code ?? 'fr';
    return FutureBuilder<List<ShopHistoryEntry>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        final rows = snap.data ?? const <ShopHistoryEntry>[];
        if (rows.isEmpty) return EmptyState(icon: Icons.redeem_outlined, title: s.shopHistoryEmpty, message: '');
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final e = rows[i];
            final message = e.item.message(lang);
            return ListTile(
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16), side: const BorderSide(color: ZColors.line)),
              leading: _Visual(item: e.item, size: 34),
              title: Text(e.item.name(lang)),
              subtitle: Text([sent ? s.shopTo(e.otherName) : s.shopFrom(e.otherName), if (message != null) message]
                  .join('\n')),
              trailing: Text(formatDate(e.at), style: Theme.of(context).textTheme.bodySmall),
            );
          },
        );
      },
    );
  }
}
