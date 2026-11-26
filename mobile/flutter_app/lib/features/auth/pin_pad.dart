import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/motion.dart';
import '../../core/theme.dart';

/// Clavier à code à 4 chiffres : quatre points, pavé numérique, effacement. Le code est remis dès le 4ᵉ chiffre.
/// `shake()` signale une erreur (secousse et vibration) et efface la saisie.
class PinPad extends StatefulWidget {
  const PinPad({super.key, required this.onCompleted, this.enabled = true, this.length = 4});
  final ValueChanged<String> onCompleted;
  final bool enabled;
  final int length;

  @override
  State<PinPad> createState() => PinPadState();
}

class PinPadState extends State<PinPad> with SingleTickerProviderStateMixin {
  String _value = '';
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  /// Erreur : la rangée de points tremble, le téléphone vibre, la saisie est effacée.
  void shake() {
    HapticFeedback.heavyImpact();
    setState(() => _value = '');
    if (!ZMotion.reduced(context)) _shake.forward(from: 0);
  }

  void clear() => setState(() => _value = '');

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _tap(String digit) {
    if (!widget.enabled || _value.length >= widget.length) return;
    HapticFeedback.selectionClick();
    setState(() => _value += digit);
    if (_value.length == widget.length) {
      final code = _value;
      // Le dernier point se remplit avant l'envoi : l'appui est bien visible.
      Future<void>.delayed(const Duration(milliseconds: 90), () {
        if (mounted) widget.onCompleted(code);
      });
    }
  }

  void _erase() {
    if (!widget.enabled || _value.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _value = _value.substring(0, _value.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      AnimatedBuilder(
        animation: _shake,
        builder: (context, child) => Transform.translate(
          offset: Offset(math.sin(_shake.value * math.pi * 6) * 12 * (1 - _shake.value), 0),
          child: child,
        ),
        child: Semantics(
          label:
              '${_value.length} chiffre${_value.length > 1 ? 's' : ''} saisi${_value.length > 1 ? 's' : ''} sur ${widget.length}',
          liveRegion: true,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < widget.length; i++)
              // Boîte de taille fixe : le point grossit à l'intérieur sans changer la mise en page, sinon tout
              // l'écran centré bougeait à chaque chiffre (« l'écran tremble et se décale », 25/11/2026).
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 11),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: Center(
                    child: AnimatedContainer(
                      duration: ZMotion.of(context, ZMotion.fast),
                      curve: Curves.easeOut,
                      width: i < _value.length ? 18 : 16,
                      height: i < _value.length ? 18 : 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _value.length ? ZColors.primary : Colors.transparent,
                        border: Border.all(color: i < _value.length ? ZColors.primary : ZColors.muted, width: 2),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
      const SizedBox(height: 34),
      for (final row in const [
        ['1', '2', '3'],
        ['4', '5', '6'],
        ['7', '8', '9'],
        ['', '0', '<'],
      ])
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (final key in row)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: key.isEmpty
                    ? const SizedBox(width: 72, height: 72)
                    : key == '<'
                        ? _Key(
                            label: 'Effacer',
                            onTap: _erase,
                            child: const Icon(Icons.backspace_outlined, size: 26, color: ZColors.ink),
                          )
                        : _Key(
                            label: key,
                            onTap: () => _tap(key),
                            filled: true,
                            child: Text(key,
                                style: GoogleFonts.sora(fontSize: 28, fontWeight: FontWeight.w600, color: ZColors.ink)),
                          ),
              ),
          ]),
        ),
    ]);
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.onTap, required this.child, this.filled = false});
  final String label;
  final VoidCallback onTap;
  final Widget child;
  final bool filled;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: filled ? const Color(0xFFF2F2F5) : Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(width: 72, height: 72, child: Center(child: child)),
          ),
        ),
      );
}
