import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Top-level background message handler.
/// Must be a top-level function (not a method) for FCM.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  log('[FCM] Background message: ${message.messageId} | ${message.notification?.title}');
  // No UI work here — Flutter is not ready in background isolate.
}

/// Service that initialises Firebase Messaging, requests permission,
/// saves the FCM token to Firestore, and handles foreground/opened notifications.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Call once from main() after Firebase.initializeApp().
  static Future<void> registerBackgroundHandler() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  /// Call after the user is authenticated and the app is mounted.
  Future<void> init(BuildContext context) async {
    // 1. Request permission (iOS/Android 13+)
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    log('[FCM] Permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    // 2. Get & save token
    final token = await _fcm.getToken();
    if (token != null) {
      await _saveTokenToFirestore(token);
    }

    // 3. Refresh token listener
    _fcm.onTokenRefresh.listen(_saveTokenToFirestore);

    // 4. Foreground messages — show a SnackBar / in-app banner
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      log('[FCM] Foreground message: ${message.notification?.title}');
      if (!context.mounted) return;
      final notification = message.notification;
      if (notification != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${notification.title ?? ''}: ${notification.body ?? ''}'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });

    // 5. Message opened from notification tray
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      log('[FCM] Opened via notification: ${message.data}');
      if (!context.mounted) return;
      _handleNotificationRoute(context, message.data);
    });

    // 6. App launched from terminated state via notification
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      log('[FCM] App launched via notification: ${initialMessage.data}');
      // Delay to allow the router to initialise
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          _handleNotificationRoute(context, initialMessage.data);
        }
      });
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await _firestore.collection('users').doc(uid).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'lastActive': FieldValue.serverTimestamp(),
      });
      log('[FCM] Token saved for $uid');
    } catch (e) {
      log('[FCM] Failed to save token: $e');
    }
  }

  /// Routes the user to the appropriate screen based on notification payload.
  void _handleNotificationRoute(BuildContext context, Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final id = data['id'] as String? ?? data['battleId'] as String?;

    switch (type) {
      case 'duel':
      case 'battle_challenge': // Supports notifications sent before the v2 payload.
        if (id != null) context.push('/home/compete/duel/$id');
        break;
      case 'chat':
        if (id != null) {
          context.push('/home/social/chat/$id',
              extra: {'chatTitle': data['chatTitle'] ?? 'Chat', 'type': data['chatType'] ?? 'dm'});
        }
        break;
      case 'mission':
        context.push('/home/missions');
        break;
      default:
        break;
    }
  }
}

/// Riverpod provider for easy access.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
