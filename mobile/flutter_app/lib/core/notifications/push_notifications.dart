import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// A fresh channel refreshes sound and badge settings saved by Android on existing installs.
const _channelId = 'zaya_notifications_v3';
const _notificationIcon = 'ic_stat_notification';

/// Notifications push Android. Le contenu affiché reste neutre : aucun texte privé n'est repris du payload.
class PushNotifications {
  PushNotifications._();
  static final instance = PushNotifications._();

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  SupabaseClient? _db;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  bool _ready = false;
  bool _starting = false;

  /// Démarre FCM uniquement pour l'application connectée, jamais en mode démo.
  Future<void> attach(SupabaseClient db) async {
    if (!Platform.isAndroid || _authSubscription != null) return;
    _db = db;
    _authSubscription = db.auth.onAuthStateChange.listen((_) {
      if (db.auth.currentUser == null) return;
      if (_ready) {
        unawaited(FirebaseMessaging.instance.getToken().then(_saveToken));
      } else {
        unawaited(_enableForSignedInUser());
      }
    });
    if (db.auth.currentUser != null) await _enableForSignedInUser();
  }

  Future<void> _enableForSignedInUser() async {
    final db = _db;
    final userId = db?.auth.currentUser?.id;
    if (db == null || userId == null || _ready || _starting) return;
    _starting = true;
    try {
      await Firebase.initializeApp();
      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings(_notificationIcon),
        ),
      );
      const channel = AndroidNotificationChannel(
        _channelId,
        'Messages et matchs ZAYA',
        description: 'Nouveaux matchs et messages',
        importance: Importance.high,
        playSound: true,
        showBadge: true,
      );
      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      final permission = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (permission.authorizationStatus == AuthorizationStatus.authorized ||
          permission.authorizationStatus == AuthorizationStatus.provisional) {
        _ready = true;
        _messageSubscription ??= FirebaseMessaging.onMessage.listen(_showForegroundNotification);
        _tokenSubscription ??= FirebaseMessaging.instance.onTokenRefresh.listen(_saveToken);
        await _saveToken(await FirebaseMessaging.instance.getToken());
      }
    } catch (error) {
      // Une panne de notifications ne doit jamais empêcher l'ouverture de l'application.
      debugPrint('ZAYA push initialization failed (${error.runtimeType}).');
    } finally {
      _starting = false;
    }
  }

  Future<void> _saveToken(String? token) async {
    final db = _db;
    final userId = db?.auth.currentUser?.id;
    if (db == null || token == null || userId == null) return;
    try {
      await db.rpc('register_push_token', params: {'p_token': token, 'p_platform': 'android'});
    } catch (error) {
      // Les notifications restent facultatives si la migration serveur n'est pas encore appliquée.
      debugPrint('ZAYA push token registration failed (${error.runtimeType}).');
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final kind = message.data['kind'];
    final title = switch (kind) {
      'message' => 'Nouveau message',
      'match' => 'Nouveau match',
      _ => 'ZAYA',
    };
    final body = switch (kind) {
      'message' => 'Vous avez reçu un message.',
      'match' => 'Une nouvelle rencontre vous attend.',
      _ => 'Vous avez une nouvelle notification.',
    };
    int? unreadCount;
    if (kind == 'message') {
      final db = _db;
      final userId = db?.auth.currentUser?.id;
      if (db != null && userId != null) {
        try {
          final count = await db.rpc('unread_message_count', params: {'p_user': userId});
          if (count is num) unreadCount = count.toInt();
        } catch (_) {
          // L'alerte s'affiche même si le compteur de badge n'est pas disponible.
        }
      }
    }
    await _local.show(
      id: kind == 'message' ? 1 : 2,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Messages et matchs ZAYA',
          channelDescription: 'Nouveaux matchs et messages',
          icon: _notificationIcon,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          number: unreadCount,
          tag: kind == 'message' ? 'zaya-unread-messages' : 'zaya-new-match',
        ),
      ),
    );
  }

  /// Retire le jeton avant la déconnexion pour qu'un autre membre du téléphone ne reçoive pas ses alertes.
  Future<void> unregisterCurrentDevice(SupabaseClient db) async {
    if (!_ready) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await db.rpc('unregister_push_token', params: {'p_token': token});
    } catch (_) {
      // La déconnexion continue même si Firebase est indisponible.
    }
  }
}
