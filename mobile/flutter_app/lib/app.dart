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

  Future<void> loadAppConfig() async {
    try {
      final config = await repo.publicConfig();
      update = evaluateUpdate(config);
      ratingRules = RatingRules.fromConfig(config);
      notifyListeners();
    } catch (_) {
      // Hors connexion : rien n'est imposé, nouvel essai au prochain lancement.
    }
  }

  Future<void> refresh() async {
    try {
      me = repo.isSignedIn ? await repo.loadMyProfile() : null;
    } catch (_) {
      me = null;
    }
    loading = false;
    notifyListeners();
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

class _ZayaAppState extends State<ZayaApp> {
  late final Session _session = Session(widget.repository);
  final LanguageController _language = LanguageController();

  @override
  void initState() {
    super.initState();
    _language.restore();
    _session.refresh();
    _session.loadAppConfig();
  }

  @override
  void dispose() {
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
