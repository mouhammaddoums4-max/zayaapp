import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import 'motion.dart';
import 'theme.dart';

/// Logo officiel ZAYA (assets/brand/zaya_logo.png).
class ZayaLogo extends StatelessWidget {
  const ZayaLogo({super.key, this.size = 96});
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: Image.asset(
          'assets/brand/zaya_logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          // Décodage à la taille d'affichage : économise la mémoire sur les téléphones modestes.
          cacheWidth: (size * 3).round(),
          semanticLabel: 'Logo ZAYA',
        ),
      );
}

/// Badge bleu « Profil vérifié » — distinct du badge Premium (V6.4 §41).
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.size = 20});
  final double size;

  @override
  Widget build(BuildContext context) => Tooltip(
        message:
            'Profil vérifié : contrôle photo/selfie réussi. Ce badge ne garantit pas les intentions de la personne.',
        child: Icon(Icons.verified, color: ZColors.verified, size: size, semanticLabel: 'Profil vérifié'),
      );
}

class PremiumBadge extends StatelessWidget {
  const PremiumBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: ZColors.premium, borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.workspace_premium, size: 13, color: Colors.white),
          const SizedBox(width: 3),
          Text('Premium', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
        ]),
      );
}

/// Bouton principal avec dégradé de marque.
class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.label, required this.onPressed, this.icon, this.busy = false});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return AnimatedOpacity(
      opacity: enabled || busy ? 1 : 0.45,
      duration: ZMotion.of(context, ZMotion.fast),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(gradient: ZColors.brandGradient, borderRadius: BorderRadius.circular(14)),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              height: 54,
              child: Center(
                child: busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        if (icon != null) ...[Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 8)],
                        Text(label,
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                      ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ligne de choix (sélection simple ou multiple) avec transition de couleur.
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
  });
  final String label;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Semantics(
          button: true,
          selected: selected,
          child: AnimatedContainer(
            duration: ZMotion.of(context, ZMotion.fast),
            decoration: BoxDecoration(
              color: selected ? ZColors.primarySoft : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? ZColors.primary : ZColors.line, width: selected ? 1.5 : 1),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(children: [
                    if (icon != null) ...[
                      Icon(icon, size: 22, color: selected ? ZColors.primaryDark : ZColors.muted),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(label,
                            style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: selected ? ZColors.primaryDark : ZColors.ink)),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Icon(selected ? Icons.check_circle : Icons.circle_outlined,
                        color: selected ? ZColors.primary : ZColors.line),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}

/// Champ de sélection qui ouvre une liste en bas d'écran (adapté au pouce, sans menu déroulant).
class ZPickerField<T> extends StatelessWidget {
  const ZPickerField({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final Map<T, String> options;
  final T? value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final current = value == null ? null : options[value];
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final picked = await showModalBottomSheet<T>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (sheetContext) => SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * 0.7),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 12),
                    child: Text(label, style: Theme.of(sheetContext).textTheme.titleLarge),
                  ),
                  for (final e in options.entries)
                    ChoiceTile(
                      label: e.value,
                      selected: e.key == value,
                      onTap: () => Navigator.of(sheetContext).pop(e.key),
                    ),
                ],
              ),
            ),
          ),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        isEmpty: current == null,
        decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.expand_more)),
        child: current == null
            ? null
            : Text(current, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: ZColors.ink)),
      ),
    );
  }
}

/// Étiquette arrondie (langues, centres d'intérêt, informations de profil).
class ZTag extends StatelessWidget {
  const ZTag(this.label, {super.key, this.icon, this.onDark = false, this.highlighted = false});
  final String label;
  final IconData? icon;
  final bool onDark;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final background =
        onDark ? Colors.white.withValues(alpha: 0.18) : (highlighted ? ZColors.primarySoft : Colors.white);
    final foreground = onDark ? Colors.white : (highlighted ? ZColors.primaryDark : ZColors.ink);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
        border: onDark ? null : Border.all(color: highlighted ? ZColors.primarySoft : ZColors.line),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 15, color: foreground), const SizedBox(width: 6)],
        Flexible(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: foreground)),
        ),
      ]),
    );
  }
}

/// Avatar rond : photo si disponible, sinon dégradé de marque avec l'initiale.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.name, this.url, this.size = 52});
  final String name;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    final placeholder = DecoratedBox(
      decoration: const BoxDecoration(gradient: ZColors.brandGradient),
      child: Center(
        child: Text(initial,
            style: GoogleFonts.sora(fontSize: size * 0.42, fontWeight: FontWeight.w700, color: Colors.white)),
      ),
    );
    final photo = url;
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: photo == null
            ? placeholder
            : Image.network(photo, fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
        child: Row(children: [
          Expanded(child: Text(text, style: Theme.of(context).textTheme.titleMedium)),
          if (trailing != null) trailing!,
        ]),
      );
}

/// Occupe toute la hauteur disponible quand le contenu tient à l'écran (les `Spacer` répartissent
/// alors l'espace), et devient défilant sinon : petit écran, grande taille de texte.
class FillOrScroll extends StatelessWidget {
  const FillOrScroll({super.key, required this.child, this.padding = EdgeInsets.zero});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(child: Padding(padding: padding, child: child)),
          ),
        ),
      );
}

/// Bandeau d'information (ton neutre, avertissement ou erreur).
class InfoBanner extends StatelessWidget {
  const InfoBanner(
      {super.key, required this.text, this.icon = Icons.info_outline, this.tone = BannerTone.info, this.action});
  final String text;
  final IconData icon;
  final BannerTone tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      BannerTone.info => (ZColors.primarySoft, ZColors.primaryDark),
      BannerTone.warning => (const Color(0xFFFFF4D6), const Color(0xFF5C4100)),
      BannerTone.danger => (ZColors.dangerSoft, ZColors.danger),
      BannerTone.success => (const Color(0xFFE3F5EE), ZColors.success),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: foreground, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(text, style: TextStyle(fontSize: 13, color: foreground, height: 1.4, fontWeight: FontWeight.w500)),
            if (action != null) action!,
          ]),
        ),
      ]),
    );
  }
}

enum BannerTone { info, warning, danger, success }

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.action});
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: FadeSlideIn(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(color: ZColors.primarySoft, shape: BoxShape.circle),
                child: Icon(icon, size: 38, color: ZColors.primary),
              ),
              const SizedBox(height: 20),
              Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(message, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
              if (action != null) ...[const SizedBox(height: 20), action!],
            ]),
          ),
        ),
      );
}

void showZayaSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? ZColors.danger : ZColors.ink,
    ));
}

/// Messages compréhensibles pour les erreurs connues du serveur ; jamais de détail technique affiché.
const _knownErrors = <String, String>{
  'AGE_MINIMUM_18': 'ZAYA est réservé aux personnes de 18 ans et plus.',
  'PROFILE_NOT_ACTIVE': 'Votre profil doit être actif pour effectuer cette action.',
  'TARGET_UNAVAILABLE': 'Ce profil n’est plus disponible.',
  'PROFILE_NOT_FOUND': 'Ce profil n’est plus disponible.',
  'MATCH_ENDED': 'Cette conversation est terminée.',
  'MATCH_NOT_FOUND': 'Cette conversation est terminée.',
  'EDIT_WINDOW_EXPIRED': 'Le délai pour modifier ce message est dépassé.',
  'UNSEND_NOT_ALLOWED': 'Le délai pour annuler ce message est dépassé.',
  'BIOMETRIC_CONSENT_REQUIRED': 'Votre accord est nécessaire pour la vérification par selfie.',
  'PREMIUM_REQUIRED': 'Cette fonction fait partie de ZAYA Premium.',
  'STATUS_CHANGE_NOT_ALLOWED': 'Ce changement n’est pas possible pour votre compte. Contactez l’assistance.',
  'NO_DELETION_REQUEST': 'Aucune demande de suppression en cours.',
  'otp_expired': 'Code incorrect ou expiré. Demandez un nouveau code.',
  'Token has expired or is invalid': 'Code incorrect ou expiré. Demandez un nouveau code.',
  'over_sms_send_rate_limit': 'Trop de demandes de code. Réessayez dans quelques minutes.',
  'sms_send_failed': 'Le SMS n’a pas pu être envoyé. Réessayez dans quelques minutes.',
  'phone_provider_disabled': 'La connexion par téléphone n’est pas encore activée sur le serveur.',
  'Unsupported phone provider': 'La connexion par téléphone n’est pas encore activée sur le serveur.',
  // Communauté
  'COMMUNITY_DISABLED': 'La communauté ouvrira bientôt.',
  'VERIFICATION_REQUIRED': 'Pour publier ou commenter, votre profil doit d’abord être vérifié.',
  'ACCOUNT_RESTRICTED': 'Votre compte ne peut pas publier pour le moment. Contactez l’assistance.',
  'RATE_LIMITED': 'Vous avez beaucoup publié récemment. Réessayez un peu plus tard.',
  'COMMENTS_DISABLED': 'Les commentaires sont désactivés sur cette publication.',
  'POST_NOT_FOUND': 'Cette publication n’est plus disponible.',
  'COMMENT_NOT_FOUND': 'Ce commentaire n’est plus disponible.',
  'COMMUNITY_NOT_FOUND': 'Cette communauté n’est plus disponible.',
  'NOT_A_MEMBER': 'Rejoignez d’abord cette communauté.',
};

String friendlyError(Object error) {
  final raw = error.toString();
  for (final entry in _knownErrors.entries) {
    if (raw.contains(entry.key)) return entry.value;
  }
  if (raw.startsWith('Exception: ')) return raw.substring('Exception: '.length);
  return 'Une erreur est survenue. Vérifiez votre connexion et réessayez.';
}
