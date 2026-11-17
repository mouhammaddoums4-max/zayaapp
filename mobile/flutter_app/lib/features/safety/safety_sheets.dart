import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';

/// Conseils anti-arnaque et de rencontre (V6.3 §34.2) — affichés dans le bouclier et avant la révélation d'un numéro.
const safetyTips = <String>[
  'Ne transférez jamais d’argent, y compris par Mobile Money, à une personne que vous n’avez pas rencontrée.',
  'Ne communiquez jamais de code OTP, de mot de passe ou de code bancaire.',
  'Gardez vos échanges sur ZAYA aussi longtemps que possible.',
  'Pour une première rencontre : un lieu public, un proche informé, votre propre moyen de transport.',
];

/// Signalement : gratuit, confidentiel, accessible depuis un profil ou une conversation.
Future<void> showReportSheet(
  BuildContext context, {
  required String userId,
  required String name,
  required String reportContext,
  String? matchId,
}) async {
  final repo = Session.read(context).repo;
  final details = TextEditingController();
  String? reason;
  var sending = false;

  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheet) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 16),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Signaler $name', style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('Votre signalement est confidentiel : $name n’en sera pas informé(e).',
                  style: Theme.of(sheetContext).textTheme.bodyMedium),
              const SizedBox(height: 14),
              for (final e in reportReasons.entries)
                ChoiceTile(label: e.value, selected: reason == e.key, onTap: () => setSheet(() => reason = e.key)),
              const SizedBox(height: 4),
              TextField(
                controller: details,
                maxLines: 2,
                maxLength: 1000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Précisions (facultatif)', counterText: ''),
              ),
              const SizedBox(height: 14),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: ZColors.danger),
                onPressed: reason == null || sending
                    ? null
                    : () async {
                        final navigator = Navigator.of(sheetContext);
                        setSheet(() => sending = true);
                        try {
                          final text = details.text.trim();
                          await repo.report(userId,
                              context: reportContext,
                              reason: reason!,
                              details: text.isEmpty ? null : text,
                              matchId: matchId);
                          navigator.pop(true);
                        } catch (_) {
                          navigator.pop(false);
                        }
                      },
                child: Text(sending ? 'Envoi…' : 'Envoyer le signalement'),
              ),
            ]),
          ),
        ),
      ),
    ),
  );
  if (!context.mounted || sent == null) return;
  showZayaSnack(
    context,
    sent
        ? 'Signalement envoyé. Notre équipe de modération va l’examiner.'
        : 'Le signalement n’a pas pu être envoyé. Vérifiez votre connexion et réessayez.',
    error: !sent,
  );
}

/// Blocage immédiat : met fin au match et empêche toute interaction future.
/// Retourne `true` si la personne a bien été bloquée.
Future<bool> confirmBlock(BuildContext context, {required String userId, required String name}) async {
  final repo = Session.read(context).repo;
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Bloquer $name ?'),
      content: Text('$name ne pourra plus voir votre profil ni vous écrire, et votre match éventuel prendra fin. '
          '$name n’en sera pas informé(e). Vous pourrez débloquer cette personne depuis vos réglages.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Annuler')),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: ZColors.danger),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Bloquer'),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  try {
    await repo.block(userId);
    if (context.mounted) showZayaSnack(context, '$name est bloqué(e).');
    return true;
  } catch (e) {
    if (context.mounted) showZayaSnack(context, friendlyError(e), error: true);
    return false;
  }
}

/// Conseils de sécurité et rappel des règles communautaires.
class SafetyTipsScreen extends StatelessWidget {
  const SafetyTipsScreen({super.key});

  static const _rules = <(IconData, String, String)>[
    (
      Icons.favorite_border,
      'Respect et intentions sérieuses',
      'ZAYA est destiné aux adultes qui recherchent une relation sérieuse. Pas de harcèlement, d’insultes ni de menaces.'
    ),
    (
      Icons.no_adult_content,
      'Aucun contenu sexuel',
      'La nudité, les contenus sexuels explicites et les sollicitations sexuelles sont interdits.'
    ),
    (
      Icons.payments_outlined,
      'Jamais d’argent',
      'Les demandes d’argent, de codes ou de coordonnées bancaires sont interdites et doivent être signalées.'
    ),
    (
      Icons.person_off_outlined,
      'Pas de faux profil',
      'Usurper une identité ou utiliser les photos d’une autre personne entraîne la fermeture du compte.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conseils de sécurité')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 28), children: [
          const SectionTitle('Avant de faire confiance'),
          for (var i = 0; i < safetyTips.length; i++)
            FadeSlideIn(
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.check_circle_outline, size: 20, color: ZColors.success)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(safetyTips[i], style: Theme.of(context).textTheme.bodyLarge)),
                ]),
              ),
            ),
          const SizedBox(height: 10),
          const SectionTitle('Règles de la communauté'),
          for (final rule in _rules)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: ZColors.primarySoft, borderRadius: BorderRadius.circular(12)),
                  child: Icon(rule.$1, color: ZColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(rule.$2, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(rule.$3, style: Theme.of(context).textTheme.bodyMedium),
                  ]),
                ),
              ]),
            ),
          const InfoBanner(
            icon: Icons.shield_outlined,
            text: 'Vous pouvez signaler ou bloquer une personne à tout moment depuis son profil ou depuis le bouclier '
                'en haut d’une conversation. En cas de danger immédiat, contactez d’abord les secours.',
          ),
          const SizedBox(height: 12),
          Text(
            'ZAYA ne peut pas détecter toutes les fraudes : restez attentif, même avec un profil vérifié.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ]),
      ),
    );
  }
}
