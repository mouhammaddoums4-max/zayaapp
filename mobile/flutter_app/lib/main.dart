import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
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
  late final ZayaRepository repository;
  if (_supabaseUrl.isEmpty || _supabaseKey.isEmpty) {
    repository = DemoRepository();
  } else {
    await Supabase.initialize(url: _supabaseUrl, publishableKey: _supabaseKey);
    repository = SupabaseRepository(Supabase.instance.client);
  }
  runApp(ZayaApp(repository: repository));
}
