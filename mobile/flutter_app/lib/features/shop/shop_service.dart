import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repository.dart';

/// Article de la boutique (migration 0035) : cadeau virtuel ou compliment écrit par l'équipe.
class ShopItem {
  const ShopItem({
    required this.id,
    required this.code,
    required this.kind,
    required this.nameFr,
    this.nameEn = '',
    this.emoji,
    this.imageUrl,
    this.messageFr,
    this.messageEn,
    this.priceCoins,
    this.rarity = 'common',
  });

  factory ShopItem.fromJson(Map<String, dynamic> j, {String? Function(Object? path)? imageUrl}) => ShopItem(
        id: j['id'] as String,
        code: j['code'] as String,
        kind: j['kind'] as String,
        nameFr: j['name_fr'] as String,
        nameEn: (j['name_en'] ?? '') as String,
        emoji: j['emoji'] as String?,
        imageUrl: imageUrl?.call(j['image_path']),
        messageFr: j['message_fr'] as String?,
        messageEn: j['message_en'] as String?,
        priceCoins: (j['price_coins'] as num?)?.toInt(),
        rarity: (j['rarity'] ?? 'common') as String,
      );

  final String id;
  final String code;
  final String kind; // gift | compliment
  final String nameFr;
  final String nameEn;
  final String? emoji;
  final String? imageUrl;
  final String? messageFr;
  final String? messageEn;

  /// Prix fixé par l'équipe ; null : pas encore en vente.
  final int? priceCoins;
  final String rarity;

  bool get isGift => kind == 'gift';
  bool get onSale => priceCoins != null;
  String name(String lang) => lang == 'en' && nameEn.isNotEmpty ? nameEn : nameFr;
  String? message(String lang) => lang == 'en' && (messageEn ?? '').isNotEmpty ? messageEn : messageFr;
}

class ShopCatalog {
  const ShopCatalog({this.enabled = false, this.coins = 0, this.paymentsOpen = false, this.items = const []});
  final bool enabled;

  /// Pièces achetées uniquement (jamais de crédits publicitaires).
  final int coins;
  final bool paymentsOpen;
  final List<ShopItem> items;

  List<ShopItem> get gifts => [for (final i in items) if (i.isGift) i];
  List<ShopItem> get compliments => [for (final i in items) if (!i.isGift) i];
}

/// Cadeau ou compliment reçu ou envoyé.
class ShopHistoryEntry {
  const ShopHistoryEntry({required this.item, required this.otherId, required this.otherName, required this.at});
  final ShopItem item;
  final String otherId;
  final String otherName;
  final DateTime at;
}

/// Tout est décidé par le serveur : prix, solde, limite, blocages, débit et envoi indissociables.
abstract class ShopService {
  Future<ShopCatalog> catalog();

  /// Renvoie le nouveau solde de pièces.
  Future<int> send(ShopItem item, String toUserId);
  Future<List<ShopHistoryEntry>> history({bool sent = false});

  static ShopService forRepository(ZayaRepository repo) =>
      repo.isDemo ? const NoShop() : SupabaseShop(Supabase.instance.client);
}

/// Mode démo : boutique vide.
class NoShop implements ShopService {
  const NoShop();
  @override
  Future<ShopCatalog> catalog() async => const ShopCatalog();
  @override
  Future<int> send(ShopItem item, String toUserId) async => throw StateError('FEATURE_DISABLED');
  @override
  Future<List<ShopHistoryEntry>> history({bool sent = false}) async => const [];
}

class SupabaseShop implements ShopService {
  SupabaseShop(this._db);
  final SupabaseClient _db;

  String? _image(Object? path) {
    final p = (path ?? '').toString();
    return p.isEmpty ? null : _db.storage.from('shop-media').getPublicUrl(p);
  }

  @override
  Future<ShopCatalog> catalog() async {
    final j = Map<String, dynamic>.from(await _db.rpc('shop_catalog') as Map);
    return ShopCatalog(
      enabled: j['enabled'] == true,
      coins: (j['coins'] as num?)?.toInt() ?? 0,
      paymentsOpen: j['payments_open'] == true,
      items: [
        for (final raw in (j['items'] as List? ?? const []))
          ShopItem.fromJson(Map<String, dynamic>.from(raw as Map), imageUrl: _image),
      ],
    );
  }

  @override
  Future<int> send(ShopItem item, String toUserId) async {
    final r = Map<String, dynamic>.from(
        await _db.rpc('send_shop_item', params: {'p_item': item.id, 'p_to': toUserId}) as Map);
    return (r['coins'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<List<ShopHistoryEntry>> history({bool sent = false}) async {
    final rows = await _db.rpc('my_shop_history', params: {'p_direction': sent ? 'sent' : 'received', 'p_limit': 100})
        as List;
    return [
      for (final raw in rows)
        () {
          final r = Map<String, dynamic>.from(raw as Map);
          return ShopHistoryEntry(
            item: ShopItem.fromJson({...r, 'id': r['id']}, imageUrl: _image),
            otherId: r['other_id'] as String,
            otherName: (r['other_name'] ?? '') as String,
            at: DateTime.parse(r['created_at'] as String),
          );
        }(),
    ];
  }
}
