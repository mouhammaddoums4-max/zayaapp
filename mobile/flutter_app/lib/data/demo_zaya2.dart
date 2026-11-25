import 'models.dart';

/// ZAYA 2.0 en mode démo : mêmes réponses que les fonctions serveur (migrations 0067 à 0069), en mémoire.
/// Aucune récompense réelle : tout est fictif et disparaît à la fermeture de l'application.
class DemoZaya2 {
  bool _pulseOptIn = false;
  bool _surpriseOpened = false;
  final Set<String> _claimed = <String>{};
  final Map<int, ({String answer, String visibility})> _answers = <int, ({String answer, String visibility})>{};
  String? _code;

  /// Profils consultés aujourd'hui (fictif) : le défi « Découvrez 5 profils » est donc réalisable en démo.
  static const _profilesViewed = 5;

  static const _questions = <(int, String, String, String, bool)>[
    (
      1,
      'marriage',
      'Pour vous, qu’est-ce qui fait un mariage réussi ?',
      'In your view, what makes a marriage successful?',
      false
    ),
    (
      2,
      'family',
      'Quelle place souhaitez-vous donner à vos familles dans votre couple ?',
      'What place do you want your families to have in your couple?',
      true
    ),
    (
      3,
      'children',
      'Souhaitez-vous des enfants ? Combien, et à quel moment ?',
      'Do you want children? How many, and when?',
      true
    ),
    (4, 'living', 'Où aimeriez-vous vivre après le mariage ?', 'Where would you like to live after marriage?', false),
  ];

  /// [fn] : nom de la fonction serveur imitée ; [p] : ses paramètres ; [pool] : profils fictifs proposés.
  Object? call(String fn, Map<String, Object?> p, List<DiscoveryProfile> pool) {
    switch (fn) {
      case 'my_daily_match':
        if (pool.isEmpty) return {'status': 'none'};
        final c = pool.first;
        return {
          'status': 'ready',
          'profile': {
            'id': c.id,
            'display_name': c.displayName,
            'age': c.age,
            'city': c.city,
            'bio': c.bio,
            'photo_path': c.photoPath,
            'shared_interests': 2,
            'is_verified': true,
          },
        };
      case 'pulse_feed':
        return {
          'status': 'ready',
          'opted_in': _pulseOptIn,
          'items': _pulseOptIn
              ? [
                  for (final c in pool.take(3))
                    {
                      'kind': 'new_member',
                      'user_id': c.id,
                      'display_name': c.displayName,
                      'age': c.age,
                      'city': c.city,
                      'photo_path': c.photoPath,
                      'joined_at': DateTime.now().toIso8601String()
                    },
                ]
              : <Object?>[],
          'stats': [
            {'city': 'Conakry — Ratoma', 'members': 42, 'active_this_week': 31},
          ],
        };
      case 'set_pulse_optin':
        _pulseOptIn = p['p_on'] == true;
        return _pulseOptIn;
      case 'my_referral_code':
        return _code ??= 'DEMO1A2B3C';
      case 'revoke_my_referral_code':
        _code = null;
        return null;
      case 'my_referral_summary':
        return {
          'status': 'ready',
          'code': _code,
          'invited': 3,
          'pending': 2,
          'rewarded': 1,
          'reward_swipes': 0,
          'min_days': 7
        };
      case 'redeem_referral':
        return {'status': 'pending'};
      case 'register_device':
        return null;
      case 'surprise_odds':
        return [
          {
            'code': 'question',
            'label_fr': 'Une question pour mieux vous connaître',
            'label_en': 'A question to know yourself better',
            'amount': 0,
            'percent': 100
          },
        ];
      case 'open_daily_surprise':
        final already = _surpriseOpened;
        _surpriseOpened = true;
        return {'status': already ? 'already_opened' : 'opened', 'prize': 'question', 'amount': 0, 'question_id': 4};
      case 'my_challenges':
        return {
          'status': 'ready',
          'challenges': [
            {
              'code': 'complete_profile',
              'title_fr': 'Complétez votre profil',
              'title_en': 'Complete your profile',
              'target': 1,
              'progress': 1,
              'reward': 0,
              'claimed': _claimed.contains('complete_profile')
            },
            {
              'code': 'answer_question',
              'title_fr': 'Répondez à une question',
              'title_en': 'Answer a question',
              'target': 1,
              'progress': _answers.isEmpty ? 0 : 1,
              'reward': 0,
              'claimed': _claimed.contains('answer_question')
            },
            {
              'code': 'discover_profiles',
              'title_fr': 'Découvrez 5 profils',
              'title_en': 'Discover 5 profiles',
              'target': 5,
              'progress': _profilesViewed,
              'reward': 0,
              'claimed': _claimed.contains('discover_profiles')
            },
          ],
        };
      case 'claim_challenge':
        final code = p['p_code'] as String;
        if (!_claimed.add(code)) throw Exception('ALREADY_CLAIMED');
        return {'status': 'claimed', 'reward': 0};
      case 'marriage_questions_list':
        return {
          'status': 'ready',
          'questions': [
            for (final q in _questions)
              {
                'id': q.$1,
                'topic': q.$2,
                'text_fr': q.$3,
                'text_en': q.$4,
                'sensitive': q.$5,
                'answer': _answers[q.$1]?.answer,
                'visibility': _answers[q.$1]?.visibility
              },
          ],
        };
      case 'answer_question':
        _answers[(p['p_question'] as num).toInt()] =
            (answer: (p['p_answer'] as String).trim(), visibility: (p['p_visibility'] as String?) ?? 'me');
        return {'status': 'saved'};
      case 'delete_answer':
        _answers.remove((p['p_question'] as num).toInt());
        return null;
      case 'answers_of':
        return <Object?>[];
    }
    throw Exception('Fonction inconnue en démo : $fn');
  }
}
