import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../discovery/profile_widgets.dart';
import '../premium/premium_screens.dart';
import '../safety/safety_sheets.dart';
import 'edit_profile_screen.dart';
import 'preferences_screen.dart';
import 'privacy_center_screen.dart';
import 'verification_screen.dart';

/// Onglet Profil : mon profil, sa complétude, la vérification et l'accès aux réglages.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(zRoute<void>(screen));

  Future<void> _openPreferences(BuildContext context) async {
    final feed = Session.read(context).feed;
    final changed = await Navigator.of(context).push<bool>(zRoute<bool>(const PreferencesScreen()));
    if (changed == true) feed.load();
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final session = Session.read(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text('Vous pourrez vous reconnecter à tout moment avec votre numéro de téléphone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Se déconnecter')),
        ],
      ),
    );
    if (ok == true) await session.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final session = Session.of(context);
    final me = session.me;
    if (me == null) return const SizedBox.shrink();
    final deletion = me.deletionScheduledFor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shield_outlined),
            tooltip: 'Confidentialité et sécurité',
            onPressed: () => _push(context, const PrivacyCenterScreen()),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
        FadeSlideIn(child: _Header(me: me, onEdit: () => _push(context, const EditProfileScreen()))),
        const SizedBox(height: 14),
        if (deletion != null) ...[
          InfoBanner(
            tone: BannerTone.danger,
            icon: Icons.delete_outline,
            text: 'Suppression du compte prévue le ${formatDate(deletion)}. Votre profil n’est plus proposé aux autres membres.',
            action: TextButton(
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero, minimumSize: const Size(0, 32), foregroundColor: ZColors.danger),
              onPressed: () => _push(context, const PrivacyCenterScreen()),
              child: const Text('Gérer ma demande  →', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (!me.isVerified) ...[
          FadeSlideIn(
            index: 1,
            child: _ActionCard(
              icon: Icons.verified_outlined,
              color: ZColors.verified,
              title: me.verificationStatus == 'pending' ? 'Vérification en cours' : 'Faites vérifier votre profil',
              text: me.verificationStatus == 'pending'
                  ? 'Notre équipe examine votre demande. Vous serez prévenu dès qu’elle sera traitée.'
                  : 'La vérification est nécessaire pour apparaître dans la découverte : 3 photos et un selfie de contrôle.',
              actionLabel: me.verificationStatus == 'pending' ? 'Voir le statut' : 'Commencer',
              onTap: () => _push(context, const VerificationScreen()),
            ),
          ),
          const SizedBox(height: 12),
        ],
        FadeSlideIn(
          index: 2,
          child: _ActionCard(
            icon: Icons.workspace_premium_outlined,
            color: ZColors.premium,
            title: me.isPremium ? 'Vous êtes Premium' : 'ZAYA Premium',
            text: me.isPremium
                ? 'Consultez vos avantages et la date de fin de votre abonnement.'
                : 'Voyez qui vous a aimé et accédez à des filtres avancés. Les fonctions essentielles restent gratuites.',
            actionLabel: me.isPremium ? 'Mon abonnement' : 'Comparer les offres',
            onTap: () => _push(context, me.isPremium ? const SubscriptionsScreen() : const PremiumScreen()),
          ),
        ),
        const SizedBox(height: 18),
        const SectionTitle('Mon profil'),
        _MenuGroup(children: [
          _MenuTile(
              icon: Icons.edit_outlined,
              title: 'Modifier mon profil',
              subtitle: 'Présentation, projet de mariage, langues, centres d’intérêt',
              onTap: () => _push(context, const EditProfileScreen())),
          _MenuTile(
              icon: Icons.tune,
              title: 'Préférences de découverte',
              subtitle: 'Âge recherché, préférence confessionnelle',
              onTap: () => _openPreferences(context)),
          _MenuTile(
              icon: Icons.verified_outlined,
              title: 'Vérification du profil',
              subtitle: _verificationLabel(me.verificationStatus),
              onTap: () => _push(context, const VerificationScreen())),
        ]),
        const SizedBox(height: 18),
        const SectionTitle('Compte'),
        _MenuGroup(children: [
          _MenuTile(
              icon: Icons.lock_outline,
              title: 'Confidentialité et sécurité',
              subtitle: 'Visibilité, personnes bloquées, mes données',
              onTap: () => _push(context, const PrivacyCenterScreen())),
          _MenuTile(
              icon: Icons.card_membership_outlined,
              title: 'Mes abonnements',
              subtitle: me.isPremium ? 'Premium' : 'Offre Gratuit',
              onTap: () => _push(context, const SubscriptionsScreen())),
          _MenuTile(
              icon: Icons.receipt_long_outlined,
              title: 'Mes paiements',
              subtitle: 'Historique et reçus',
              onTap: () => _push(context, const PaymentsScreen())),
          _MenuTile(
              icon: Icons.health_and_safety_outlined,
              title: 'Conseils de sécurité',
              subtitle: 'Rencontres, arnaques, signalement',
              onTap: () => _push(context, const SafetyTipsScreen())),
        ]),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: () => _confirmSignOut(context),
          icon: const Icon(Icons.logout, size: 20),
          label: const Text('Se déconnecter'),
        ),
        if (session.repo.isDemo) ...[
          const SizedBox(height: 14),
          Text('Mode démo — données fictives, rien n’est enregistré.',
              textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ]),
    );
  }

  static String _verificationLabel(String status) => switch (status) {
        'approved' => 'Profil vérifié',
        'pending' => 'En cours d’examen',
        'more_info_required' => 'Informations complémentaires demandées',
        'rejected' => 'Demande refusée — vous pouvez réessayer',
        'redo' => 'À refaire',
        _ => 'Non vérifié',
      };
}

/// En-tête : avatar entouré d'un anneau de complétude qui se remplit à l'ouverture.
class _Header extends StatelessWidget {
  const _Header({required this.me, required this.onEdit});
  final MyProfile me;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final percent = (me.completeness * 100).round();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ZColors.line),
      ),
      child: Row(children: [
        SizedBox(
          width: 104,
          height: 104,
          child: Stack(alignment: Alignment.center, children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: me.completeness),
              duration: ZMotion.of(context, const Duration(milliseconds: 900)),
              curve: ZMotion.emphasized,
              builder: (context, value, _) => SizedBox(
                width: 104,
                height: 104,
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: 5,
                  strokeCap: StrokeCap.round,
                  backgroundColor: ZColors.line,
                  color: ZColors.primary,
                  semanticsLabel: 'Complétude du profil',
                  semanticsValue: '$percent %',
                ),
              ),
            ),
            RemoteAvatar(name: me.displayName, photoPath: me.mainPhotoPath, size: 86),
          ]),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(me.age == null ? me.displayName : '${me.displayName}, ${me.age}',
                    overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleLarge),
              ),
              if (me.isVerified) ...[const SizedBox(width: 6), const VerifiedBadge()],
            ]),
            if (me.city != null) ...[
              const SizedBox(height: 2),
              Text(me.city!, style: Theme.of(context).textTheme.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              if (me.isPremium) const PremiumBadge(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: ZColors.primarySoft, borderRadius: BorderRadius.circular(99)),
                child: Text('Profil complété à $percent %',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: ZColors.primaryDark)),
              ),
            ]),
            const SizedBox(height: 6),
            TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
              onPressed: onEdit,
              child: Text(percent < 100 ? 'Compléter mon profil  →' : 'Modifier mon profil  →',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
    required this.actionLabel,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String text;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: ZColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(text, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Text('$actionLabel  →',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: ZColors.primaryDark)),
                ]),
              ),
            ]),
          ),
        ),
      );
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: ZColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(indent: 60),
            children[i],
          ],
        ]),
      );
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(icon, color: ZColors.primaryDark),
        title: Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: ZColors.ink)),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right, color: ZColors.muted),
        onTap: onTap,
      );
}
