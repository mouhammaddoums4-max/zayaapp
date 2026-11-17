import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/l10n/l10n.dart';
import '../../core/motion.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import 'settings_widgets.dart';

/// Version la plus récente de chaque document, dans la langue demandée, sinon en français.
/// Renvoie aussi si le français a servi de repli.
({LegalDocument? doc, bool fallback}) pickLegalDocument(List<LegalDocument> all, String kind, String lang) {
  LegalDocument? latest(String l) {
    final list = all.where((d) => d.kind == kind && d.lang == l).toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return list.isEmpty ? null : list.first;
  }

  final own = latest(lang);
  if (own != null) return (doc: own, fallback: false);
  final fr = latest('fr');
  return (doc: fr, fallback: fr != null && lang != 'fr');
}

/// Documents légaux (CARTE_ECRANS F13) : conditions d'utilisation, confidentialité, règles communautaires.
/// Les textes viennent de `legal_documents` (versionnés) : rien n'est écrit en dur dans l'application.
class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  static const _kinds = ['tos', 'privacy', 'community'];
  late Future<List<LegalDocument>> _docs = Session.read(context).repo.legalDocuments();

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final lang = LanguageScope.maybeOf(context)?.language.code ?? 'fr';
    return Scaffold(
      appBar: AppBar(title: Text(s.legalTitle)),
      body: FutureBuilder<List<LegalDocument>>(
        future: _docs,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.wifi_off,
              title: s.loadError,
              message: '',
              action: OutlinedButton(
                onPressed: () {
                  final next = Session.read(context).repo.legalDocuments();
                  setState(() {
                    _docs = next;
                  });
                },
                child: Text(s.retry),
              ),
            );
          }
          final all = snapshot.data ?? const <LegalDocument>[];
          return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 28), children: [
            SettingsGroup(children: [
              for (final kind in _kinds)
                Builder(builder: (context) {
                  final picked = pickLegalDocument(all, kind, lang);
                  final doc = picked.doc;
                  return SettingsTile(
                    icon: switch (kind) {
                      'tos' => Icons.description_outlined,
                      'privacy' => Icons.privacy_tip_outlined,
                      _ => Icons.groups_outlined,
                    },
                    title: s.legalKind(kind),
                    subtitle: doc == null ? s.legalMissing : s.legalVersion(doc.version, formatDate(doc.publishedAt)),
                    onTap: doc == null
                        ? null
                        : () => Navigator.of(context)
                            .push(zRoute<void>(LegalDocumentScreen(document: doc, frenchFallback: picked.fallback))),
                  );
                }),
            ]),
          ]);
        },
      ),
    );
  }
}

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.document, this.frenchFallback = false});
  final LegalDocument document;
  final bool frenchFallback;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      appBar: AppBar(title: Text(s.legalKind(document.kind))),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 28), children: [
          Text(s.legalVersion(document.version, formatDate(document.publishedAt)),
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          if (document.isDraft) ...[
            InfoBanner(tone: BannerTone.warning, icon: Icons.edit_note, text: s.legalDraftNotice),
            const SizedBox(height: 12),
          ],
          if (frenchFallback) ...[
            InfoBanner(icon: Icons.translate, text: s.legalFrenchOnly),
            const SizedBox(height: 12),
          ],
          SelectableText(document.content, style: Theme.of(context).textTheme.bodyLarge),
        ]),
      ),
    );
  }
}
