import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zaya/features/security/app_lock.dart';
import 'package:zaya/features/security/lock_screen.dart';

/// Biométrie simulée : le test décide si l'empreinte ou le visage est reconnu.
class _FakeDevice implements DeviceAuth {
  bool accept = true;
  int prompts = 0;
  @override
  Future<bool> available() async => true;
  @override
  Future<bool> authenticate(String reason) async {
    prompts++;
    return accept;
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
    await GoogleFonts.pendingFonts([
      GoogleFonts.inter(),
      GoogleFonts.inter(fontWeight: FontWeight.w600),
      GoogleFonts.inter(fontWeight: FontWeight.w700),
      GoogleFonts.sora(fontWeight: FontWeight.w600),
      GoogleFonts.sora(fontWeight: FontWeight.w700),
    ]);
  });

  test('code : jamais conservé en clair ; bon code déverrouille ; réglages relus au démarrage', () async {
    final store = MemoryLockStore();
    final lock = AppLock(store: store, device: _FakeDevice());
    await lock.load();
    expect(lock.enabled, isFalse);
    expect(lock.locked, isFalse);
    await lock.setPin('2580');
    expect(store.values.values.any((v) => v.contains('2580')), isFalse, reason: 'aucun code en clair');

    final restarted = AppLock(store: store, device: _FakeDevice());
    await restarted.load();
    expect(restarted.locked, isTrue, reason: 'l’application s’ouvre verrouillée');
    expect(await restarted.verifyPin('1111'), isFalse);
    expect(restarted.locked, isTrue);
    expect(await restarted.verifyPin('2580'), isTrue);
    expect(restarted.locked, isFalse);
    expect(() => restarted.setPin('12a4'), throwsArgumentError);
  });

  test('après 5 erreurs : attente qui double, même après un redémarrage', () async {
    var now = DateTime(2026, 11, 25, 10);
    final store = MemoryLockStore();
    final lock = AppLock(store: store, device: _FakeDevice(), clock: () => now);
    await lock.load();
    await lock.setPin('2580');
    for (var i = 0; i < 5; i++) {
      await lock.verifyPin('0000');
    }
    expect(lock.waitRemaining, const Duration(seconds: 30));
    expect(await lock.verifyPin('2580'), isFalse, reason: 'même le bon code attend la fin du délai');

    final restarted = AppLock(store: store, device: _FakeDevice(), clock: () => now);
    await restarted.load();
    expect(restarted.waitRemaining, isNotNull, reason: 'redémarrer ne remet pas les essais à zéro');
    now = now.add(const Duration(seconds: 31));
    expect(await restarted.verifyPin('0000'), isFalse);
    expect(restarted.waitRemaining, const Duration(seconds: 60));
    now = now.add(const Duration(seconds: 61));
    expect(await restarted.verifyPin('2580'), isTrue);
    expect(restarted.failures, 0);
  });

  test('empreinte ou visage : seulement si activés ; retour dans l’application selon le délai choisi', () async {
    var now = DateTime(2026, 11, 25, 10);
    final device = _FakeDevice();
    final lock = AppLock(store: MemoryLockStore(), device: device, clock: () => now);
    await lock.load();
    await lock.setPin('2580');
    lock.lockNow();
    expect(await lock.unlockWithDevice('Déverrouiller'), isFalse, reason: 'biométrie non activée');
    expect(device.prompts, 0);
    await lock.setBiometrics(true);
    device.accept = false;
    expect(await lock.unlockWithDevice('Déverrouiller'), isFalse);
    device.accept = true;
    expect(await lock.unlockWithDevice('Déverrouiller'), isTrue);

    await lock.setDelay(60);
    lock.didChangeAppLifecycleState(AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 20));
    lock.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(lock.locked, isFalse, reason: 'absence plus courte que le délai');
    lock.didChangeAppLifecycleState(AppLifecycleState.paused);
    now = now.add(const Duration(minutes: 2));
    lock.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(lock.locked, isTrue);

    await lock.disable();
    expect(lock.enabled || lock.locked || lock.biometrics, isFalse);
  });

  test('code unique : le code de connexion retenu sert au verrou ; désactiver depuis les réglages le garde', () async {
    final lock = AppLock(store: MemoryLockStore(), device: _FakeDevice());
    await lock.load();
    await lock.rememberLoginCode('4826');
    expect(lock.hasCode, isTrue);
    expect(lock.enabled, isFalse, reason: 'retenir le code n''active pas le verrou à la place du membre');
    await lock.enable();
    lock.lockNow();
    expect(await lock.verifyPin('4826'), isTrue);
    await lock.turnOff();
    expect(lock.enabled, isFalse);
    expect(lock.hasCode, isTrue, reason: 'le code reste connu pour réactiver le verrou');
    await lock.disable();
    expect(lock.hasCode, isFalse, reason: '« Code oublié ? » efface tout');
  });

  testWidgets('écran verrouillé : contenu masqué ; mauvais code signalé ; bon code ouvre l’application',
      (tester) async {
    // Taille d'un téléphone : tout l'écran verrouillé est visible.
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final lock = AppLock(store: MemoryLockStore(), device: _FakeDevice());
    await lock.load();
    await lock.setPin('2580');
    lock.lockNow();
    var forgot = 0;
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => AppLockGate(
        lock: lock,
        signedIn: true,
        onForgot: () async => forgot++,
        child: child!,
      ),
      home: const Scaffold(body: Text('Conversations privées')),
    ));
    await tester.pump();
    expect(find.text('ZAYA est verrouillé'), findsOneWidget);
    expect(find.bySemanticsLabel('Conversations privées'), findsNothing, reason: 'contenu caché aux lecteurs d’écran');

    for (final d in ['1', '1', '1', '1']) {
      await tester.tap(find.text(d).last);
      await tester.pump();
    }
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    expect(find.text('Code incorrect'), findsOneWidget);

    for (final d in ['2', '5', '8', '0']) {
      await tester.tap(find.text(d).last);
      await tester.pump();
    }
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    expect(find.text('ZAYA est verrouillé'), findsNothing);
    expect(find.text('Conversations privées'), findsOneWidget);

    lock.lockNow();
    await tester.pump();
    await tester.tap(find.text('Code oublié ?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Me reconnecter'));
    await tester.pumpAndSettle();
    expect(forgot, 1);
  });

  testWidgets('membre non connecté : jamais d’écran de verrouillage', (tester) async {
    final lock = AppLock(store: MemoryLockStore(), device: _FakeDevice());
    await lock.load();
    await lock.setPin('2580');
    lock.lockNow();
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => AppLockGate(lock: lock, signedIn: false, onForgot: () async {}, child: child!),
      home: const Scaffold(body: Text('Bienvenue')),
    ));
    await tester.pump();
    expect(find.text('ZAYA est verrouillé'), findsNothing);
    expect(find.text('Bienvenue'), findsOneWidget);
  });
}
