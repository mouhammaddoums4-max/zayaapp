import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';

/// Comparaison Gratuit / Premium : claire, stable, sans compte à rebours ni pression (V3.0 §4.4, §5).
/// Aucun achat n'est possible tant que les moyens de paiement ne sont pas validés.
class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  static const _rows = <(String, bool, bool)>[
    ('Créer et gérer son profil', true, true),
    ('Découvrir tous les profils, Gratuit et Premium', true, true),
    ('Likes quotidiens', true, true),
    ('Matchs réciproques et messagerie', true, true),
    ('Bloquer, signaler, masquer son profil', true, true),
    ('Exporter et supprimer ses données', true, true),
    ('Voir qui a aimé votre profil', false, true),
    ('Davantage de likes par jour', false, true),
    ('Filtres de recherche avancés', false, true),
    ('Statistiques détaillées du profil', false, true),
  ];

  @override
  Widget build(BuildContext context) {
    final me = Session.of(context).me;
    final premium = me?.isPremium ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('ZAYA Premium')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 28), children: [
          FadeSlideIn(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(gradient: ZColors.brandGradient, borderRadius: BorderRadius.circular(24)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.workspace_premium, color: Colors.white, size: 36),
                const SizedBox(height: 10),
                Text(premium ? 'Vous êtes Premium' : 'Allez plus loin avec Premium',
                    style: GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 6),
                Text(
                  'Premium ajoute du confort. Les fonctions essentielles de rencontre — découvrir, aimer, '
                  'matcher, discuter, se protéger — restent gratuites.',
                  style: GoogleFonts.inter(fontSize: 14, color: Colors.white.withValues(alpha: 0.95), height: 1.45),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 18),
          FadeSlideIn(
            index: 1,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: ZColors.line),
              ),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Row(children: [
                    const Expanded(child: SizedBox.shrink()),
                    SizedBox(width: 64, child: Center(child: Text('Gratuit', style: _head(ZColors.muted)))),
                    SizedBox(width: 72, child: Center(child: Text('Premium', style: _head(ZColors.premium)))),
                  ]),
                ),
                for (final row in _rows) ...[
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    child: Row(children: [
                      Expanded(child: Text(row.$1, style: Theme.of(context).textTheme.bodyLarge)),
                      SizedBox(width: 64, child: _Mark(included: row.$2, color: ZColors.success)),
                      SizedBox(width: 72, child: _Mark(included: row.$3, color: ZColors.premium)),
                    ]),
                  ),
                ],
              ]),
            ),
          ),
          const SizedBox(height: 16),
          const InfoBanner(
            icon: Icons.lock_outline,
            text: 'Premium ne permet jamais de contourner les réglages de confidentialité d’un autre membre, '
                'et ne garantit ni match, ni réponse, ni relation.',
          ),
          const SizedBox(height: 10),
          InfoBanner(
            tone: BannerTone.warning,
            icon: Icons.schedule,
            text: premium
                ? 'Retrouvez les dates de votre abonnement dans « Mes abonnements ».'
                : 'Les abonnements ne sont pas encore ouverts : aucun paiement n’est possible pour le moment. '
                    'Les prix et moyens de paiement seront affichés ici avant tout achat.',
          ),
          if (premium) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(zRoute<void>(const SubscriptionsScreen())),
              child: const Text('Mes abonnements'),
            ),
          ],
        ]),
      ),
    );
  }

  static TextStyle _head(Color color) => GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: color);
}

class _Mark extends StatelessWidget {
  const _Mark({required this.included, required this.color});
  final bool included;
  final Color color;

  @override
  Widget build(BuildContext context) => Center(
        child: Icon(
          included ? Icons.check_circle : Icons.remove,
          size: 20,
          color: included ? color : ZColors.line,
          semanticLabel: included ? 'Inclus' : 'Non inclus',
        ),
      );
}

/// « Mes abonnements » : offre actuelle, statut, dates, mode d'obtention et historique (V6.4 §40.1).
class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  late Future<List<PremiumGrant>> _future = Session.read(context).repo.premiumHistory();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes abonnements')),
      body: FutureBuilder<List<PremiumGrant>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(padding: EdgeInsets.all(20), child: Skeleton(height: 130));
          }
          final grants = snapshot.data;
          if (snapshot.hasError || grants == null) {
            return EmptyState(
              icon: Icons.wifi_off,
              title: 'Connexion interrompue',
              message: 'Vos abonnements ne peuvent pas être chargés.',
              action: FilledButton(
                onPressed: () => setState(() => _future = Session.read(context).repo.premiumHistory()),
                child: const Text('Réessayer'),
              ),
            );
          }
          PremiumGrant? active;
          for (final g in grants) {
            if (g.isActive) {
              active = g;
              break;
            }
          }
          return ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 28), children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: active == null ? ZColors.line : ZColors.premium, width: active == null ? 1 : 1.5),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Offre actuelle', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 4),
                Row(children: [
                  Text(active == null ? 'Gratuit' : 'Premium', style: Theme.of(context).textTheme.headlineMedium),
                  if (active != null) ...[const SizedBox(width: 10), const PremiumBadge()],
                ]),
                const SizedBox(height: 10),
                if (active == null)
                  Text('Toutes les fonctions essentielles de rencontre sont incluses.',
                      style: Theme.of(context).textTheme.bodyLarge)
                else ...[
                  _Line(label: 'Statut', value: active.statusLabel),
                  _Line(label: 'Début', value: formatDate(active.startsAt)),
                  _Line(label: 'Fin', value: formatDate(active.endsAt)),
                  _Line(label: 'Obtenu par', value: active.sourceLabel),
                  const _Line(label: 'Renouvellement', value: 'Aucun renouvellement automatique'),
                ],
              ]),
            ),
            const SizedBox(height: 18),
            const SectionTitle('Historique'),
            if (grants.isEmpty)
              Text('Aucun abonnement pour le moment.', style: Theme.of(context).textTheme.bodyMedium)
            else
              for (final g in grants)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ZColors.line),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Premium · ${g.sourceLabel}', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text('Du ${formatDate(g.startsAt)} au ${formatDate(g.endsAt)}',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ]),
                    ),
                    _StatusChip(label: g.statusLabel, positive: g.isActive),
                  ]),
                ),
            const SizedBox(height: 8),
            Text(
              'Les dates sont affichées dans le fuseau horaire de votre téléphone. '
              'Un abonnement offert n’est jamais compté comme un paiement.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ]);
        },
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 120, child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Expanded(
            child: Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: ZColors.ink)),
          ),
        ]),
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.positive, this.negative = false});
  final String label;
  final bool positive;
  final bool negative;

  @override
  Widget build(BuildContext context) {
    final color = positive ? ZColors.success : (negative ? ZColors.danger : ZColors.muted);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
      child: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

/// « Mes paiements » : opérations du membre, statut clairement distingué (V6.4 §39.4).
class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  late Future<List<PaymentTx>> _future = Session.read(context).repo.payments();

  String _amount(PaymentTx tx) {
    // Séparateur de milliers pour les montants en GNF (ex. 25 000 GNF).
    final whole = tx.amount.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(whole[i]);
    }
    return '$buffer ${tx.currency}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes paiements')),
      body: FutureBuilder<List<PaymentTx>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(padding: EdgeInsets.all(20), child: Skeleton(height: 90));
          }
          final items = snapshot.data;
          if (snapshot.hasError || items == null) {
            return EmptyState(
              icon: Icons.wifi_off,
              title: 'Connexion interrompue',
              message: 'Vos paiements ne peuvent pas être chargés.',
              action: FilledButton(
                onPressed: () => setState(() => _future = Session.read(context).repo.payments()),
                child: const Text('Réessayer'),
              ),
            );
          }
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Aucun paiement',
              message: 'Vos achats et leurs reçus apparaîtront ici. Aucun paiement n’est nécessaire pour utiliser '
                  'les fonctions essentielles de ZAYA.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final tx = items[i];
              return FadeSlideIn(
                index: i,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ZColors.line),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(tx.serviceLabel, style: Theme.of(context).textTheme.titleMedium)),
                      _StatusChip(
                        label: tx.statusLabel,
                        positive: tx.isConfirmed,
                        negative: tx.status == 'failed' || tx.status == 'cancelled' || tx.status == 'disputed',
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Text(_amount(tx), style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: ZColors.ink)),
                    const SizedBox(height: 4),
                    Text('${formatDate(tx.createdAt)} à ${formatTime(tx.createdAt)} · ${tx.method}',
                        style: Theme.of(context).textTheme.bodyMedium),
                    Text('Référence : ${tx.reference}', style: Theme.of(context).textTheme.bodyMedium),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
