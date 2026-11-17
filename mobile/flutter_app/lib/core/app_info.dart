/// Version affichée dans les Réglages. Doit rester identique à `version:` de pubspec.yaml
/// (vérifié par test/app_info_test.dart).
const String appVersion = '0.1.0';
const int appBuildNumber = 1;

String get appVersionLabel => '$appVersion ($appBuildNumber)';
