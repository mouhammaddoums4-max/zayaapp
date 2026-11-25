import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app.dart';
import '../../core/l10n/l10n.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import 'phone_login_screen.dart';
import 'signup_done_screen.dart';

const _draftKey = 'zaya_onboarding_draft';

enum _Step {
  adult,
  name,
  birth,
  gender,
  city,
  horizon,
  marital,
  nationality,
  profession,
  education,
  children,
  confession,
  discovery,
  bio,
  phone,
  rules
}

/// Inscription progressive : une question par écran, barre de progression animée,
/// brouillon sauvegardé sur l'appareil pour reprendre après une interruption.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  OnboardingDraft _d = OnboardingDraft();
  List<City> _cities = const <City>[];
  List<Country> _countries = const <Country>[];
  List<Profession> _professions = const <Profession>[];
  List<EducationLevel> _educationLevels = const <EducationLevel>[];
  String _professionQuery = '';
  bool _loaded = false;
  bool _forward = true;
  bool _phoneVerified = false;
  bool _saving = false;
  String _cityQuery = '';
  final _name = TextEditingController();
  final _bio = TextEditingController();
  final _professionOther = TextEditingController();

  _Step get _step => _Step.values[_d.step.clamp(0, _Step.values.length - 1).toInt()];
  bool get _isLast => _step == _Step.values.last;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _professionOther.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    final repo = Session.read(context).repo;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftKey);
      if (raw != null) _d = OnboardingDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Brouillon illisible : on repart d'un formulaire vide.
      _d = OnboardingDraft();
    }
    try {
      _cities = await repo.cities();
    } catch (_) {
      _cities = const <City>[];
    }
    // Référentiels facultatifs : sans eux, les étapes nationalité et profession peuvent être passées.
    try {
      _countries = await repo.countries();
    } catch (_) {
      _countries = const <Country>[];
    }
    try {
      _professions = await repo.professions();
    } catch (_) {
      _professions = const <Profession>[];
    }
    // Niveaux d'études tenus par l'administration (0052) ; sans eux, l'étape peut être passée.
    try {
      _educationLevels = await repo.educationLevels();
    } catch (_) {
      _educationLevels = const <EducationLevel>[];
    }
    _phoneVerified = repo.isSignedIn;
    _name.text = _d.displayName;
    _bio.text = _d.bio;
    _professionOther.text = _d.professionOther;
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_draftKey, jsonEncode(_d.toJson()));
    } catch (_) {
      // La sauvegarde du brouillon est un confort : l'inscription continue sans elle.
    }
  }

  bool get _hasConfession => _d.confession != null && _d.confession != 'undisclosed';

  bool get _canContinue => switch (_step) {
        _Step.adult => _d.adultConfirmed,
        _Step.name => _d.displayName.trim().length >= 2,
        _Step.birth => _d.birthDate != null && isAdult(_d.birthDate!),
        _Step.gender => _d.gender != null,
        _Step.city => _d.cityId != null,
        _Step.horizon => _d.horizon != null,
        _Step.marital => true,
        _Step.nationality => true,
        _Step.profession => true,
        _Step.education => true,
        _Step.children => true,
        _Step.confession => !_hasConfession || _d.confessionConsent,
        _Step.discovery => _d.confessionMode != 'selected' || _d.selectedConfessions.isNotEmpty,
        _Step.bio => true,
        _Step.phone => _phoneVerified,
        _Step.rules => _d.acceptedTerms,
      };

  /// Sur une étape facultative restée vide, le bouton propose de passer.
  String get _buttonLabel {
    if (_isLast) return 'Entrer sur ZAYA';
    final empty = switch (_step) {
      _Step.marital => _d.maritalStatus == null,
      _Step.nationality => _d.nationalityCode == null,
      _Step.profession => _d.professionId == null && _d.professionOther.trim().isEmpty,
      _Step.education => _d.educationKey == null,
      _Step.children => _d.childrenCount == null,
      _Step.confession => _d.confession == null,
      _Step.bio => _d.bio.trim().isEmpty,
      _ => false,
    };
    return empty ? 'Passer cette étape' : 'Continuer';
  }

  void _next() {
    FocusScope.of(context).unfocus();
    if (_isLast) {
      _finish();
      return;
    }
    setState(() {
      _forward = true;
      _d.step = _step.index + 1;
    });
    _persist();
  }

  void _back() {
    FocusScope.of(context).unfocus();
    if (_step.index == 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _forward = false;
      _d.step = _step.index - 1;
    });
  }

  Future<void> _finish() async {
    final session = Session.read(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      await session.repo.saveOnboarding(_d);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_draftKey);
      } catch (_) {
        // Sans importance : le brouillon sera remplacé à la prochaine inscription.
      }
      await session.refresh();
      navigator.popUntil((route) => route.isFirst);
      // Fin d'inscription (B12) : le profil n'est proposé qu'après vérification ; photos et selfie en un geste.
      navigator.push(zRoute<void>(const SignupDoneScreen()));
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showZayaSnack(context, friendlyError(e), error: true);
      }
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _d.birthDate ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 90),
      lastDate: DateTime(now.year - 18, now.month, now.day),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Votre date de naissance',
    );
    if (picked != null && mounted) setState(() => _d.birthDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final progress = (_step.index + 1) / _Step.values.length;
    final showButton = _step != _Step.phone || _phoneVerified;

    return PopScope(
      canPop: _step.index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back), tooltip: 'Retour', onPressed: _back),
          title: Text('Étape ${_step.index + 1} sur ${_Step.values.length}',
              style: Theme.of(context).textTheme.bodyMedium),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: progress),
                  duration: ZMotion.of(context, ZMotion.medium),
                  curve: ZMotion.emphasized,
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 6,
                    backgroundColor: ZColors.line,
                    color: ZColors.primary,
                    semanticsLabel: 'Progression de l’inscription',
                  ),
                ),
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: Column(children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: ZMotion.of(context, ZMotion.medium),
                switchInCurve: ZMotion.emphasized,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  // L'étape entrante glisse depuis le côté correspondant au sens de navigation.
                  final entering = child.key == ValueKey<_Step>(_step);
                  final dx = (entering == _forward) ? 0.12 : -0.12;
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: Offset(dx, 0), end: Offset.zero).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: ListView(
                  key: ValueKey<_Step>(_step),
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                  children: _stepBody(context),
                ),
              ),
            ),
            if (showButton)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: GradientButton(label: _buttonLabel, busy: _saving, onPressed: _canContinue ? _next : null),
              ),
          ]),
        ),
      ),
    );
  }

  List<Widget> _title(BuildContext context, String title, String subtitle) => [
        Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 26)),
        const SizedBox(height: 8),
        Text(subtitle, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: ZColors.muted)),
        const SizedBox(height: 24),
      ];

  List<Widget> _stepBody(BuildContext context) {
    switch (_step) {
      case _Step.adult:
        return [
          ..._title(context, 'Bienvenue sur ZAYA',
              'ZAYA est destiné aux adultes qui recherchent une relation sérieuse en vue du mariage. Ce n’est pas un service de rencontres occasionnelles.'),
          ChoiceTile(
            icon: Icons.cake_outlined,
            label: 'J’ai 18 ans ou plus',
            subtitle: 'Votre date de naissance vous sera demandée pour le confirmer.',
            selected: _d.adultConfirmed,
            onTap: () => setState(() => _d.adultConfirmed = !_d.adultConfirmed),
          ),
        ];

      case _Step.name:
        return [
          ..._title(context, 'Comment vous appelez-vous ?',
              'Votre prénom, ou le nom que vous souhaitez afficher sur votre profil.'),
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: 40,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(labelText: 'Prénom ou nom d’affichage', counterText: ''),
            onChanged: (v) => setState(() => _d.displayName = v),
            onSubmitted: (_) {
              if (_canContinue) _next();
            },
          ),
        ];

      case _Step.birth:
        final birth = _d.birthDate;
        return [
          ..._title(context, 'Quelle est votre date de naissance ?',
              'Seul votre âge apparaît sur votre profil. Elle ne pourra plus être modifiée librement ensuite.'),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _pickBirthDate,
            child: InputDecorator(
              isEmpty: birth == null,
              decoration: InputDecoration(
                labelText: 'Date de naissance',
                suffixIcon: const Icon(Icons.calendar_today_outlined),
                errorText:
                    birth != null && !isAdult(birth) ? 'ZAYA est réservé aux personnes de 18 ans et plus.' : null,
              ),
              child: birth == null ? null : Text(formatDate(birth), style: const TextStyle(fontSize: 16)),
            ),
          ),
          if (birth != null && isAdult(birth)) ...[
            const SizedBox(height: 14),
            InfoBanner(icon: Icons.cake_outlined, text: 'Vous avez ${ageFrom(birth)} ans.'),
          ],
        ];

      case _Step.gender:
        return [
          ..._title(context, 'Vous êtes…', 'ZAYA vous proposera des profils en conséquence.'),
          ChoiceTile(
            icon: Icons.female,
            label: 'Une femme',
            selected: _d.gender == 'femme',
            onTap: () => setState(() => _d.gender = 'femme'),
          ),
          ChoiceTile(
            icon: Icons.male,
            label: 'Un homme',
            selected: _d.gender == 'homme',
            onTap: () => setState(() => _d.gender = 'homme'),
          ),
        ];

      case _Step.city:
        final query = _cityQuery.trim().toLowerCase();
        final cities = [
          for (final c in _cities)
            if (query.isEmpty || c.name.toLowerCase().contains(query)) c,
        ];
        return [
          ..._title(context, 'Où habitez-vous ?',
              'Seule votre ville est affichée, jamais votre adresse ni votre position exacte.'),
          if (_cities.length > 8) ...[
            TextField(
              decoration: const InputDecoration(hintText: 'Rechercher une ville', prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setState(() => _cityQuery = v),
            ),
            const SizedBox(height: 14),
          ],
          if (_cities.isEmpty)
            const InfoBanner(
              tone: BannerTone.warning,
              icon: Icons.wifi_off,
              text: 'La liste des villes n’a pas pu être chargée. Vérifiez votre connexion puis revenez à cette étape.',
            ),
          for (final c in cities)
            ChoiceTile(
              label: c.name,
              selected: _d.cityId == c.id,
              onTap: () => setState(() => _d.cityId = c.id),
            ),
        ];

      case _Step.horizon:
        return [
          ..._title(context, 'Votre projet de mariage',
              'Quel horizon envisagez-vous ? Vous pourrez le modifier à tout moment.'),
          for (final e in horizonLabels.entries)
            ChoiceTile(label: e.value, selected: _d.horizon == e.key, onTap: () => setState(() => _d.horizon = e.key)),
        ];

      case _Step.marital:
        return [
          ..._title(
              context, 'Votre situation matrimoniale', 'Facultatif. Vous choisissez ce que vous souhaitez indiquer.'),
          for (final e in maritalLabels.entries)
            ChoiceTile(
              label: e.value,
              selected: _d.maritalStatus == e.key,
              onTap: () => setState(() => _d.maritalStatus = _d.maritalStatus == e.key ? null : e.key),
            ),
        ];

      case _Step.nationality:
        final s = context.s;
        final lang = LanguageScope.maybeOf(context)?.language.code ?? 'fr';
        return [
          ..._title(context, s.onbNationalityTitle, s.onbNationalitySubtitle),
          if (_countries.isEmpty)
            InfoBanner(tone: BannerTone.warning, icon: Icons.wifi_off, text: s.onbListUnavailable),
          for (final c in _countries)
            ChoiceTile(
              label: c.name(lang),
              selected: _d.nationalityCode == c.code,
              onTap: () => setState(() => _d.nationalityCode = _d.nationalityCode == c.code ? null : c.code),
            ),
        ];

      case _Step.profession:
        final s = context.s;
        final lang = LanguageScope.maybeOf(context)?.language.code ?? 'fr';
        final query = _professionQuery.trim().toLowerCase();
        final matches = [
          for (final p in _professions)
            if (query.isEmpty || p.label(lang).toLowerCase().contains(query)) p,
        ];
        return [
          ..._title(context, s.onbProfessionTitle, s.onbProfessionSubtitle),
          if (_professions.isEmpty)
            InfoBanner(tone: BannerTone.warning, icon: Icons.wifi_off, text: s.onbListUnavailable)
          else ...[
            TextField(
              decoration: InputDecoration(hintText: s.onbProfessionSearch, prefixIcon: const Icon(Icons.search)),
              onChanged: (v) => setState(() => _professionQuery = v),
            ),
            const SizedBox(height: 14),
            if (matches.isEmpty) ...[
              Text(s.onbProfessionNoResult, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
            ],
            for (final p in matches)
              ChoiceTile(
                label: p.label(lang),
                selected: _d.professionId == p.id,
                onTap: () => setState(() {
                  _d.professionId = _d.professionId == p.id ? null : p.id;
                  if (_d.professionId != null) {
                    _d.professionOther = '';
                    _professionOther.clear();
                  }
                }),
              ),
          ],
          const SizedBox(height: 6),
          TextField(
            controller: _professionOther,
            maxLength: 60,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: s.onbProfessionOther),
            onChanged: (v) => setState(() {
              _d.professionOther = v;
              if (v.trim().isNotEmpty) _d.professionId = null;
            }),
          ),
        ];

      case _Step.education:
        final s = context.s;
        final lang = LanguageScope.maybeOf(context)?.language.code ?? 'fr';
        return [
          ..._title(context, s.onbEducationTitle, s.onbEducationSubtitle),
          if (_educationLevels.isEmpty)
            InfoBanner(tone: BannerTone.warning, icon: Icons.wifi_off, text: s.onbListUnavailable),
          for (final level in _educationLevels)
            ChoiceTile(
              label: level.label(lang),
              selected: _d.educationKey == level.key,
              onTap: () => setState(() => _d.educationKey = _d.educationKey == level.key ? null : level.key),
            ),
        ];

      case _Step.children:
        final s = context.s;
        final count = _d.childrenCount;
        final many = count != null && count >= 5;
        return [
          ..._title(context, s.onbChildrenTitle, s.onbChildrenSubtitle),
          for (var n = 0; n <= 4; n++)
            ChoiceTile(
              label: n == 0 ? s.childrenNone : s.childrenCount(n),
              selected: count == n,
              onTap: () => setState(() => _d.childrenCount = count == n ? null : n),
            ),
          ChoiceTile(
            label: s.childrenFiveOrMore,
            selected: many,
            onTap: () => setState(() => _d.childrenCount = many ? null : 5),
          ),
          // « 5 ou plus » : le nombre exact se règle ici (5 à 20), pour que la fiche affiche le bon chiffre.
          if (many)
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton.outlined(
                icon: const Icon(Icons.remove),
                tooltip: '−1',
                onPressed: count > 5 ? () => setState(() => _d.childrenCount = count - 1) : null,
              ),
              SizedBox(
                width: 120,
                child: Text(s.childrenCount(count),
                    textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
              ),
              IconButton.outlined(
                icon: const Icon(Icons.add),
                tooltip: '+1',
                onPressed: count < 20 ? () => setState(() => _d.childrenCount = count + 1) : null,
              ),
            ]),
        ];

      case _Step.confession:
        return [
          ..._title(context, 'Votre confession',
              'Facultatif. ZAYA accueille toutes les confessions et ne déduit jamais la vôtre.'),
          for (final e in confessionLabels.entries)
            ChoiceTile(
              label: e.value,
              selected: _d.confession == e.key,
              onTap: () => setState(() {
                _d.confession = _d.confession == e.key ? null : e.key;
                if (!_hasConfession) {
                  _d.confessionConsent = false;
                  if (_d.confessionMode == 'mine_only') _d.confessionMode = 'no_filter';
                }
              }),
            ),
          if (_hasConfession)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _d.confessionConsent,
              onChanged: (v) => setState(() => _d.confessionConsent = v ?? false),
              title: const Text(
                'J’accepte que ZAYA enregistre ma confession pour me proposer des profils selon mes préférences. '
                'Elle n’est jamais utilisée pour la publicité.',
                style: TextStyle(fontSize: 14, height: 1.35),
              ),
            ),
        ];

      case _Step.discovery:
        return [
          ..._title(context, 'Qui souhaitez-vous découvrir ?',
              'Ces réglages filtrent uniquement les profils qui vous sont proposés. Vous pourrez les changer à tout moment.'),
          Text('Âge recherché : ${_d.ageMin} – ${_d.ageMax} ans', style: Theme.of(context).textTheme.titleMedium),
          RangeSlider(
            min: 18,
            max: 70,
            divisions: 52,
            values: RangeValues(_d.ageMin.toDouble(), _d.ageMax.toDouble()),
            labels: RangeLabels('${_d.ageMin}', '${_d.ageMax}'),
            onChanged: (values) => setState(() {
              _d.ageMin = values.start.round();
              _d.ageMax = values.end.round();
            }),
          ),
          const SizedBox(height: 12),
          Text('Préférence confessionnelle', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          for (final e in confessionModeLabels.entries)
            if (e.key != 'mine_only' || _hasConfession)
              ChoiceTile(
                label: e.value,
                selected: _d.confessionMode == e.key,
                onTap: () => setState(() => _d.confessionMode = e.key),
              ),
          if (_d.confessionMode == 'selected')
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final e in confessionLabels.entries)
                if (e.key != 'undisclosed')
                  FilterChip(
                    label: Text(e.value),
                    selected: _d.selectedConfessions.contains(e.key),
                    selectedColor: ZColors.primarySoft,
                    checkmarkColor: ZColors.primaryDark,
                    onSelected: (on) =>
                        setState(() => on ? _d.selectedConfessions.add(e.key) : _d.selectedConfessions.remove(e.key)),
                  ),
            ]),
          const SizedBox(height: 10),
          Text('Les personnes qui n’ont pas précisé leur confession restent proposées.',
              style: Theme.of(context).textTheme.bodyMedium),
        ];

      case _Step.bio:
        return [
          ..._title(context, 'Quelques mots sur vous',
              'Facultatif. Une présentation sincère aide les autres à mieux vous connaître.'),
          TextField(
            controller: _bio,
            maxLines: 6,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Vos valeurs, votre quotidien, ce que vous recherchez…',
              alignLabelWithHint: true,
            ),
            onChanged: (v) => setState(() => _d.bio = v),
          ),
        ];

      case _Step.phone:
        return [
          ..._title(context, 'Vérifiez votre numéro', 'Un code vous est envoyé par SMS pour sécuriser votre compte.'),
          if (_phoneVerified)
            const InfoBanner(tone: BannerTone.success, icon: Icons.check_circle, text: 'Votre numéro est vérifié.')
          else
            PhoneOtpForm(
              initialPhone: _d.phone.replaceFirst('+224', ''),
              onVerified: (phone) {
                setState(() {
                  _d.phone = phone;
                  _phoneVerified = true;
                });
                _next();
              },
            ),
        ];

      case _Step.rules:
        return [
          ..._title(context, 'Les règles de ZAYA', 'Prenez-en connaissance avant d’entrer.'),
          const _Rule(Icons.favorite_border, 'Respect et intentions sérieuses',
              'Pas de harcèlement, d’insultes, de nudité ni de contenu sexuel.'),
          const _Rule(Icons.payments_outlined, 'Jamais d’argent',
              'N’envoyez jamais d’argent ni de code à une personne rencontrée en ligne.'),
          const _Rule(Icons.shield_outlined, 'Signalez et bloquez librement',
              'Ces protections sont gratuites et accessibles depuis chaque profil et conversation.'),
          const SizedBox(height: 4),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _d.acceptedTerms,
            onChanged: (v) => setState(() => _d.acceptedTerms = v ?? false),
            title: const Text(
              'J’accepte les Conditions d’utilisation, la Politique de confidentialité et les Règles communautaires de ZAYA.',
              style: TextStyle(fontSize: 14, height: 1.35),
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _d.marketingConsent,
            onChanged: (v) => setState(() => _d.marketingConsent = v ?? false),
            title: const Text(
              'J’accepte de recevoir des actualités et des offres de ZAYA (facultatif).',
              style: TextStyle(fontSize: 14, height: 1.35),
            ),
          ),
        ];
    }
  }
}

class _Rule extends StatelessWidget {
  const _Rule(this.icon, this.title, this.text);
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: ZColors.primarySoft, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: ZColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(text, style: Theme.of(context).textTheme.bodyMedium),
            ]),
          ),
        ]),
      );
}
