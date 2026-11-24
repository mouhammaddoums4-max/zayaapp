import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repository.dart';

/// Récompense proposée AVANT le visionnage (régie v1 §2.1) : montant, nombre restant aujourd'hui, libellé.
class RewardOffer {
  const RewardOffer(
      {required this.available, this.amount = 0, this.remainingToday = 0, this.labelFr = '', this.labelEn = ''});
  const RewardOffer.none() : this(available: false);

  factory RewardOffer.fromJson(Map<String, dynamic> j) => RewardOffer(
        available: j['available'] == true,
        amount: (j['amount'] as num?)?.toInt() ?? 0,
        remainingToday: (j['remaining_today'] as num?)?.toInt() ?? 0,
        labelFr: j['label_fr'] as String? ?? '',
        labelEn: j['label_en'] as String? ?? '',
      );

  final bool available;
  final int amount;
  final int remainingToday;
  final String labelFr;
  final String labelEn;

  String label(String lang) => lang == 'en' && labelEn.isNotEmpty ? labelEn : labelFr;
}

/// Portefeuille (régie v1 §8) : trois catégories séparées, soldes calculés par le serveur.
class Wallet {
  const Wallet({
    this.adSwipes = 0,
    this.adBoosts = 0,
    this.coins = 0,
    this.bonusSwipes = 0,
    this.bonusBoosts = 0,
    this.bonusPremiumDays = 0,
    this.premiumActive = false,
    this.premiumEndsAt,
    this.history = const <WalletEntry>[],
  });

  factory Wallet.fromJson(Map<String, dynamic> j) {
    final ad = Map<String, dynamic>.from(j['ad_credits'] as Map? ?? const {});
    final bonus = Map<String, dynamic>.from(j['bonus'] as Map? ?? const {});
    final premium = Map<String, dynamic>.from(j['premium'] as Map? ?? const {});
    return Wallet(
      adSwipes: (ad['swipes'] as num?)?.toInt() ?? 0,
      adBoosts: (ad['boosts'] as num?)?.toInt() ?? 0,
      coins: (j['coins'] as num?)?.toInt() ?? 0,
      bonusSwipes: (bonus['swipes'] as num?)?.toInt() ?? 0,
      bonusBoosts: (bonus['boosts'] as num?)?.toInt() ?? 0,
      bonusPremiumDays: (bonus['premium_days'] as num?)?.toInt() ?? 0,
      premiumActive: premium['active'] == true,
      premiumEndsAt: premium['ends_at'] == null ? null : DateTime.parse(premium['ends_at'] as String),
      history: [
        for (final raw in (j['history'] as List? ?? const []))
          () {
            final r = Map<String, dynamic>.from(raw as Map);
            return WalletEntry(
              category: r['category'] as String,
              asset: r['asset'] as String,
              amount: (r['amount'] as num).toInt(),
              reason: r['reason'] as String,
              at: DateTime.parse(r['created_at'] as String),
            );
          }(),
      ],
    );
  }

  final int adSwipes;
  final int adBoosts;
  final int coins;

  /// Cadeaux de ZAYA (boîte mystère, 0033) : catégorie séparée des crédits publicitaires et des pièces.
  final int bonusSwipes;
  final int bonusBoosts;
  final int bonusPremiumDays;
  final bool premiumActive;
  final DateTime? premiumEndsAt;
  final List<WalletEntry> history;

  bool get hasBonus => bonusSwipes > 0 || bonusBoosts > 0 || bonusPremiumDays > 0;
}

class WalletEntry {
  const WalletEntry(
      {required this.category, required this.asset, required this.amount, required this.reason, required this.at});
  final String category; // ad_credit | coins | bonus
  final String asset; // swipes | boost | coins
  final int amount;
  final String reason;
  final DateTime at;
}

/// Ce que l'application montre ; tout crédit est décidé par le serveur après vérification de Google (SSV).
abstract class RewardsService {
  Future<RewardOffer> offer(String reward);
  Future<Wallet> wallet();

  /// Affiche la publicité récompensée ; renvoie vrai si Google a signalé la fin du visionnage. Le crédit, lui,
  /// n'arrive qu'après la vérification côté serveur : appeler [waitForCredit].
  Future<bool> showRewardedAd(String reward);

  /// Attend que le serveur ait crédité la récompense (nombre restant du jour qui diminue), au plus [timeout].
  Future<bool> waitForCredit(String reward, {required int remainingBefore, Duration timeout});

  static RewardsService forRepository(ZayaRepository repo) =>
      repo.isDemo ? const NoRewardsService() : SupabaseRewardsService(Supabase.instance.client, repo);
}

class NoRewardsService implements RewardsService {
  const NoRewardsService();

  @override
  Future<RewardOffer> offer(String reward) async => const RewardOffer.none();
  @override
  Future<Wallet> wallet() async => const Wallet();
  @override
  Future<bool> showRewardedAd(String reward) async => false;
  @override
  Future<bool> waitForCredit(String reward, {required int remainingBefore, Duration timeout = Duration.zero}) async =>
      false;
}

class SupabaseRewardsService implements RewardsService {
  SupabaseRewardsService(this._db, this._repo);
  final SupabaseClient _db;
  final ZayaRepository _repo;
  static bool _initialized = false;

  @override
  Future<RewardOffer> offer(String reward) async => RewardOffer.fromJson(
      Map<String, dynamic>.from(await _db.rpc('my_reward_offer', params: {'p_reward': reward}) as Map));

  @override
  Future<Wallet> wallet() async => Wallet.fromJson(Map<String, dynamic>.from(await _db.rpc('my_wallet') as Map));

  @override
  Future<bool> showRewardedAd(String reward) async {
    final config = await _repo.publicConfig();
    final unit = (config['admob_rewarded_unit_android'] ?? '').toString();
    final userId = _repo.userId;
    if (config['ads_admob_enabled'] != true || unit.isEmpty || userId == null) return false;
    if (!_initialized) {
      await MobileAds.instance.initialize();
      _initialized = true;
    }
    final loaded = Completer<RewardedAd?>();
    // Publicités non personnalisées : aucun ciblage à partir du profil ni des données sensibles (CDC §22.13).
    await RewardedAd.load(
      adUnitId: unit,
      request: const AdRequest(nonPersonalizedAds: true),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: loaded.complete,
        onAdFailedToLoad: (_) => loaded.complete(null),
      ),
    );
    final ad = await loaded.future;
    if (ad == null) return false;
    // Google renverra userId et customData au serveur (fonction admob-ssv) : c'est là que le crédit est décidé.
    await ad.setServerSideOptions(ServerSideVerificationOptions(userId: userId, customData: reward));
    final done = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        if (!done.isCompleted) done.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        if (!done.isCompleted) done.complete(false);
      },
    );
    await ad.show(onUserEarnedReward: (_, __) => earned = true);
    return done.future;
  }

  @override
  Future<bool> waitForCredit(String reward,
      {required int remainingBefore, Duration timeout = const Duration(seconds: 15)}) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(seconds: 2));
      try {
        if ((await offer(reward)).remainingToday < remainingBefore) return true;
      } catch (_) {
        // Réseau instable : on réessaie jusqu'à la fin du délai.
      }
    }
    return false;
  }
}
