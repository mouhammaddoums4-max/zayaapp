/// Version affichée dans les Réglages. Doit rester identique à `version:` de pubspec.yaml
/// (vérifié par test/app_info_test.dart).
const String appVersion = '0.1.0';
const int appBuildNumber = 1;

String get appVersionLabel => '$appVersion ($appBuildNumber)';

/// Compare deux versions « 1.2.3 » : négatif si [a] < [b], 0 si égales, positif sinon.
/// Les parties absentes ou illisibles valent 0 (« 1.2 » == « 1.2.0 »).
int compareVersions(String a, String b) {
  List<int> parts(String v) =>
      [for (final p in v.trim().split('.')) int.tryParse(p.split(RegExp(r'[^0-9]')).first) ?? 0];
  final x = parts(a);
  final y = parts(b);
  for (var i = 0; i < 3; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d;
  }
  return 0;
}
