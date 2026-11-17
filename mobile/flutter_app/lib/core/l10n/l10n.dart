import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'strings.dart';
import 'strings_en.dart';
import 'strings_fr.dart';

export 'strings.dart';

/// L'anglais n'est proposé que lorsque **tous** les écrans sont traduits (cahier des charges §22.15 : ne jamais
/// présenter une langue comme prise en charge avant que ses écrans essentiels le soient).
const bool englishInterfaceComplete = false;

/// Langues de l'interface. Le pular, le maninka et le soussou sont préparés pour la Guinée ; ils restent
/// « bientôt disponibles » tant que leurs traductions n'ont pas été écrites et relues par des locuteurs.
enum AppLanguage {
  fr(code: 'fr', nativeName: 'Français'),
  en(code: 'en', nativeName: 'English'),
  pular(code: 'fuf', nativeName: 'Pular'),
  maninka(code: 'emk', nativeName: 'Maninkakan'),
  soso(code: 'sus', nativeName: 'Sosoxui');

  const AppLanguage({required this.code, required this.nativeName});

  /// Code de langue (ISO 639), aussi utilisé dans `app_config.active_languages` et `legal_documents.lang`.
  final String code;

  /// Nom de la langue dans la langue elle-même : reconnaissable quelle que soit la langue affichée.
  final String nativeName;

  /// Toutes les chaînes de l'application existent dans cette langue.
  bool get isTranslated => switch (this) {
        AppLanguage.fr => true,
        AppLanguage.en => englishInterfaceComplete,
        _ => false,
      };

  static AppLanguage? fromCode(String? code) {
    for (final l in AppLanguage.values) {
      if (l.code == code) return l;
    }
    return null;
  }
}

/// Langue choisie par le membre, mémorisée sur le téléphone (réglage local, CARTE_ECRANS F14).
/// Indépendante des langues parlées indiquées sur le profil.
class LanguageController extends ChangeNotifier {
  LanguageController({AppLanguage initial = AppLanguage.fr}) : _language = initial;

  static const prefsKey = 'zaya_app_language';

  AppLanguage _language;
  AppLanguage get language => _language;

  ZStrings get strings => stringsFor(_language);

  Locale get locale => Locale(_language == AppLanguage.en ? 'en' : 'fr');

  static ZStrings stringsFor(AppLanguage language) =>
      language == AppLanguage.en && language.isTranslated ? const ZStringsEn() : const ZStringsFr();

  /// Reprend la langue mémorisée ; à défaut, celle du téléphone si elle est disponible ; sinon le français.
  Future<void> restore() async {
    AppLanguage? found;
    try {
      final prefs = await SharedPreferences.getInstance();
      found = AppLanguage.fromCode(prefs.getString(prefsKey));
    } catch (_) {
      // Stockage indisponible : on garde la langue par défaut.
    }
    found ??= AppLanguage.fromCode(WidgetsBinding.instance.platformDispatcher.locale.languageCode);
    if (found != null && found.isTranslated && found != _language) {
      _language = found;
      notifyListeners();
    }
  }

  Future<void> select(AppLanguage language) async {
    if (!language.isTranslated || language == _language) return;
    _language = language;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, language.code);
    } catch (_) {
      // Le choix reste actif pour cette session.
    }
  }
}

/// Rend la langue accessible à tous les écrans : `ZStrings.of(context)`, `LanguageScope.of(context)`.
class LanguageScope extends InheritedNotifier<LanguageController> {
  const LanguageScope({super.key, required LanguageController controller, required super.child})
      : super(notifier: controller);

  static LanguageController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LanguageScope>()?.notifier;

  static LanguageController of(BuildContext context) => maybeOf(context)!;
}

/// Raccourci : `context.s.settingsTitle`.
extension ZStringsContext on BuildContext {
  ZStrings get s => LanguageScope.maybeOf(this)?.strings ?? const ZStringsFr();
}
