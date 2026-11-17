import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme.dart';

/// Groupe de lignes de réglages sur fond blanc, séparées par un trait.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});
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

/// Ligne de réglage : icône, titre, valeur ou explication, chevron.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) => ListTile(
        enabled: enabled,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(icon, color: enabled ? ZColors.primaryDark : ZColors.muted),
        title: Text(title,
            style: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w600, color: enabled ? ZColors.ink : ZColors.muted)),
        subtitle: subtitle == null ? null : Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: trailing ?? (onTap == null ? null : const Icon(Icons.chevron_right, color: ZColors.muted)),
        onTap: onTap,
      );
}

/// Titre de section des réglages, en grand comme dans la convention retenue (CARTE_ECRANS §7.1).
class SettingsSectionTitle extends StatelessWidget {
  const SettingsSectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
        child: Text(text, style: Theme.of(context).textTheme.titleLarge),
      );
}
