import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Réglages de la demande d'avis (app_config, migration 0014). Valeurs prudentes si la configuration manque.
class RatingRules {
  const RatingRules({this.enabled = true, this.minDays = 7, this.minSessions = 5, this.intervalDays = 90});

  factory RatingRules.fromConfig(Map<String, Object?> c) {
    int n(String key, int fallback) => c[key] is num ? (c[key] as num).toInt() : fallback;
    return RatingRules(
      enabled: c['rating_prompt_enabled'] != false,
      minDays: n('rating_min_days', 7),
      minSessions: n('rating_min_sessions', 5),
      intervalDays: n('rating_interval_days', 90),
    );
  }

  final bool enabled;
  final int minDays;
  final int minSessions;
  final int intervalDays;
}

/// Décision pure (testable) : jamais pour un nouveau membre, jamais deux fois de suite.
bool shouldAskForRating({
  required RatingRules rules,
  required DateTime firstOpen,
  required int sessions,
  required DateTime? lastAsked,
  required DateTime now,
}) {
  if (!rules.enabled) return false;
  if (sessions < rules.minSessions) return false;
  if (now.difference(firstOpen).inDays < rules.minDays) return false;
  if (lastAsked != null && now.difference(lastAsked).inDays < rules.intervalDays) return false;
  return true;
}

/// Compte les ouvertures et propose, de temps en temps, la fenêtre d'avis officielle de Google Play.
/// Aucune question préalable du type « Aimez-vous ZAYA ? » : les règles du store l'interdisent (pas de filtrage des
/// avis). Hors Google Play (APK installé à la main), la fenêtre ne s'affiche pas et rien ne se passe.
class RatingPrompter {
  static const _firstOpenKey = 'zaya_first_open';
  static const _sessionsKey = 'zaya_sessions';
  static const _lastAskedKey = 'zaya_rating_last_asked';

  bool _askedThisSession = false;

  /// À appeler une fois par ouverture de l'application.
  static Future<void> recordSession({DateTime? now}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final at = (now ?? DateTime.now()).toIso8601String();
      if (prefs.getString(_firstOpenKey) == null) await prefs.setString(_firstOpenKey, at);
      await prefs.setInt(_sessionsKey, (prefs.getInt(_sessionsKey) ?? 0) + 1);
    } catch (_) {
      // Statistique locale de confort : sans stockage, aucune demande d'avis.
    }
  }

  /// À appeler à un moment calme (changement d'onglet), jamais au milieu d'une action.
  Future<void> maybeAsk(RatingRules rules, {DateTime? now}) async {
    if (_askedThisSession) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final first = DateTime.tryParse(prefs.getString(_firstOpenKey) ?? '');
      if (first == null) return;
      final last = DateTime.tryParse(prefs.getString(_lastAskedKey) ?? '');
      final at = now ?? DateTime.now();
      if (!shouldAskForRating(
          rules: rules, firstOpen: first, sessions: prefs.getInt(_sessionsKey) ?? 0, lastAsked: last, now: at)) {
        return;
      }
      _askedThisSession = true;
      await prefs.setString(_lastAskedKey, at.toIso8601String());
      final review = InAppReview.instance;
      if (await review.isAvailable()) await review.requestReview();
    } catch (_) {
      // Store indisponible : on réessaiera après l'intervalle prévu.
    }
  }
}
