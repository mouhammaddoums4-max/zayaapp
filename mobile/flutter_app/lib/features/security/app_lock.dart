import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:material_ui/material_ui.dart';

/// Verrouillage local de l'application (CDC V6.4 §22.9) : code PIN propre à ZAYA, empreinte digitale ou
/// reconnaissance faciale (Face ID sur iPhone) par les mécanismes du système, avec repli sur le code du téléphone.
/// Tout reste sur l'appareil : ni le code ni la biométrie ne sont envoyés au serveur.
class AppLock extends ChangeNotifier with WidgetsBindingObserver {
  AppLock({LockStore? store, DeviceAuth? device, DateTime Function()? clock})
      : _store = store ?? const SecureLockStore(),
        device = device ?? LocalDeviceAuth(),
        _clock = clock ?? DateTime.now;

  /// Instance de l'application.
  static final AppLock instance = AppLock();

  static const pinLength = 4;

  /// Essais libres avant une attente ; l'attente double ensuite à chaque erreur (au plus 15 minutes).
  static const freeAttempts = 5;

  /// Délais proposés avant le verrouillage, une fois l'application quittée (secondes).
  static const delayChoices = <int>[0, 60, 300];

  final LockStore _store;
  final DeviceAuth device;
  final DateTime Function() _clock;

  bool loaded = false;
  bool enabled = false;
  bool biometrics = false;
  int delaySeconds = 0;
  bool locked = false;
  int failures = 0;
  DateTime? blockedUntil;
  String? _hash;
  String? _salt;
  DateTime? _leftAt;
  bool _observing = false;

  static const _kEnabled = 'lock_enabled';
  static const _kHash = 'lock_pin_hash';
  static const _kSalt = 'lock_pin_salt';
  static const _kBio = 'lock_biometrics';
  static const _kDelay = 'lock_delay_seconds';
  static const _kFailures = 'lock_failures';
  static const _kBlocked = 'lock_blocked_until';

  /// Lit les réglages ; au démarrage, l'application s'ouvre verrouillée si le verrouillage est actif.
  Future<void> load() async {
    if (loaded) return;
    try {
      enabled = await _store.read(_kEnabled) == 'true';
      _hash = await _store.read(_kHash);
      _salt = await _store.read(_kSalt);
      biometrics = await _store.read(_kBio) == 'true';
      delaySeconds = int.tryParse(await _store.read(_kDelay) ?? '') ?? 0;
      failures = int.tryParse(await _store.read(_kFailures) ?? '') ?? 0;
      final blocked = await _store.read(_kBlocked);
      blockedUntil = blocked == null ? null : DateTime.tryParse(blocked);
    } catch (_) {
      enabled = false; // stockage illisible : on ne bloque pas le membre hors de son compte
    }
    if (enabled && (_hash == null || _salt == null)) enabled = false;
    locked = enabled;
    loaded = true;
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    notifyListeners();
  }

  static String _digest(String salt, String pin) {
    // Empreinte salée et répétée : le code n'est jamais conservé en clair.
    List<int> bytes = utf8.encode('$salt:$pin');
    for (var i = 0; i < 20000; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return base64Encode(bytes);
  }

  static bool isValidPin(String pin) => pin.length == pinLength && RegExp(r'^\d+$').hasMatch(pin);

  /// Un code est connu sur cet appareil (choisi ici, ou code de connexion retenu après une connexion réussie).
  bool get hasCode => _hash != null && _salt != null;

  Future<void> _storeCode(String pin) async {
    if (!isValidPin(pin)) throw ArgumentError('PIN');
    final rnd = Random.secure();
    final salt = base64Encode(List<int>.generate(16, (_) => rnd.nextInt(256)));
    _salt = salt;
    _hash = _digest(salt, pin);
    failures = 0;
    blockedUntil = null;
    await _store.write(_kSalt, salt);
    await _store.write(_kHash, _hash!);
    await _store.write(_kFailures, '0');
    await _store.delete(_kBlocked);
  }

  /// Active le verrouillage avec un nouveau code (ou remplace le code).
  Future<void> setPin(String pin) async {
    await _storeCode(pin);
    enabled = true;
    locked = false;
    await _store.write(_kEnabled, 'true');
    notifyListeners();
  }

  /// Code de connexion à 4 chiffres, après sa vérification par le serveur (connexion ou changement de code réussi) :
  /// il devient le code du verrou, pour déverrouiller sans réseau. Seule une empreinte salée est conservée.
  Future<void> rememberLoginCode(String code) async {
    if (!isValidPin(code)) return;
    await _storeCode(code);
    notifyListeners();
  }

  /// Active le verrouillage avec le code déjà connu (le membre vient de le saisir correctement).
  Future<void> enable() async {
    if (!hasCode) return;
    enabled = true;
    locked = false;
    await _store.write(_kEnabled, 'true');
    notifyListeners();
  }

  /// Attente restante avant un nouvel essai (null : essai possible).
  Duration? get waitRemaining {
    final until = blockedUntil;
    if (until == null) return null;
    final left = until.difference(_clock());
    return left.isNegative || left == Duration.zero ? null : left;
  }

  /// Vérifie le code. Vrai : l'application est déverrouillée.
  Future<bool> verifyPin(String pin) async {
    if (!hasCode) return false;
    if (waitRemaining != null) return false;
    if (_digest(_salt!, pin) == _hash) {
      await _unlocked();
      return true;
    }
    failures++;
    if (failures >= freeAttempts) {
      final seconds = min(30 * (1 << (failures - freeAttempts)), 15 * 60);
      blockedUntil = _clock().add(Duration(seconds: seconds));
      await _store.write(_kBlocked, blockedUntil!.toIso8601String());
    }
    await _store.write(_kFailures, '$failures');
    notifyListeners();
    return false;
  }

  /// Empreinte, visage ou, à défaut, code du téléphone (repli prévu par le système).
  Future<bool> unlockWithDevice(String reason) async {
    if (!enabled || !biometrics) return false;
    final ok = await device.authenticate(reason);
    if (ok) await _unlocked();
    return ok;
  }

  Future<void> _unlocked() async {
    locked = false;
    failures = 0;
    blockedUntil = null;
    await _store.write(_kFailures, '0');
    await _store.delete(_kBlocked);
    notifyListeners();
  }

  Future<void> setBiometrics(bool value) async {
    biometrics = value;
    await _store.write(_kBio, value ? 'true' : 'false');
    notifyListeners();
  }

  Future<void> setDelay(int seconds) async {
    delaySeconds = seconds;
    await _store.write(_kDelay, '$seconds');
    notifyListeners();
  }

  /// Désactive le verrouillage depuis les réglages ; le code reste connu pour le réactiver plus tard.
  Future<void> turnOff() async {
    enabled = false;
    biometrics = false;
    locked = false;
    await _store.write(_kEnabled, 'false');
    await _store.write(_kBio, 'false');
    notifyListeners();
  }

  /// Désactive le verrouillage et efface le code (aussi utilisé par « Code oublié ? », suivi d'une déconnexion).
  Future<void> disable() async {
    enabled = false;
    biometrics = false;
    locked = false;
    failures = 0;
    blockedUntil = null;
    _hash = null;
    _salt = null;
    for (final k in [_kEnabled, _kHash, _kSalt, _kBio, _kFailures, _kBlocked]) {
      await _store.delete(k);
    }
    notifyListeners();
  }

  void lockNow() {
    if (!enabled || locked) return;
    locked = true;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!enabled) return;
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _leftAt ??= _clock();
      case AppLifecycleState.resumed:
        final left = _leftAt;
        _leftAt = null;
        if (left != null && _clock().difference(left).inSeconds >= delaySeconds) lockNow();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }
}

/// Stockage du verrouillage : chiffré par le système (Keystore Android, Trousseau iOS).
abstract class LockStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureLockStore implements LockStore {
  const SecureLockStore();
  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// En mémoire (tests).
class MemoryLockStore implements LockStore {
  final Map<String, String> values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// Authentification du système : empreinte, visage, ou code du téléphone en repli.
abstract class DeviceAuth {
  /// L'appareil peut-il authentifier le membre (biométrie enregistrée ou code du téléphone) ?
  Future<bool> available();
  Future<bool> authenticate(String reason);
}

class LocalDeviceAuth implements DeviceAuth {
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  Future<bool> available() async {
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(localizedReason: reason, persistAcrossBackgrounding: true);
    } catch (_) {
      return false;
    }
  }
}
