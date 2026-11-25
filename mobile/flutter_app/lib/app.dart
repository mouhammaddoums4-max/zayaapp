import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'core/l10n/l10n.dart';
import 'core/motion.dart';
import 'core/theme.dart';
import 'features/discovery/profile_widgets.dart' show zayaPhoto;
import 'core/widgets.dart';
import 'data/models.dart';
import 'data/repository.dart';
import 'features/app/app_update.dart';
import 'features/app/rating_prompt.dart';
import 'features/home/home_shell.dart';
import 'features/onboarding/welcome_screen.dart';
import 'features/security/app_lock.dart';
import 'features/security/lock_screen.dart';

/// Fil de découverte partagé entre les onglets Découvrir et Explorer.
class FeedStore extends ChangeNotifier {
  FeedStore(this._repo);
  final ZayaRepository _repo;

  List<DiscoveryProfile> profiles = const <DiscoveryProfile>[];
  LikeQuota? quota;
  String? quickFilter;
  bool loading = false;
  bool loaded = false;
  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final repository = _repo;
      final filter = quickFilter;
      final feed = repository is QuickDiscoveryRepository
          ? await (repository as QuickDiscoveryRepository).discoveryFeedFiltered(filter)
          : await repository.discoveryFeed();
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

  Future<void> setQuickFilter(String? filter) async {
    if (quickFilter == filter) return;
    quickFilter = filter;
    await load();
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
    quickFilter = null;
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

  /// Réglages publics (`app_config`, lisibles par l'application), gardés pour les interrupteurs de fonctions.
  /// Le serveur reste juge : une fonction coupée y est refusée même si l'application l'ignore encore.
  Map<String, Object?> publicConfigCache = const <String, Object?>{};

  /// Le serveur propose-t-il ZAYA 2.0 (migrations 0066 à 0070) ? Tant que ces migrations ne sont pas appliquées en
  /// ligne, leurs interrupteurs sont absents de la configuration publique : l'application masque alors ces blocs
  /// au lieu d'appeler des fonctions qui n'existent pas encore.
  bool get zaya2Ready => publicConfigCache['feature_challenge_enabled'] != null;

  /// Fonction ZAYA 2.0 déclarée active par le serveur (`feature_<nom>_enabled`).
  bool featureOn(String name) => publicConfigCache['feature_${name}_enabled'] == true;

  Future<void> loadAppConfig() async {
    try {
      final config = await repo.publicConfig();
      publicConfigCache = config;
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
    // Tout part en même temps : profil, réglages, fil et pastilles ne s'attendent plus les uns les autres.
    // Le fil est lancé sans attendre le profil ; il est jeté si le compte n'est pas actif (voir plus bas).
    final signedIn = repo.isSignedIn;
    final prefetch =
        signedIn ? Future.wait([feed.load(), refreshBadges()]).then((_) => _warmPhotos()).timeout(maxWait) : null;
    // Le délai ne doit pas laisser une erreur non gérée si le chargement échoue après l'ouverture.
    unawaited(prefetch?.then((_) {}, onError: (Object _) {}));
    await Future.wait([_loadMe(), loadAppConfig()]);
    final m = me;
    if (m != null && m.status == 'active') {
      try {
        await prefetch;
      } catch (_) {
        // Délai dépassé ou réseau indisponible : rien de bloquant.
      }
    } else {
      feed.reset();
    }
    loading = false;
    notifyListeners();
    _listenSignals();
    _startPresence();
  }

  Future<void> refresh() async {
    await _loadMe();
    loading = false;
    notifyListeners();
    _listenSignals();
    _startPresence();
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
    final stream = zayaPhoto(url, path).resolve(ImageConfiguration.empty);
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
    _startPresence();
  }

  // ── Présence « en ligne » (0070) : un signal d'activité par minute tant que l'application est au premier plan.
  Timer? _presence;

  void _startPresence() {
    if (_presence != null || me == null || !repo.isSignedIn) return;
    _presence = Timer.periodic(const Duration(minutes: 1), (_) => unawaited(repo.touchActive()));
  }

  /// Application en arrière-plan : plus de signal d'activité, le point vert disparaît au bout de quelques minutes.
  void pausePresence() {
    _presence?.cancel();
    _presence = null;
  }

  @override
  void dispose() {
    pausePresence();
    _stopSignals();
    _signalEvents.close();
    super.dispose();
  }

  /// Met à jour les pastilles des onglets Likes et Messages. Silencieux en cas d'échec réseau.
  Future<void> refreshBadges() async {
    if (!repo.isSignedIn) return;
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
    pausePresence();
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

/// Observateur de navigation de l'application (RouteAware : un écran apprend que celui du dessus s'est refermé).
final RouteObserver<ModalRoute<Object?>> zRouteObserver = RouteObserver<ModalRoute<Object?>>();

class ZayaApp extends StatefulWidget {
  const ZayaApp({super.key, required this.repository});
  final ZayaRepository repository;

  @override
  State<ZayaApp> createState() => _ZayaAppState();
}

class _ZayaAppState extends State<ZayaApp> with WidgetsBindingObserver {
  late final Session _session = Session(widget.repository);
  // Thème construit une seule fois : le reconstruire à chaque changement de langue recalculait toutes les polices.
  late final ThemeData _theme = buildZayaTheme();
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
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) _session.pausePresence();
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
            theme: _theme,
            locale: _language.locale,
            supportedLocales: const [Locale('fr'), Locale('en')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            // Permet à un écran de savoir quand celui du dessus se referme (ex. choix du code après l'inscription).
            navigatorObservers: [zRouteObserver],
            home: const _RootGate(),
            // Verrouillage par code PIN, empreinte ou Face ID (CDC V6.4 §22.9), au-dessus de tous les écrans.
            builder: (context, child) => ListenableBuilder(
              listenable: _session,
              builder: (context, _) => AppLockGate(
                signedIn: _session.me != null && _session.me!.status != 'draft',
                onForgot: () async {
                  await AppLock.instance.disable();
                  await _session.signOut();
                },
                child: child ?? const SizedBox.shrink(),
              ),
            ),
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
    final Widget page;
    if (session.loading) {
      page = const _Splash(key: ValueKey<String>('splash'));
    } else if (session.update.level == UpdateLevel.required) {
      page = RequiredUpdateScreen(status: session.update);
    } else {
      final me = session.me;
      if (me == null || me.status == 'draft') {
        page = const WelcomeScreen();
      } else if (me.status == 'suspended' || me.status == 'banned' || me.status == 'deleted') {
        page = _RestrictedAccount(status: me.status);
      } else {
        page = const HomeShell();
      }
    }
    // Fondu court entre le démarrage et l'écran suivant, au lieu d'un changement sec.
    return AnimatedSwitcher(
      duration: ZMotion.of(context, const Duration(milliseconds: 220)),
      child: KeyedSubtree(key: ValueKey<Type>(page.runtimeType), child: page),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash({super.key});

  @override
  // Fond blanc, comme l'écran de lancement Android : pas d'éclair rose entre les deux, et aucun texte.
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: ZayaLogo(size: 104)),
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
