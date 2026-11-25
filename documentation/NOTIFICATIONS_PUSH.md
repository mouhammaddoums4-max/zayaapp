# Notifications push

Le client Android utilise Firebase Cloud Messaging. Il demande l'autorisation après la connexion, enregistre le jeton
FCM via les fonctions RLS de `0060_jetons_notifications.sql`, supprime ce jeton à la déconnexion et joue le son de
notification configuré par le téléphone. Le contenu privé d'un message n'est jamais placé dans une notification.

## État du serveur Supabase

Le code de `supabase/functions/push-dispatch/` traite les signaux `message` et `match` de `member_signals`. Il envoie
un texte neutre via FCM HTTP v1 ; les autres événements ne sont pas transmis. Le compte de service Firebase ne doit
jamais être copié dans le dépôt ou l'application mobile.

Les migrations `0055_signaux_instantanes.sql`, `0060_jetons_notifications.sql`,
`0061_webhook_notifications.sql`, `0062_messages_vocaux.sql` et
`0063_statuts_reception_messages.sql` sont appliquées au projet Supabase `wocgmmwwopzrgleeevof`.
La fonction `push-dispatch` est déployée avec sa vérification JWT de passerelle désactivée ;
elle valide son en-tête `x-push-webhook-secret`. Le webhook asynchrone `pg_net` est raccordé
à `member_signals`, et son URL et son secret sont rangés dans Supabase Vault. Le secret de
webhook est également enregistré dans les secrets de la fonction. Aucun secret n'est stocké
dans ce dépôt.

Le secret `FIREBASE_SERVICE_ACCOUNT_JSON` est configuré dans Supabase et un jeton FCM avait été enregistré sur un appareil.
Le client a maintenant un canal Android v3 avec son par défaut et pastille activée. Le push FCM envoie aussi le nombre
de messages non lus et remplace l'alerte précédente du même type. Les erreurs d'initialisation et d'enregistrement sont
visibles dans les journaux Android sans y inclure de jeton. Ce code et la migration 0065 restent à déployer sur la
préproduction ; le projet distant est nommé `zaya-production`, donc cette opération attend une autorisation explicite.
L'envoi FCM de bout en bout reste à vérifier sur le téléphone après installation de la nouvelle APK :

1. Installer la dernière APK et connecter le compte sur l'appareil.
2. Vérifier qu'un nouveau message ou match déclenche la notification et son son par défaut.
3. Si besoin, autoriser les notifications de ZAYA et le son du canal « Messages et matchs ZAYA » dans Android.

Le projet distant ne possédait pas `supabase_migrations.schema_migrations`. Les migrations ont donc été
appliquées directement avec le SQL de leurs fichiers ; elles ne sont pas enregistrées dans l'historique CLI.
Ne pas lancer `supabase db push` avant d'avoir réconcilié l'historique existant.

Le fichier `android/app/google-services.json` correspond au package Android `com.zaya.app.zaya`. iOS n'est pas encore
configuré : il faut son `GoogleService-Info.plist`, activer les notifications push dans Xcode et configurer APNs dans
Firebase avant d'activer les notifications iOS.

Android utilise l'icône système `ic_stat_notification` et le canal sonore `zaya_notifications_v3` afin de créer un
canal avec le son par défaut sur les installations antérieures. Le son dépend aussi du réglage Android de ce canal,
du volume de notification et du mode silencieux du téléphone. L'affichage d'un nombre sur l'icône du lanceur dépend
du lanceur Android ; les appareils qui n'affichent que des points montrent une pastille sans chiffre.
