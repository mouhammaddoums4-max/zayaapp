import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'core/l10n/l10n.dart';
import 'core/theme.dart';
import 'core/widgets.dart';
import 'data/models.dart';
import 'data/repository.dart';
import 'features/app/app_update.dart';
import 'features/app/rating_prompt.dart';
import 'features/home/home_shell.dart';
import 'features/onboarding/welcome_screen.dart';

/// Fil de découverte partagé entre les onglets Découvrir et Explorer.
class FeedStore extends ChangeNotifier {
  FeedStore(this._repo);
  final ZayaRepository _repo;

  List<DiscoveryProfile> profiles = const <DiscoveryProfile>[];
  LikeQuota? quota;
  bool loading = false;
  bool loaded = false;
  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final feed = await _repo.discoveryFeed();
      final likeQuota = await _repo.likeQuota();
      profiles = feed;
      quota = likeQuota;
      loaded = true;
    } catch (_) {
      error = 'Impossible de charger les profils. Vérifiez votre connexion.';
    }
    loading = false;
    notifyListeners();
  }

  void remove(String userId) {
    profiles = profiles.where((p) => p.id != userId).toList();
    notifyListeners();
  }

  /// Remet un profil en tête du fil (retour arrière sur un profil passé, migration 0016).
  void restore(DiscoveryProfile profile) {
    profiles = [profile, ...profiles.where((p) => p.id != profile.id)];
    notifyListeners();
  }

  void setRemaining(int remaining) {
    final current = quota;
    if (current == null) return;
    quota = LikeQuota(limit: current.limit, remaining: remaining, resetsAt: current.resetsAt);
    notifyListeners();
  }

  void reset() {
    profiles = const <DiscoveryProfile>[];
    quota = null;
    loaded = false;
    loading = false;
    error = null;
  }
}

/// État de session partagé : dépôt de données, profil du membre connecté, compteurs des onglets.
class Session extends ChangeNotifier {
  Session(this.repo) : feed = FeedStore(repo);
  final ZayaRepository repo;
  final FeedStore feed;

  MyProfile? me;
  bool loading = true;
  int likesBadge = 0;
  int unreadBadge = 0;

  /// Réglages publics lus au lancement (app_config) : mise à jour proposée ou obligatoire, demande d'avis.
  UpdateStatus update = const UpdateStatus.none();
  RatingRules ratingRules = const RatingRules();

  /// Durée d'une période de swipes (app_config.swipe_window_hours, 0016).
  int swipeWindowHours = 8;

  Future<void> loadAppConfig() async {
    try {
      final config = await repo.publicConfig();
      update = evaluateUpdate(config);
      ratingRules = RatingRules.fromConfig(config);
      final hours = config['swipe_window_hours'];
      if (hours is num && hours > 0) swipeWindowHours = hours.toInt();
      notifyListeners();
    } catch (_) {
      // Hors connexion : rien n'est imposé, nouvel essai au prochain lancement.
    }
  }

  /// Chargement initial, pendant l'écran de démarrage : profil et réglages publics, puis, pour un membre actif, le
  /// fil, les pastilles et les premières photos, afin que l'application s'ouvre déjà remplie. Plafonné à
  /// [maxWait] : sur un réseau lent, l'application s'ouvre quand même et les écrans finissent de charger.
  Future<void> start({Duration maxWait = const Duration(seconds: 3)}) async {
    await Future.wait([_loadMe(), loadAppConfig()]);
    final m = me;
    if (m != null && m.status == 'active') {
      try {
        await Future.wait([feed.load(), refreshBadges()]).then((_) => _warmPhotos()).timeout(maxWait);
      } catch (_) {
        // Délai dépassé ou réseau indisponible : rien de bloquant.
      }
    }
    loading = false;
    notifyListeners();
    _listenSignals();
  }

  Future<void> refresh() async {
    await _loadMe();
    loading = false;
    notifyListeners();
    _listenSignals();
  }

  Future<void> _loadMe() async {
    try {
      me = repo.isSignedIn ? await repo.loadMyProfile() : null;
    } catch (_) {
      me = null;
    }
  }

  /// Photo du membre et des deux premiers profils du fil, déjà téléchargées et décodées à l'ouverture.
  Future<void> _warmPhotos() async {
    final paths = <String?>[me?.mainPhotoPath, for (final p in feed.profiles.take(2)) p.photoPath];
    await Future.wait([
      for (final path in paths.whereType<String>()) _warmPhoto(path),
    ]);
  }

  Future<void> _warmPhoto(String path) async {
    final url = await repo.photoUrl(path);
    if (url == null) return;
    final done = Completer<void>();
    final stream = NetworkImage(url).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    void finish() {
      if (!done.isCompleted) done.complete();
      stream.removeListener(listener);
    }

    listener = ImageStreamListener((_, __) => finish(), onError: (_, __) => finish());
    stream.addListener(listener);
    return done.future;
  }

  // ── Mises à jour instantanées (migration 0055)
  StreamSubscription<String>? _signalSubscription;
  final StreamController<String> _signalEvents = StreamController<String>.broadcast();
  final Set<String> _pendingSignals = <String>{};
  Timer? _signalDebounce;

  /// Signaux reçus en temps réel ('like', 'match', 'message', 'photo', 'premium', 'profile', 'visit', 'wallet') :
  /// les écrans de listes (likes, conversations, portefeuille…) peuvent s'y abonner pour se rafraîchir aussitôt.
  Stream<String> get signals => _signalEvents.stream;

  void _listenSignals() {
    if (_signalSubscription != null || me == null || !repo.isSignedIn) return;
    _signalSubscription = repo.watchSignals().listen(_onSignal, onError: (Object _) {});
  }

  void _stopSignals() {
    _signalSubscription?.cancel();
    _signalSubscription = null;
    _signalDebounce?.cancel();
    _pendingSignals.clear();
  }

  void _onSignal(String kind) {
    if (!_signalEvents.isClosed) _signalEvents.add(kind);
    _pendingSignals.add(kind);
    // Plusieurs signaux rapprochés (un match envoie aussi un message…) : un seul rafraîchissement.
    _signalDebounce?.cancel();
    _signalDebounce = Timer(const Duration(milliseconds: 300), _applySignals);
  }

  Future<void> _applySignals() async {
    final kinds = {..._pendingSignals};
    _pendingSignals.clear();
    if (kinds.any(const {'photo', 'premium', 'profile'}.contains)) {
      await _loadMe();
      notifyListeners();
    }
    if (kinds.any(const {'like', 'match', 'message'}.contains)) await refreshBadges();
    // Premium active ou retire les filtres avancés : le fil est recalculé.
    if (kinds.contains('premium') && feed.loaded) unawaited(feed.load());
  }

  /// Retour dans l'application : tout ce qui a pu changer pendant l'absence est relu, sans écran de chargement.
  Future<void> resume() async {
    if (me == null || !repo.isSignedIn) return;
    await _loadMe();
    notifyListeners();
    await refreshBadges();
    _listenSignals();
  }

  @override
  void dispose() {
    _stopSignals();
    _signalEvents.close();
    super.dispose();
  }

  /// Met à jour les pastilles des onglets Likes et Messages. Silencieux en cas d'échec réseau.
  Future<void> refreshBadges() async {
    if (me == null) return;
    try {
      final likes = await repo.receivedInterestsCount();
      final matches = await repo.matches();
      likesBadge = likes;
      unreadBadge = matches.fold<int>(0, (sum, m) => sum + m.unread);
      notifyListeners();
    } catch (_) {
      // Les compteurs seront rafraîchis au prochain changement d'onglet.
    }
  }

  Future<void> signOut() async {
    _stopSignals();
    await repo.signOut();
    me = null;
    likesBadge = 0;
    unreadBadge = 0;
    feed.reset();
    notifyListeners();
  }

  /// Accès avec abonnement aux changements (à utiliser dans `build`).
  static Session of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_SessionScope>()!.notifier!;

  /// Accès ponctuel sans abonnement (utilisable dans `initState` et les callbacks).
  static Session read(BuildContext context) => context.getInheritedWidgetOfExactType<_SessionScope>()!.notifier!;
}

class _SessionScope extends InheritedNotifier<Session> {
  const _SessionScope({required Session session, required super.child}) : super(notifier: session);
}

class ZayaApp extends StatefulWidget {
  const ZayaApp({super.key, required this.repository});
  final ZayaRepository repository;

  @override
  State<ZayaApp> createState() => _ZayaAppState();
}

class _ZayaAppState extends State<ZayaApp> with WidgetsBindingObserver {
  late final Session _session = Session(widget.repository);
  final LanguageController _language = LanguageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _language.restore();
    // Profil, réglages publics, fil, pastilles et premières photos, pendant l'écran de démarrage.
    _session.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _session.resume();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session.feed.dispose();
    _session.dispose();
    _language.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LanguageScope(
      controller: _language,
      child: _SessionScope(
        session: _session,
        child: ListenableBuilder(
          listenable: _language,
          builder: (context, _) => MaterialApp(
            title: 'ZAYA',
            debugShowCheckedModeBanner: false,
            theme: buildZayaTheme(),
            locale: _language.locale,
            supportedLocales: const [Locale('fr'), Locale('en')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: const _RootGate(),
          ),
        ),
      ),
    );
  }
}

/// Aiguillage : chargement → accueil / inscription → application (ou écran de compte restreint).
class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final session = Session.of(context);
    if (session.loading) return const _Splash();
    if (session.update.level == UpdateLevel.required) return RequiredUpdateScreen(status: session.update);
    final me = session.me;
    if (me == null || me.status == 'draft') return const WelcomeScreen();
    if (me.status == 'suspended' || me.status == 'banned' || me.status == 'deleted') {
      return _RestrictedAccount(status: me.status);
    }
    return const HomeShell();
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: ZColors.brandGradient),
          child: Center(child: ZayaLogo(size: 120)),
        ),
      );
}

/// Compte suspendu ou banni : explication claire, recours possible, déconnexion.
class _RestrictedAccount extends StatelessWidget {
  const _RestrictedAccount({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final suspended = status == 'suspended';
    return Scaffold(
      body: SafeArea(
        child: FillOrScroll(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.lock_outline, size: 56, color: ZColors.danger),
            const SizedBox(height: 20),
            Text(suspended ? 'Compte suspendu' : 'Compte fermé',
                style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(
              suspended
                  ? 'Votre compte est temporairement suspendu à la suite d’un examen de modération. '
                      'Vous pouvez demander un réexamen auprès de l’assistance ZAYA.'
                  : 'Ce compte n’est plus accessible. Si vous pensez qu’il s’agit d’une erreur, '
                      'vous pouvez demander un réexamen auprès de l’assistance ZAYA.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            OutlinedButton(
              onPressed: () => Session.read(context).signOut(),
              child: const Text('Se déconnecter'),
            ),
          ]),
        ),
      ),
    );
  }
}
