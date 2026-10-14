// lib/core/services/notification_service.dart
// ─────────────────────────────────────────────────────────────
// Handles Firebase Cloud Messaging for SahiReport.
//  - Requests permission
//  - Gets the FCM token (web uses the VAPID key)
//  - Saves the token to owners.fcm_token
//  - Shows foreground notifications (mobile via local notifications)
//  - Handles notification TAPS in all app states (foreground,
//    background, terminated) by bringing the app forward.
//
// Channel id "sahi_report_submissions" matches the channel_id sent
// by the send-notification Edge Function. They MUST stay in sync.
//
// Designed to fail soft: any error is caught and logged so a
// notification problem can never crash the app.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  NotificationService._();

  // Web Push (VAPID) key from Firebase → Cloud Messaging → Web config.
  static const String _vapidKey =
      'BE1Mz10eNmAa3UiZ3y93fX0Ce3xeaS6ODAzl8En9qEKHeZO2XC_2BJCqYAlpu98m9cnoYXtdOi83XMP27eTXN0Q';

  // Must match the Edge Function's android.notification.channel_id.
  static const String _channelId = 'sahi_report_submissions';
  static const String _channelName = 'New Submissions';

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();
  static bool _localReady = false;

  // Optional hook: assign this to navigate when a notification is tapped.
  // With "just open the app" behaviour this can stay null — tapping still
  // foregrounds the app.
  static void Function(Map<String, dynamic> data)? onNotificationTap;

  // ── Initialise: permission + handlers ─────────────────────
  static Future<void> initialize() async {
    try {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (!kIsWeb) {
        await _initLocalNotifications();
      }

      // Foreground messages: on mobile, surface via local notification.
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (!kIsWeb) _showLocal(message);
      });

      // App in BACKGROUND, opened by tapping the FCM notification.
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleTap(message.data);
      });

      // App was TERMINATED, cold-started by tapping the notification.
      final initial = await _messaging.getInitialMessage();
      if (initial != null) {
        _handleTap(initial.data);
      }
    } catch (e) {
      debugPrint('NotificationService.initialize failed (non-critical): $e');
    }
  }

  static Future<void> _initLocalNotifications() async {
    if (_localReady) return;
    const androidInit =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const settings =
    InitializationSettings(android: androidInit, iOS: iosInit);

    await _localNotifications.initialize(
      settings,
      // FOREGROUND local-notification tap handler (the missing link).
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        _handleTap(
            payload != null ? {'route': payload} : <String, dynamic>{});
      },
    );

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Alerts when a field user submits a report',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    _localReady = true;
  }

  static Future<void> _showLocal(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _localNotifications.show(
      n.hashCode,
      n.title ?? 'SahiReport',
      n.body ?? '',
      details,
      payload: message.data['route'] as String?,
    );
  }

  // Central tap handler — fires the optional navigation hook if set.
  static void _handleTap(Map<String, dynamic> data) {
    try {
      onNotificationTap?.call(data);
    } catch (e) {
      debugPrint('onNotificationTap failed (non-critical): $e');
    }
  }

  // ── Get the token and save it to owners.fcm_token ─────────
  static Future<void> getAndSaveFCMToken(String ownerId) async {
    try {
      final token = kIsWeb
          ? await _messaging.getToken(vapidKey: _vapidKey)
          : await _messaging.getToken();

      if (token == null) return;

      await Supabase.instance.client
          .from('owners')
          .update({'fcm_token': token}).eq('id', ownerId);
    } catch (e) {
      debugPrint('getAndSaveFCMToken failed (non-critical): $e');
    }
  }

  // ── Keep the token fresh if it rotates ────────────────────
  static void listenTokenRefresh(String ownerId) {
    try {
      _messaging.onTokenRefresh.listen((token) async {
        try {
          await Supabase.instance.client
              .from('owners')
              .update({'fcm_token': token}).eq('id', ownerId);
        } catch (e) {
          debugPrint('token refresh save failed (non-critical): $e');
        }
      });
    } catch (e) {
      debugPrint('listenTokenRefresh failed (non-critical): $e');
    }
  }
}