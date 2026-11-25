import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app.dart';
import '../../data/models.dart';
import '../../data/repository.dart';

/// Texte selon la langue de l'application (français par défaut, anglais si choisi).
String tr(BuildContext context, String fr, String en) => Localizations.localeOf(context).languageCode == 'en' ? en : fr;

Map<String, Object?> _map(Object? value) => value is Map ? Map<String, Object?>.from(value) : const <String, Object?>{};
List<Map<String, Object?>> _list(Object? value) =>
    value is List ? [for (final v in value) _map(v)] : const <Map<String, Object?>>[];
int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
String? _str(Object? v) => v == null ? null : '$v';

/// Suggestion du jour (migration 0068) : `profile` nul si aucun profil n'est proposé.
class DailyMatch {
  const DailyMatch({required this.status, this.profile, this.sharedInterests = 0});
  final String status;
  final DiscoveryProfile? profile;
  final int sharedInterests;
  bool get ready => status == 'ready' && profile != null;
}

class PulseMember {
  const PulseMember({required this.userId, required this.name, required this.age, this.city, this.photoPath});
  final String userId;
  final String name;
  final int age;
  final String? city;
  final String? photoPath;
}

class PulseStat {
  const PulseStat({required this.city, required this.members, required this.activeThisWeek});
  final String city;
  final int members;
  final int activeThisWeek;
}

class PulseFeed {
  const PulseFeed({required this.status, this.optedIn = false, this.members = const [], this.stats = const []});
  final String status;
  final bool optedIn;
  final List<PulseMember> members;
  final List<PulseStat> stats;
}

class ReferralSummary {
  const ReferralSummary({
    required this.status,
    this.code,
    this.invited = 0,
    this.pending = 0,
    this.rewarded = 0,
    this.rewardSwipes = 0,
    this.minDays = 7,
  });
  final String status;
  final String? code;
  final int invited;
  final int pending;
  final int rewarded;
  final int rewardSwipes;
  final int minDays;
}

class SurpriseOdd {
  const SurpriseOdd(
      {required this.code, required this.labelFr, required this.labelEn, required this.amount, required this.percent});
  final String code;
  final String labelFr;
  final String labelEn;
  final int amount;
  final double percent;
}

class SurpriseResult {
  const SurpriseResult({required this.status, this.prize, this.amount = 0, this.questionId});
  final String status;
  final String? prize;
  final int amount;
  final int? questionId;
  bool get opened => status == 'opened' || status == 'already_opened';
}

class ChallengeItem {
  const ChallengeItem({
    required this.code,
    required this.titleFr,
    required this.titleEn,
    required this.target,
    required this.progress,
    required this.reward,
    required this.claimed,
  });
  final String code;
  final String titleFr;
  final String titleEn;
  final int target;
  final int progress;
  final int reward;
  final bool claimed;
  bool get completed => progress >= target;
}

class MarriageQuestion {
  const MarriageQuestion({
    required this.id,
    required this.topic,
    required this.textFr,
    required this.textEn,
    required this.sensitive,
    this.answer,
    this.visibility,
  });
  final int id;
  final String topic;
  final String textFr;
  final String textEn;
  final bool sensitive;
  final String? answer;
  final String? visibility;
}

/// Accès aux fonctions ZAYA 2.0. Chaque règle (éligibilité, quotas, récompenses) est vérifiée par le serveur ;
/// l'application ne fait qu'afficher ce qu'il renvoie.
class Zaya2Api {
  Zaya2Api(this.repo);
  final ZayaRepository repo;

  static Zaya2Api of(BuildContext context) => Zaya2Api(Session.read(context).repo);

  static const _deviceKey = 'zaya_device_id';

  /// Identifiant aléatoire de cette installation, transmis seulement sous forme opaque au serveur : il sert à
  /// repérer l'auto-parrainage et les récompenses multipliées sur un même téléphone. Aucun identifiant matériel.
  Future<void> registerDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString(_deviceKey);
      if (id == null || id.length < 32) {
        final rnd = Random.secure();
        id = List<String>.generate(32, (_) => rnd.nextInt(16).toRadixString(16)).join();
        await prefs.setString(_deviceKey, id);
      }
      await repo.zayaRpc('register_device', {'p_hash': id});
    } catch (_) {
      // Sans réseau : nouvel essai à la prochaine ouverture. Le serveur reste juge des récompenses.
    }
  }

  Future<DailyMatch> dailyMatch() async {
    final r = _map(await repo.zayaRpc('my_daily_match'));
    final p = _map(r['profile']);
    return DailyMatch(
      status: _str(r['status']) ?? 'none',
      sharedInterests: _int(p['shared_interests']),
      profile: p.isEmpty
          ? null
          : DiscoveryProfile(
              id: p['id'] as String,
              displayName: _str(p['display_name']) ?? '',
              age: _int(p['age']),
              city: _str(p['city']),
              bio: _str(p['bio']),
              photoPath: _str(p['photo_path']),
              isVerified: p['is_verified'] == true,
            ),
    );
  }

  Future<PulseFeed> pulse() async {
    final r = _map(await repo.zayaRpc('pulse_feed'));
    return PulseFeed(
      status: _str(r['status']) ?? 'none',
      optedIn: r['opted_in'] == true,
      members: [
        for (final m in _list(r['items']))
          PulseMember(
            userId: m['user_id'] as String,
            name: _str(m['display_name']) ?? '',
            age: _int(m['age']),
            city: _str(m['city']),
            photoPath: _str(m['photo_path']),
          ),
      ],
      stats: [
        for (final s in _list(r['stats']))
          PulseStat(
              city: _str(s['city']) ?? '', members: _int(s['members']), activeThisWeek: _int(s['active_this_week'])),
      ],
    );
  }

  Future<bool> setPulseOptIn(bool on) async => (await repo.zayaRpc('set_pulse_optin', {'p_on': on})) == true;

  Future<String> referralCode() async => '${await repo.zayaRpc('my_referral_code')}';

  Future<void> revokeReferralCode() => repo.zayaRpc('revoke_my_referral_code');

  Future<String> redeemReferral(String code) async =>
      _str(_map(await repo.zayaRpc('redeem_referral', {'p_code': code.trim()}))['status']) ?? 'pending';

  Future<ReferralSummary> referralSummary() async {
    final r = _map(await repo.zayaRpc('my_referral_summary'));
    return ReferralSummary(
      status: _str(r['status']) ?? 'none',
      code: _str(r['code']),
      invited: _int(r['invited']),
      pending: _int(r['pending']),
      rewarded: _int(r['rewarded']),
      rewardSwipes: _int(r['reward_swipes']),
      minDays: _int(r['min_days']) == 0 ? 7 : _int(r['min_days']),
    );
  }

  Future<List<SurpriseOdd>> surpriseOdds() async => [
        for (final o in _list(await repo.zayaRpc('surprise_odds')))
          SurpriseOdd(
            code: _str(o['code']) ?? '',
            labelFr: _str(o['label_fr']) ?? '',
            labelEn: _str(o['label_en']) ?? '',
            amount: _int(o['amount']),
            percent: o['percent'] is num ? (o['percent'] as num).toDouble() : double.tryParse('${o['percent']}') ?? 0,
          ),
      ];

  Future<SurpriseResult> openSurprise() async {
    final r = _map(await repo.zayaRpc('open_daily_surprise'));
    return SurpriseResult(
      status: _str(r['status']) ?? 'none',
      prize: _str(r['prize']),
      amount: _int(r['amount']),
      questionId: r['question_id'] == null ? null : _int(r['question_id']),
    );
  }

  Future<(String, List<ChallengeItem>)> challenges() async {
    final r = _map(await repo.zayaRpc('my_challenges'));
    return (
      _str(r['status']) ?? 'none',
      [
        for (final c in _list(r['challenges']))
          ChallengeItem(
            code: _str(c['code']) ?? '',
            titleFr: _str(c['title_fr']) ?? '',
            titleEn: _str(c['title_en']) ?? '',
            target: _int(c['target']),
            progress: _int(c['progress']),
            reward: _int(c['reward']),
            claimed: c['claimed'] == true,
          ),
      ],
    );
  }

  Future<int> claimChallenge(String code) async =>
      _int(_map(await repo.zayaRpc('claim_challenge', {'p_code': code}))['reward']);

  Future<(String, List<MarriageQuestion>)> questions() async {
    final r = _map(await repo.zayaRpc('marriage_questions_list'));
    return (
      _str(r['status']) ?? 'none',
      [
        for (final q in _list(r['questions']))
          MarriageQuestion(
            id: _int(q['id']),
            topic: _str(q['topic']) ?? '',
            textFr: _str(q['text_fr']) ?? '',
            textEn: _str(q['text_en']) ?? '',
            sensitive: q['sensitive'] == true,
            answer: _str(q['answer']),
            visibility: _str(q['visibility']),
          ),
      ],
    );
  }

  /// Renvoie la catégorie refusée par le filtre (numéro, lien, terme interdit), ou null si la réponse est enregistrée.
  Future<String?> answerQuestion(int questionId, String answer, String visibility) async {
    final r = _map(await repo
        .zayaRpc('answer_question', {'p_question': questionId, 'p_answer': answer, 'p_visibility': visibility}));
    return r['status'] == 'blocked' ? (_str(r['category']) ?? 'blocked') : null;
  }

  Future<void> deleteAnswer(int questionId) => repo.zayaRpc('delete_answer', {'p_question': questionId});
}
