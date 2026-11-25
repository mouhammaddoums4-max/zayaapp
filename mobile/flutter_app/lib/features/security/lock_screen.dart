import 'dart:async';

import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import 'app_lock.dart';

/// Recouvre toute l'application tant qu'elle est verrouillée (placé dans MaterialApp.builder) : les écrans ouverts
/// restent en place derrière, invisibles et inaccessibles, jusqu'au déverrouillage.
class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.child, required this.signedIn, required this.onForgot, this.lock});
  final Widget child;

  /// Le verrouillage ne concerne qu'un membre connecté.
  final bool signedIn;

  /// « Code oublié ? » : désactive le verrouillage puis déconnecte (reconnexion par le numéro).
  final Future<void> Function() onForgot;
  final AppLock? lock;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> {
  late final AppLock _lock = widget.lock ?? AppLock.instance;

  @override
  void initState() {
    super.initState();
    _lock.load();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _lock,
        builder: (context, child) {
          // Ne recouvre que si le verrouillage est réellement actif : jamais pendant l'inscription, ni avant le choix
          // d'un code, ni si le stockage sécurisé est indisponible.
          final covered = widget.signedIn && _lock.loaded && _lock.enabled && _lock.locked;
          return Stack(children: [
            // Contenu masqué aux lecteurs d'écran et aux appuis tant que l'application est verrouillée.
            ExcludeSemantics(excluding: covered, child: AbsorbPointer(absorbing: covered, child: child)),
            if (covered) Positioned.fill(child: _LockLayer(lock: _lock, onForgot: widget.onForgot)),
          ]);
        },
        child: widget.child,
      );
}

/// L'écran verrouillé est placé au-dessus du navigateur de l'application : il reçoit sa propre couche (Overlay)
/// pour les info-bulles et les effets des boutons.
class _LockLayer extends StatefulWidget {
  const _LockLayer({required this.lock, required this.onForgot});
  final AppLock lock;
  final Future<void> Function() onForgot;

  @override
  State<_LockLayer> createState() => _LockLayerState();
}

class _LockLayerState extends State<_LockLayer> {
  late final OverlayEntry _entry =
      OverlayEntry(builder: (_) => LockScreen(lock: widget.lock, onForgot: widget.onForgot));

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_entry]);
}

/// Écran de déverrouillage : code à 4 chiffres, empreinte ou visage si activés.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.lock, required this.onForgot});
  final AppLock lock;
  final Future<void> Function() onForgot;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _pin = '';
  String? _error;
  bool _checking = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _startTicker();
    // La biométrie est proposée d'emblée, comme le font les applications bancaires.
    if (widget.lock.biometrics) WidgetsBinding.instance.addPostFrameCallback((_) => _device());
  }

  void _startTicker() {
    _ticker?.cancel();
    if (widget.lock.waitRemaining == null) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() {});
      if (widget.lock.waitRemaining == null) t.cancel();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _device() async {
    if (!mounted) return;
    await widget.lock.unlockWithDevice(context.s.lockReason);
  }

  Future<void> _digit(String d) async {
    if (_checking || widget.lock.waitRemaining != null || _pin.length >= AppLock.pinLength) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length < AppLock.pinLength) return;
    setState(() => _checking = true);
    final ok = await widget.lock.verifyPin(_pin);
    if (!mounted || ok) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _checking = false;
      _pin = '';
      _error = context.s.lockWrongPin;
    });
    _startTicker();
  }

  void _erase() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  // L'écran recouvre le navigateur de l'application : la confirmation s'affiche dans l'écran lui-même.
  bool _confirmForgot = false;

  Widget _forgotPanel(BuildContext context) {
    final s = context.s;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(children: [
        Text(s.lockForgot, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(s.lockForgotBody, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 14),
        // Boutons l'un sous l'autre : le thème leur donne toute la largeur.
        FilledButton(onPressed: widget.onForgot, child: Text(s.lockForgotConfirm)),
        const SizedBox(height: 4),
        TextButton(onPressed: () => setState(() => _confirmForgot = false), child: Text(s.cancel)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final wait = widget.lock.waitRemaining;
    final message = wait != null ? s.lockWait(wait.inSeconds + 1) : _error;
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Image.asset('assets/brand/zaya_logo.png', width: 72, height: 72, semanticLabel: 'ZAYA'),
                  const SizedBox(height: 18),
                  Text(s.lockTitle, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Text(s.lockEnterPin, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 22),
                  PinDots(filled: _pin.length),
                  SizedBox(
                    height: 40,
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: ZMotion.of(context, ZMotion.fast),
                        child: message == null
                            ? const SizedBox.shrink()
                            : Text(message,
                                key: ValueKey<String>(message),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(fontSize: 13, color: ZColors.danger)),
                      ),
                    ),
                  ),
                  // « Code oublié ? » remplace le pavé par l'explication et la confirmation.
                  if (_confirmForgot)
                    _forgotPanel(context)
                  else ...[
                    PinPad(
                      onDigit: _digit,
                      onErase: _erase,
                      deviceButton: widget.lock.biometrics
                          ? IconButton(
                              tooltip: s.lockUseDevice,
                              iconSize: 30,
                              onPressed: _device,
                              icon: const Icon(Icons.fingerprint, color: ZColors.primary),
                            )
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextButton(onPressed: () => setState(() => _confirmForgot = true), child: Text(s.lockForgot)),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Points du code : pleins au fur et à mesure de la saisie.
class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.filled});
  final int filled;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '$filled / ${AppLock.pinLength}',
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < AppLock.pinLength; i++)
            AnimatedContainer(
              duration: ZMotion.of(context, ZMotion.fast),
              margin: const EdgeInsets.symmetric(horizontal: 9),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < filled ? ZColors.primary : Colors.transparent,
                border: Border.all(color: i < filled ? ZColors.primary : ZColors.muted, width: 1.6),
              ),
            ),
        ]),
      );
}

/// Pavé numérique (0 à 9), effacement et, si activé, bouton empreinte ou visage.
class PinPad extends StatelessWidget {
  const PinPad({super.key, required this.onDigit, required this.onErase, this.deviceButton});
  final ValueChanged<String> onDigit;
  final VoidCallback onErase;
  final Widget? deviceButton;

  Widget _key(BuildContext context, String d) => SizedBox(
        width: 76,
        height: 76,
        child: Material(
          color: ZColors.primarySoft,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => onDigit(d),
            child: Center(
              child: Text(d, style: GoogleFonts.sora(fontSize: 26, fontWeight: FontWeight.w600, color: ZColors.ink)),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    Widget row(List<Widget> keys) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: keys),
        );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Column(children: [
        row([_key(context, '1'), _key(context, '2'), _key(context, '3')]),
        row([_key(context, '4'), _key(context, '5'), _key(context, '6')]),
        row([_key(context, '7'), _key(context, '8'), _key(context, '9')]),
        row([
          SizedBox(width: 76, height: 76, child: Center(child: deviceButton)),
          _key(context, '0'),
          SizedBox(
            width: 76,
            height: 76,
            child: IconButton(
              tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              onPressed: onErase,
              icon: const Icon(Icons.backspace_outlined, color: ZColors.muted),
            ),
          ),
        ]),
      ]),
    );
  }
}
