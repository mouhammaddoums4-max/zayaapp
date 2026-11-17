import 'package:material_ui/material_ui.dart';

import '../../core/widgets.dart';

/// Centre de notifications ouvert depuis la cloche de l'en-tête de Découvrir.
///
/// Les notifications push arrivent au lot B (FCM). D'ici là, l'écran n'affiche que ce qui existe
/// réellement : jamais de fausse notification ni de fausse pastille (CDC §22.17).
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const EmptyState(
          icon: Icons.notifications_none_rounded,
          title: 'Aucune notification',
          message: 'Vos nouveaux matchs, vos messages et le résultat de votre vérification apparaîtront ici.',
        ),
      );
}
