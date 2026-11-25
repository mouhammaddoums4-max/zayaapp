import 'dart:async';

import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../onboarding/phone_login_screen.dart' show PhoneOtpForm;
import '../security/app_lock.dart';
import 'pin_pad.dart';

/// Numéro affiché partiellement masqué (« +224 6•• •• 30 30 »).
String maskedPhone(String phone) {
  final d = phone.replaceAll(RegExp(r'\D'), '');
  final local = d.length > 9 ? d.substring(d.length - 9) : d;
  if (local.length < 9) return phone;
  return '+224 ${local[0]}•• •• ${local.substring(5, 7)} ${local.substring(7)}';
}

/// Après une connexion ou un changement de code réussi : le verrou local (empreinte, visage) retient le même code
/// (un seul code pour tout, décision partagée avec la session « verrouillage »).
/// Sans attendre : le stockage sécurisé du téléphone peut être lent ou absent, la connexion n'en dépend pas.
void _rememberForLock(String pin) {
  unawaited(AppLock.instance.rememberLoginCode(pin).then((_) {}, onError: (Object _) {
    // Verrou local indisponible (simulateur, test) : la connexion reste valable.
  }));
}

/// Connexion par numéro + code à 4 chiffres (0071). « Code oublié ? » passe par une vérification SMS.
class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({super.key, required this.phone});
  final String phone;

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  final _pad = GlobalKey<PinPadState>();
  bool _busy = false;
  String? _message;

  String _hour(DateTime t) {
    final l = t.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _submit(String pin) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final session = Session.read(context);
    final nav = Navigator.of(context);
    try {
      final r = await session.repo.signInWithPin(widget.phone, pin);
      if (!mounted) return;
      if (r.ok) {
        _rememberForLock(pin);
        await session.refresh();
        if (r.mustChange) {
          // Code imposé (6236) : remplacé tout de suite par un code personnel.
          await nav.pushReplacement(MaterialPageRoute<void>(
            builder: (_) => PinSetupScreen(mode: PinSetupMode.change, oldPin: pin, forced: true),
          ));
        } else {
          nav.popUntil((route) => route.isFirst);
        }
        return;
      }
      _pad.currentState?.shake();
      setState(() {
        _message = switch (r.status) {
          'wrong' => (r.remaining ?? 0) <= 1
              ? 'Code incorrect. Dernier essai avant le blocage temporaire.'
              : 'Code incorrect. Encore ${r.remaining} essais avant le blocage temporaire.',
          'locked' => r.lockedUntil == null
              ? 'Trop d’erreurs : votre compte est bloqué un moment. Vous pouvez réinitialiser votre code.'
              : 'Trop d’erreurs : réessayez après ${_hour(r.lockedUntil!)}, ou réinitialisez votre code.',
          'rate_limited' => 'Trop de tentatives depuis ce réseau. Réessayez dans un moment.',
          'disabled' => 'La connexion par code est momentanément indisponible : utilisez « Code oublié ? ».',
          'unknown' || 'no_pin' => 'Ce numéro n’a pas encore de code : utilisez « Code oublié ? » pour en créer un.',
          _ => 'Connexion impossible pour le moment. Vérifiez votre connexion et réessayez.',
        };
      });
    } catch (e) {
      _pad.currentState?.shake();
      if (mounted) setState(() => _message = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(children: [
                Text('Entrez votre code', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(maskedPhone(widget.phone), style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 28),
                PinPad(key: _pad, enabled: !_busy, onCompleted: _submit),
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: _busy
                      ? const Center(
                          child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4)))
                      : _message == null
                          ? null
                          : Text(_message!,
                              textAlign: TextAlign.center,
                              style:
                                  GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: ZColors.danger)),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(context)
                          .push(MaterialPageRoute<void>(builder: (_) => PinResetScreen(phone: widget.phone))),
                  child: const Text('Code oublié ?'),
                ),
              ]),
            ),
          ),
        ),
      );
}

enum PinSetupMode { create, change, reset }

/// Choix d'un code à 4 chiffres : création (après l'inscription), changement (ancien code exigé) ou
/// réinitialisation (juste après une vérification SMS). `forced` : impossible de revenir en arrière.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key, required this.mode, this.oldPin, this.forced = false});
  final PinSetupMode mode;
  final String? oldPin;
  final bool forced;

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final _pad = GlobalKey<PinPadState>();
  late String? _old = widget.oldPin;
  String? _first;
  bool _busy = false;
  String? _message;

  static bool _weak(String p) =>
      RegExp(r'^(.)\1{3}$').hasMatch(p) ||
      const {
        '0123',
        '1234',
        '2345',
        '3456',
        '4567',
        '5678',
        '6789',
        '9876',
        '8765',
        '7654',
        '6543',
        '5432',
        '4321',
        '3210'
      }.contains(p);

  bool get _askOld => widget.mode == PinSetupMode.change && _old == null;

  String get _title {
    if (_askOld) return 'Votre code actuel';
    if (_first != null) return 'Confirmez votre code';
    return widget.mode == PinSetupMode.create ? 'Choisissez votre code' : 'Choisissez un nouveau code';
  }

  String get _hint {
    if (_askOld) return 'Pour changer de code, entrez d’abord celui que vous utilisez aujourd’hui.';
    if (_first != null) return 'Entrez-le une seconde fois.';
    return 'Quatre chiffres, faciles à retenir pour vous mais pas évidents (évitez 1234 ou 0000). '
        'Il vous servira à vous connecter, sans SMS.';
  }

  Future<void> _onCode(String pin) async {
    if (_askOld) {
      setState(() {
        _old = pin;
        _message = null;
      });
      _pad.currentState?.clear();
      return;
    }
    if (_first == null) {
      if (_weak(pin)) {
        _pad.currentState?.shake();
        setState(() => _message = 'Ce code est trop facile à deviner. Choisissez-en un autre.');
        return;
      }
      if (widget.mode == PinSetupMode.change && pin == _old) {
        _pad.currentState?.shake();
        setState(() => _message = 'Choisissez un code différent de l’ancien.');
        return;
      }
      setState(() {
        _first = pin;
        _message = null;
      });
      _pad.currentState?.clear();
      return;
    }
    if (pin != _first) {
      _pad.currentState?.shake();
      setState(() {
        _first = null;
        _message = 'Les deux codes ne sont pas identiques. Recommencez.';
      });
      return;
    }
    await _save(pin);
  }

  Future<void> _save(String pin) async {
    setState(() => _busy = true);
    final session = Session.read(context);
    final nav = Navigator.of(context);
    try {
      switch (widget.mode) {
        case PinSetupMode.create:
          await session.repo.setPin(pin);
        case PinSetupMode.change:
          await session.repo.changePin(_old!, pin);
        case PinSetupMode.reset:
          await session.repo.resetPin(pin);
      }
      _rememberForLock(pin);
      if (!mounted) return;
      if (widget.mode == PinSetupMode.change && !widget.forced) {
        // Depuis les réglages : confirmation, puis retour.
        showZayaSnack(context, 'Code enregistré. Vous vous connecterez désormais avec votre numéro et ce code.');
        nav.pop();
      } else {
        // Création, réinitialisation ou code imposé : l'arrivée dans l'application vaut confirmation (pas de
        // bandeau pendant la transition, il apparaîtrait sur deux écrans à la fois).
        await session.refresh();
        nav.popUntil((route) => route.isFirst);
      }
    } catch (e) {
      _pad.currentState?.shake();
      if (!mounted) return;
      final text = e.toString();
      setState(() {
        if (text.contains('PIN_WRONG')) {
          _old = null; // l'ancien code est redemandé
        }
        _first = null;
        _message = friendlyError(e);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !widget.forced,
        child: Scaffold(
          appBar: AppBar(automaticallyImplyLeading: !widget.forced),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(children: [
                  const Icon(Icons.lock_outline_rounded, size: 38, color: ZColors.primary),
                  const SizedBox(height: 12),
                  Text(_title, style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(_hint, style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
                  const SizedBox(height: 28),
                  PinPad(key: _pad, enabled: !_busy, onCompleted: _onCode),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: _busy
                        ? const Center(
                            child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4)))
                        : _message == null
                            ? null
                            : Text(_message!,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                    fontSize: 14, fontWeight: FontWeight.w600, color: ZColors.danger)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
}

/// Code oublié : vérification du numéro par SMS (code valable 5 minutes), puis choix d'un nouveau code.
class PinResetScreen extends StatelessWidget {
  const PinResetScreen({super.key, required this.phone});
  final String phone;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Code oublié')),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(24), children: [
            Text('Vérifions votre numéro', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('Nous vous envoyons un code par SMS, valable 5 minutes. Vous choisirez ensuite un nouveau code.',
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 24),
            PhoneOtpForm(
              initialPhone: phone,
              onVerified: (_) => Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
                builder: (_) => const PinSetupScreen(mode: PinSetupMode.reset, forced: true),
              )),
            ),
          ]),
        ),
      );
}
