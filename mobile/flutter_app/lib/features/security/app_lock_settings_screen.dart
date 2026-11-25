import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../settings/settings_widgets.dart';
import 'app_lock.dart';
import 'lock_screen.dart';

/// Réglages du verrouillage : activer par un code, empreinte ou visage, délai, changer le code.
class AppLockSettingsScreen extends StatefulWidget {
  const AppLockSettingsScreen({super.key, this.lock});
  final AppLock? lock;

  @override
  State<AppLockSettingsScreen> createState() => _AppLockSettingsScreenState();
}

class _AppLockSettingsScreenState extends State<AppLockSettingsScreen> {
  late final AppLock _lock = widget.lock ?? AppLock.instance;
  bool? _deviceAvailable;

  @override
  void initState() {
    super.initState();
    _lock.load();
    _lock.device.available().then((v) {
      if (mounted) setState(() => _deviceAvailable = v);
    });
  }

  Future<String?> _askPin(PinStep step) =>
      Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => PinEntryScreen(step: step, lock: _lock)));

  Future<void> _toggle(bool on) async {
    final messenger = ScaffoldMessenger.of(context);
    final s = context.s;
    if (on) {
      if (_lock.hasCode) {
        // Code déjà connu (code de connexion retenu) : le membre le confirme, sans en créer un second.
        if (await _askPin(PinStep.current) == null) return;
        await _lock.enable();
      } else {
        final pin = await _askPin(PinStep.create);
        if (pin == null) return;
        await _lock.setPin(pin);
      }
      messenger.showSnackBar(SnackBar(content: Text(s.lockEnabled)));
    } else {
      // Désactiver exige le code : un téléphone laissé ouvert ne suffit pas à retirer la protection.
      final ok = await _askPin(PinStep.current);
      if (ok == null) return;
      await _lock.turnOff();
    }
  }

  Future<void> _change() async {
    final current = await _askPin(PinStep.current);
    if (current == null || !mounted) return;
    final pin = await _askPin(PinStep.create);
    if (pin != null) await _lock.setPin(pin);
  }

  Future<void> _toggleBiometrics(bool on) async {
    if (on) {
      // Le membre prouve d'abord que l'empreinte ou le visage enregistrés sont bien les siens.
      final ok = await _lock.device.authenticate(context.s.lockReason);
      if (!ok) return;
    }
    await _lock.setBiometrics(on);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      appBar: AppBar(title: Text(s.lockSettingsTitle)),
      body: ListenableBuilder(
        listenable: _lock,
        builder: (context, _) => ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 28 + MediaQuery.paddingOf(context).bottom),
          children: [
            SettingsGroup(children: [
              SwitchListTile(
                secondary: const Icon(Icons.pin_outlined, color: ZColors.primary),
                title: Text(s.lockSwitch),
                value: _lock.enabled,
                onChanged: _lock.loaded ? _toggle : null,
              ),
              if (_lock.enabled) ...[
                SwitchListTile(
                  secondary: const Icon(Icons.fingerprint, color: ZColors.primary),
                  title: Text(s.lockBiometricSwitch),
                  subtitle: _deviceAvailable == false ? Text(s.lockBiometricUnavailable) : null,
                  value: _lock.biometrics,
                  onChanged: _deviceAvailable == true ? _toggleBiometrics : null,
                ),
                ListTile(
                  leading: const Icon(Icons.password, color: ZColors.primary),
                  title: Text(s.lockChangePin),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _change,
                ),
              ],
            ]),
            if (_lock.enabled) ...[
              SettingsSectionTitle(s.lockDelayTitle),
              RadioGroup<int>(
                groupValue: _lock.delaySeconds,
                onChanged: (v) => _lock.setDelay(v ?? 0),
                child: SettingsGroup(children: [
                  for (final d in AppLock.delayChoices) RadioListTile<int>(value: d, title: Text(s.lockDelay(d))),
                ]),
              ),
            ],
            const SizedBox(height: 16),
            InfoBanner(tone: BannerTone.info, icon: Icons.lock_outline, text: s.lockPrivacyNote),
          ],
        ),
      ),
    );
  }
}

enum PinStep { create, current }

/// Saisie d'un code : création (saisie puis confirmation) ou vérification du code actuel. Renvoie le code.
class PinEntryScreen extends StatefulWidget {
  const PinEntryScreen({super.key, required this.step, required this.lock});
  final PinStep step;
  final AppLock lock;

  @override
  State<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends State<PinEntryScreen> {
  String _pin = '';
  String? _first;
  String? _error;
  bool _busy = false;

  Future<void> _digit(String d) async {
    if (_busy || _pin.length >= AppLock.pinLength) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length < AppLock.pinLength) return;
    final s = context.s;
    final pin = _pin;
    if (widget.step == PinStep.current) {
      setState(() => _busy = true);
      final ok = await widget.lock.verifyPin(pin);
      if (!mounted) return;
      if (ok) return Navigator.of(context).pop(pin);
      final wait = widget.lock.waitRemaining;
      setState(() {
        _busy = false;
        _pin = '';
        _error = wait != null ? s.lockWait(wait.inSeconds + 1) : s.lockWrongPin;
      });
      return;
    }
    if (_first == null) {
      setState(() {
        _first = pin;
        _pin = '';
      });
    } else if (_first == pin) {
      Navigator.of(context).pop(pin);
    } else {
      setState(() {
        _first = null;
        _pin = '';
        _error = s.lockPinMismatch;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final title = switch (widget.step) {
      PinStep.current => s.lockCurrentPin,
      PinStep.create => _first == null ? s.lockNewPin : s.lockConfirmPin,
    };
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 22),
            PinDots(filled: _pin.length),
            SizedBox(
              height: 44,
              child: Center(
                child: _error == null
                    ? null
                    : Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: ZColors.danger)),
              ),
            ),
            PinPad(
              onDigit: _digit,
              onErase: () {
                if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1));
              },
            ),
          ]),
        ),
      ),
    );
  }
}
