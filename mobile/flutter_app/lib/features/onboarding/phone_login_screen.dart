import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../auth/pin_screens.dart';
import 'onboarding_flow.dart';

/// Normalise un numéro guinéen saisi localement (« 622 11 22 33 ») en format international.
String normalizeGuineaPhone(String input) {
  final digits = input.replaceAll(RegExp(r'\D'), '');
  if (input.trim().startsWith('+')) return '+$digits';
  if (digits.startsWith('224') && digits.length == 12) return '+$digits';
  return '+224$digits';
}

bool isValidGuineaPhone(String input) => RegExp(r'^\+224[0-9]{9}$').hasMatch(normalizeGuineaPhone(input));

/// Saisie du numéro + code OTP. Réutilisé par la connexion et par l'inscription.
class PhoneOtpForm extends StatefulWidget {
  const PhoneOtpForm({super.key, required this.onVerified, this.initialPhone = ''});
  final void Function(String phone) onVerified;
  final String initialPhone;

  @override
  State<PhoneOtpForm> createState() => _PhoneOtpFormState();
}

class _PhoneOtpFormState extends State<PhoneOtpForm> {
  /// Délai par défaut avant de pouvoir redemander un code, si `app_config.otp_resend_seconds` est illisible.
  static const _defaultResendSeconds = 60;

  late final _phone = TextEditingController(text: widget.initialPhone);
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;
  Timer? _timer;
  int _resendIn = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  /// Compte à rebours avant renvoi (CDC §9) : évite les demandes répétées, donc les envois facturés inutiles.
  Future<void> _startCountdown() async {
    var seconds = _defaultResendSeconds;
    try {
      final value = (await Session.read(context).repo.publicConfig())['otp_resend_seconds'];
      if (value is num && value > 0) seconds = value.toInt();
    } catch (_) {
      // Valeur par défaut.
    }
    if (!mounted) return;
    _timer?.cancel();
    setState(() => _resendIn = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendIn <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendIn = 0);
        return;
      }
      setState(() => _resendIn--);
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final repo = Session.of(context).repo;
    final phone = normalizeGuineaPhone(_phone.text);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        controller: _phone,
        enabled: !_codeSent,
        keyboardType: TextInputType.phone,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
        decoration:
            const InputDecoration(labelText: 'Numéro de téléphone', prefixText: '+224  ', hintText: '6XX XX XX XX'),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 8),
      Text('Votre numéro sert uniquement à sécuriser votre compte. Il n’apparaît jamais sur votre profil.',
          style: Theme.of(context).textTheme.bodyMedium),
      if (_codeSent) ...[
        const SizedBox(height: 20),
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          maxLength: 6,
          autofocus: true,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Code reçu par SMS',
            counterText: '',
            helperText: repo.isDemo ? 'Mode démo : saisissez 123456' : 'Ne communiquez jamais ce code.',
          ),
          onChanged: (_) => setState(() {}),
        ),
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [
          TextButton(
            onPressed: _busy ? null : () => setState(() => _codeSent = false),
            child: const Text('Modifier le numéro'),
          ),
          if (_resendIn > 0)
            Text(s.otpResendIn(_resendIn), style: Theme.of(context).textTheme.bodySmall)
          else
            TextButton(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                        final messenger = ScaffoldMessenger.of(context);
                        await repo.requestOtp(phone);
                        if (!mounted) return;
                        messenger
                            .showSnackBar(SnackBar(content: Text(s.otpResent), behavior: SnackBarBehavior.floating));
                        await _startCountdown();
                      }),
              child: Text(s.otpResend),
            ),
        ]),
      ],
      if (_error != null) ...[
        const SizedBox(height: 8),
        Text(_error!, style: const TextStyle(color: ZColors.danger, fontWeight: FontWeight.w600)),
      ],
      const SizedBox(height: 20),
      if (!_codeSent)
        GradientButton(
          label: 'Recevoir le code',
          busy: _busy,
          onPressed: isValidGuineaPhone(_phone.text)
              ? () => _run(() async {
                    await repo.requestOtp(phone);
                    if (!mounted) return;
                    setState(() => _codeSent = true);
                    await _startCountdown();
                  })
              : null,
        )
      else
        GradientButton(
          label: 'Vérifier',
          busy: _busy,
          onPressed: _code.text.length == 6
              ? () => _run(() async {
                    await repo.verifyOtp(phone, _code.text);
                    widget.onVerified(phone);
                  })
              : null,
        ),
    ]);
  }
}

/// Connexion d'un membre existant (0071) : le numéro d'abord ; le serveur dit s'il existe.
///   • compte avec code → saisie du code à 4 chiffres (aucun SMS) ;
///   • numéro inconnu → proposition de créer son profil ;
///   • compte sans code (ou serveur sans la migration 0071) → vérification par SMS comme avant, puis choix du code.
class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _phone = TextEditingController();
  bool _busy = false;
  String? _error;

  /// Numéro pour lequel la vérification par SMS est proposée (compte sans code).
  String? _otpPhone;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_busy) return;
    if (!isValidGuineaPhone(_phone.text)) {
      setState(() => _error = 'Numéro invalide : 9 chiffres, par exemple 622 11 22 33.');
      return;
    }
    final phone = normalizeGuineaPhone(_phone.text);
    setState(() {
      _busy = true;
      _error = null;
    });
    final nav = Navigator.of(context);
    String status;
    try {
      status = await Session.read(context).repo.phoneStatus(phone);
    } catch (_) {
      // Serveur sans la connexion par code : la vérification par SMS reste possible.
      status = 'no_pin';
    }
    if (!mounted) return;
    setState(() => _busy = false);
    switch (status) {
      case 'pin':
        await nav.push(MaterialPageRoute<void>(builder: (_) => PinLoginScreen(phone: phone)));
      case 'new':
        await _proposeSignup();
      case 'rate_limited':
        setState(() => _error = 'Trop de tentatives depuis ce réseau. Réessayez dans un moment.');
      default:
        setState(() => _otpPhone = phone);
    }
  }

  Future<void> _proposeSignup() async {
    final create = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Aucun compte avec ce numéro'),
        content: const Text('Créez votre profil : votre numéro sera vérifié une seule fois par SMS, '
            'puis vous choisirez votre code de connexion.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.of(d).pop(true), child: const Text('Créer mon profil')),
        ],
      ),
    );
    if (create == true && mounted) {
      await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => const OnboardingFlow()));
    }
  }

  Future<void> _afterOtp() async {
    final session = Session.read(context);
    final nav = Navigator.of(context);
    await session.refresh();
    if (session.me != null) {
      // Le choix du code est demandé à l'arrivée dans l'application (compte sans code).
      nav.popUntil((r) => r.isFirst);
    } else {
      // Numéro vérifié mais aucun profil : poursuivre l'inscription.
      nav.pushReplacement(MaterialPageRoute<void>(builder: (_) => const OnboardingFlow()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final otpPhone = _otpPhone;
    return Scaffold(
      appBar: AppBar(title: const Text('Connexion')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(24), children: [
          Text('Bon retour sur ZAYA', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          if (otpPhone == null) ...[
            Text('Entrez votre numéro de téléphone.', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 24),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 +]'))],
              onSubmitted: (_) => _continue(),
              decoration: InputDecoration(
                prefixText: '+224 ',
                hintText: '622 11 22 33',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _continue,
              child: _busy
                  ? const SizedBox(
                      width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : const Text('Continuer'),
            ),
          ] else ...[
            const InfoBanner(
              icon: Icons.sms_outlined,
              text: 'Ce compte n’a pas encore de code de connexion. Confirmez votre numéro par SMS, '
                  'puis vous choisirez votre code : les prochaines fois, plus besoin de SMS.',
            ),
            const SizedBox(height: 20),
            PhoneOtpForm(initialPhone: otpPhone, onVerified: (_) => _afterOtp()),
          ],
        ]),
      ),
    );
  }
}
