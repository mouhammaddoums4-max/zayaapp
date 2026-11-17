import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/theme.dart';
import 'data/demo_repository.dart';
import 'data/repository.dart';
import 'data/supabase_repository.dart';

/// Configuration injectée à la compilation. Aucun secret : la clé « publishable » (anciennement « anon »)
/// est publique par conception et les données sont protégées par les règles RLS du serveur.
///
///   flutter run --dart-define-from-file=env.staging.json
///
/// Sans ces valeurs, l'application démarre en mode démo (données fictives, aucun serveur).
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
  defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Plein écran : les barres du téléphone, transparentes, prennent la couleur de l'écran affiché (voir zSystemUi).
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(zSystemUi);
  _registerFontLicenses();
  late final ZayaRepository repository;
  if (_supabaseUrl.isEmpty || _supabaseKey.isEmpty) {
    repository = DemoRepository();
  } else {
    await Supabase.initialize(url: _supabaseUrl, publishableKey: _supabaseKey);
    repository = SupabaseRepository(Supabase.instance.client);
  }
  runApp(ZayaApp(repository: repository));
}

/// Les polices Inter et Sora sont embarquées (assets/google_fonts) sous licence SIL Open Font License.
void _registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const ['Inter'], await rootBundle.loadString('assets/google_fonts/OFL-Inter.txt'));
    yield LicenseEntryWithLineBreaks(const ['Sora'], await rootBundle.loadString('assets/google_fonts/OFL-Sora.txt'));
  });
}
