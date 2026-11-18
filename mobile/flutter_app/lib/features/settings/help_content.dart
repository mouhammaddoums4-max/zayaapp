import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repository.dart';

/// Une question fréquente, administrée dans Supabase (table help_articles, migration 0019).
class HelpArticle {
  const HelpArticle({required this.section, required this.question, required this.answer});
  final String section;
  final String question;
  final String answer;
}

/// Une rubrique de l'aide et ses questions, dans l'ordre choisi par l'équipe.
class HelpSection {
  const HelpSection(this.title, this.articles);
  final String title;
  final List<HelpArticle> articles;
}

/// Regroupe des questions déjà triées par rubrique, en gardant l'ordre de première apparition.
List<HelpSection> groupHelp(List<HelpArticle> articles) {
  final order = <String>[];
  final bySection = <String, List<HelpArticle>>{};
  for (final a in articles) {
    if (!bySection.containsKey(a.section)) order.add(a.section);
    bySection.putIfAbsent(a.section, () => <HelpArticle>[]).add(a);
  }
  return [for (final s in order) HelpSection(s, bySection[s]!)];
}

/// Lecture de l'aide : aucune question n'est écrite dans l'application (consigne « pas de données en dur »).
abstract class HelpContent {
  /// Questions dans [lang], sinon en français.
  Future<List<HelpSection>> sections(String lang);

  static HelpContent forRepository(ZayaRepository repo) =>
      repo.isDemo ? const DemoHelpContent() : SupabaseHelpContent(Supabase.instance.client);
}

class SupabaseHelpContent implements HelpContent {
  SupabaseHelpContent(this._db);
  final SupabaseClient _db;

  Future<List<HelpArticle>> _fetch(String lang) async {
    final rows = await _db
        .from('help_articles')
        .select('section, question, answer')
        .eq('lang', lang)
        .order('position')
        .order('id');
    return [
      for (final r in rows)
        HelpArticle(section: r['section'] as String, question: r['question'] as String, answer: r['answer'] as String),
    ];
  }

  @override
  Future<List<HelpSection>> sections(String lang) async {
    var articles = await _fetch(lang);
    if (articles.isEmpty && lang != 'fr') articles = await _fetch('fr');
    return groupHelp(articles);
  }
}

/// Mode démo (aucun serveur) : quelques questions fictives, pour parcourir l'écran.
class DemoHelpContent implements HelpContent {
  const DemoHelpContent();

  @override
  Future<List<HelpSection>> sections(String lang) async => groupHelp(const [
        HelpArticle(
          section: 'Compte et profil',
          question: 'Mon numéro de téléphone est-il visible ?',
          answer: 'Non. Il sert uniquement à vous connecter et à sécuriser votre compte. Il n’apparaît jamais sur '
              'votre profil ni dans vos conversations.',
        ),
        HelpArticle(
          section: 'Rencontres et messages',
          question: 'Comment se crée un match ?',
          answer: 'Un match se crée seulement lorsque deux personnes s’aiment mutuellement.',
        ),
        HelpArticle(
          section: 'Sécurité',
          question: 'Comment signaler ou bloquer quelqu’un ?',
          answer: 'Depuis son profil ou la conversation, ouvrez le menu ⋯ puis choisissez « Signaler » ou « Bloquer ».',
        ),
      ]);
}
