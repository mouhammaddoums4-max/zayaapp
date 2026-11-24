import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repository.dart';

/// Un lot possible de la boîte mystère, avec sa probabilité réelle (calculée par le serveur).
class MysteryPrize {
  const MysteryPrize({
    required this.code,
    required this.kind,
    required this.amount,
    required this.labelFr,
    required this.labelEn,
    this.probabilityPercent,
  });

  factory MysteryPrize.fromJson(Map<String, dynamic> j) => MysteryPrize(
        code: j['code'] as String,
        kind: j['kind'] as String? ?? '',
        amount: (j['amount'] as num?)?.toInt() ?? 0,
        labelFr: j['label_fr'] as String? ?? '',
        labelEn: j['label_en'] as String? ?? '',
        probabilityPercent: (j['probability_percent'] as num?)?.toDouble(),
      );

  final String code;
  final String kind; // extra_swipes | boost_credit | premium_days
  final int amount;
  final String labelFr;
  final String labelEn;
  final double? probabilityPercent;

  String label(String lang) => lang == 'en' && labelEn.isNotEmpty ? labelEn : labelFr;
}

/// État de la boîte pour le membre connecté (mystery_box_status, migration 0033).
class MysteryBoxState {
  const MysteryBoxState({
    this.enabled = false,
    this.eligible = false,
    this.opened = false,
    this.prize,
    this.prizes = const <MysteryPrize>[],
  });

  factory MysteryBoxState.fromJson(Map<String, dynamic> j) => MysteryBoxState(
        enabled: j['enabled'] == true,
        eligible: j['eligible'] == true,
        opened: j['opened'] == true,
        prize: j['prize'] is Map ? MysteryPrize.fromJson(Map<String, dynamic>.from(j['prize'] as Map)) : null,
        prizes: [
          for (final p in (j['prizes'] as List? ?? const [])) MysteryPrize.fromJson(Map<String, dynamic>.from(p as Map)),
        ],
      );

  final bool enabled;
  final bool eligible;
  final bool opened;
  final MysteryPrize? prize;
  final List<MysteryPrize> prizes;

  /// Une boîte reste à ouvrir.
  bool get available => enabled && eligible && !opened && prizes.isNotEmpty;
}

/// Tout est décidé par le serveur : éligibilité, tirage, stock, crédit, ouverture unique.
abstract class MysteryBoxService {
  Future<MysteryBoxState> status();

  /// Ouvre la boîte ; un second appel renvoie le même lot (aucun nouveau tirage).
  Future<MysteryBoxState> open();

  static MysteryBoxService forRepository(ZayaRepository repo) =>
      repo.isDemo ? const NoMysteryBox() : SupabaseMysteryBox(Supabase.instance.client);
}

/// Mode démo (aucun serveur) : pas de boîte.
class NoMysteryBox implements MysteryBoxService {
  const NoMysteryBox();
  @override
  Future<MysteryBoxState> status() async => const MysteryBoxState();
  @override
  Future<MysteryBoxState> open() async => const MysteryBoxState();
}

class SupabaseMysteryBox implements MysteryBoxService {
  SupabaseMysteryBox(this._db);
  final SupabaseClient _db;

  @override
  Future<MysteryBoxState> status() async =>
      MysteryBoxState.fromJson(Map<String, dynamic>.from(await _db.rpc('mystery_box_status') as Map));

  @override
  Future<MysteryBoxState> open() async =>
      MysteryBoxState.fromJson(Map<String, dynamic>.from(await _db.rpc('open_mystery_box') as Map));
}
