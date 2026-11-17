import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
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
  late final _phone = TextEditingController(text: widget.initialPhone);
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
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
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _busy ? null : () => setState(() => _codeSent = false),
            child: const Text('Modifier le numéro'),
          ),
        ),
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
                    if (mounted) setState(() => _codeSent = true);
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

/// Connexion d'un membre existant.
class PhoneLoginScreen extends StatelessWidget {
  const PhoneLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connexion')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(24), children: [
          Text('Bon retour sur ZAYA', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('Entrez votre numéro pour recevoir un code de connexion.', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 24),
          PhoneOtpForm(onVerified: (_) async {
            final session = Session.read(context);
            final nav = Navigator.of(context);
            await session.refresh();
            if (session.me != null) {
              nav.popUntil((r) => r.isFirst);
            } else {
              // Numéro vérifié mais aucun profil : poursuivre l'inscription.
              nav.pushReplacement(MaterialPageRoute<void>(builder: (_) => const OnboardingFlow()));
            }
          }),
        ]),
      ),
    );
  }
}
