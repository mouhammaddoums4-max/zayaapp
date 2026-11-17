import 'package:in_app_review/in_app_review.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_info.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

enum UpdateLevel { none, available, required }

/// Résultat de la comparaison entre la version installée et `app_config` (migration 0014).
class UpdateStatus {
  const UpdateStatus(this.level, {this.latest = appVersion, this.url = ''});
  const UpdateStatus.none() : this(UpdateLevel.none);

  final UpdateLevel level;
  final String latest;
  final String url;
}

/// Sans réglage lisible, rien n'est imposé : l'application reste utilisable.
UpdateStatus evaluateUpdate(Map<String, Object?> config, {String current = appVersion}) {
  final min = (config['min_app_version'] ?? '').toString();
  final latest = (config['latest_app_version'] ?? '').toString();
  final url = (config['app_update_url'] ?? '').toString().trim();
  if (min.isNotEmpty && compareVersions(current, min) < 0) {
    return UpdateStatus(UpdateLevel.required, latest: latest.isEmpty ? min : latest, url: url);
  }
  if (latest.isNotEmpty && compareVersions(current, latest) < 0) {
    return UpdateStatus(UpdateLevel.available, latest: latest, url: url);
  }
  return const UpdateStatus.none();
}

/// Ouvre le lien de mise à jour, ou à défaut la fiche Google Play de l'application.
Future<void> openAppUpdate(BuildContext context, String url) async {
  final s = context.s;
  final messenger = ScaffoldMessenger.of(context);
  var ok = false;
  try {
    if (url.isNotEmpty) {
      ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      await InAppReview.instance.openStoreListing();
      ok = true;
    }
  } catch (_) {
    ok = false;
  }
  if (!ok) messenger.showSnackBar(SnackBar(content: Text(s.updateUnavailable), behavior: SnackBarBehavior.floating));
}

/// Mise à jour obligatoire : la version installée est en dessous de `min_app_version`.
class RequiredUpdateScreen extends StatelessWidget {
  const RequiredUpdateScreen({super.key, required this.status});
  final UpdateStatus status;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      body: SafeArea(
        child: FillOrScroll(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.system_update, size: 64, color: ZColors.primary),
            const SizedBox(height: 20),
            Text(s.updateRequiredTitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            Text(s.updateRequiredBody(appVersion, status.latest),
                textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 28),
            GradientButton(
                label: s.updateNow, icon: Icons.download, onPressed: () => openAppUpdate(context, status.url)),
          ]),
        ),
      ),
    );
  }
}

/// Proposition de mise à jour (non bloquante), affichée une fois par version.
Future<void> showUpdateAvailableDialog(BuildContext context, UpdateStatus status) {
  final s = context.s;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.system_update, color: ZColors.primary, size: 36),
      title: Text(s.updateAvailableTitle),
      content: Text(s.updateAvailableBody(status.latest)),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(s.updateLater)),
        TextButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            openAppUpdate(context, status.url);
          },
          child: Text(s.updateNow),
        ),
      ],
    ),
  );
}
