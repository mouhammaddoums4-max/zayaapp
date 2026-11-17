import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import 'motion.dart';
import 'theme.dart';

class ZTabItem {
  const ZTabItem({required this.icon, required this.activeIcon, required this.label});
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Barre d'onglets ZAYA : pastille qui s'élargit, icône qui se remplit et rebondit, libellé qui s'affirme.
class ZayaTabBar extends StatelessWidget {
  const ZayaTabBar({
    super.key,
    required this.index,
    required this.onChanged,
    required this.items,
    this.badges = const <int, int>{},
  });

  final int index;
  final ValueChanged<int> onChanged;
  final List<ZTabItem> items;

  /// Compteurs par position d'onglet (0 = pas de pastille).
  final Map<int, int> badges;

  @override
  Widget build(BuildContext context) {
    // La barre système du téléphone prend la couleur de la barre d'onglets (voir zSystemNavigationBarStyle).
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: zSystemNavigationBarStyle,
      child: _bar(context),
    );
  }

  Widget _bar(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const Border(top: BorderSide(color: ZColors.line)),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _TabButton(
                  item: items[i],
                  selected: i == index,
                  badge: badges[i] ?? 0,
                  onTap: () => onChanged(i),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.item, required this.selected, required this.badge, required this.onTap});
  final ZTabItem item;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final duration = ZMotion.of(context, ZMotion.medium);
    final color = selected ? ZColors.primaryDark : ZColors.muted;
    return Semantics(
      button: true,
      selected: selected,
      label: badge > 0 ? '${item.label}, $badge nouveautés' : item.label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 40,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(
            width: 64,
            height: 32,
            child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
              AnimatedContainer(
                duration: duration,
                curve: ZMotion.emphasized,
                width: selected ? 58 : 28,
                height: 32,
                decoration: BoxDecoration(
                  color: selected ? ZColors.primarySoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              AnimatedScale(
                scale: selected ? 1.12 : 1,
                duration: duration,
                curve: ZMotion.spring,
                child: AnimatedSwitcher(
                  duration: duration,
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: Tween<double>(begin: 0.7, end: 1).animate(animation),
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: Icon(
                    selected ? item.activeIcon : item.icon,
                    key: ValueKey<bool>(selected),
                    color: color,
                    size: 24,
                  ),
                ),
              ),
              if (badge > 0)
                Positioned(
                  top: -3,
                  right: 6,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: ZColors.primary,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white, height: 1.2),
                    ),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: duration,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
            child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ]),
      ),
    );
  }
}
