import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

enum NotificationType {
  streakAtRisk,
  incomingDuel,
  crateAvailable,
  levelUp,
  questComplete,
  systemAlert,
}

class HunterNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  const HunterNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
  });

  String get typeEmoji {
    switch (type) {
      case NotificationType.streakAtRisk:
        return '🔥';
      case NotificationType.incomingDuel:
        return '⚔️';
      case NotificationType.crateAvailable:
        return '📦';
      case NotificationType.levelUp:
        return '⬆️';
      case NotificationType.questComplete:
        return '✅';
      case NotificationType.systemAlert:
        return '🤖';
    }
  }

  factory HunterNotification.fromMap(String id, Map<String, dynamic> map) {
    return HunterNotification(
      id: id,
      type: _parseType(map['type'] as String? ?? 'systemAlert'),
      title: map['title'] as String? ?? '[SYSTEM]',
      body: map['body'] as String? ?? '',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      isRead: map['isRead'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'title': title,
        'body': body,
        'createdAt': Timestamp.fromDate(createdAt),
        'isRead': isRead,
      };

  HunterNotification copyWith({bool? isRead}) => HunterNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        createdAt: createdAt,
        isRead: isRead ?? this.isRead,
      );

  static NotificationType _parseType(String raw) {
    return NotificationType.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => NotificationType.systemAlert,
    );
  }
}

// ─── Service ──────────────────────────────────────────────────────────────────

/// WHY THIS SERVICE EXISTS:
/// Players had no way to see incoming duel challenges, streak warnings, or
/// crate availability without manually navigating to specific screens.
/// This service writes structured notification records to Firestore and
/// provides a stream for the bell widget to render an unread badge count.
class NotificationsService {
  final FirebaseFirestore _db;

  NotificationsService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _notifCol(String uid) =>
      _db.collection('users').doc(uid).collection('notifications');

  /// Streams the 20 most recent notifications for the given hunter.
  Stream<List<HunterNotification>> watchNotifications(String uid) {
    return _notifCol(uid)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => HunterNotification.fromMap(doc.id, doc.data()))
            .toList());
  }

  /// Posts a new notification for the given hunter.
  Future<void> sendNotification({
    required String uid,
    required NotificationType type,
    required String title,
    required String body,
  }) async {
    await _notifCol(uid).add({
      'type': type.name,
      'title': title,
      'body': body,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  /// Marks a single notification as read.
  Future<void> markRead(String uid, String notificationId) async {
    await _notifCol(uid).doc(notificationId).update({'isRead': true});
  }

  /// Marks all notifications as read.
  Future<void> markAllRead(String uid) async {
    final batch = _db.batch();
    final unread = await _notifCol(uid).where('isRead', isEqualTo: false).get();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  /// Evaluates the hunter's current game state and sends relevant notifications.
  ///
  /// Call this on app foreground return or after completing a mission to ensure
  /// the player is always informed of critical state changes.
  Future<void> evaluateAndNotify({
    required String uid,
    required bool isStreakAtRisk,
    required bool hasCrateAvailable,
    required bool hasPendingDuels,
  }) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final sentRef = _db
        .collection('users')
        .doc(uid)
        .collection('notificationSentLog')
        .doc(today);

    final sentDoc = await sentRef.get();
    final alreadySent = (sentDoc.data() ?? <String, bool>{}).cast<String, bool>();

    final futures = <Future<void>>[];

    if (isStreakAtRisk && alreadySent['streakRisk'] != true) {
      futures.add(sendNotification(
        uid: uid,
        type: NotificationType.streakAtRisk,
        title: '[SYSTEM ALERT] STREAK AT RISK',
        body: 'Complete any daily quest before midnight to preserve your streak multiplier!',
      ));
      alreadySent['streakRisk'] = true;
    }

    if (hasCrateAvailable && alreadySent['crate'] != true) {
      futures.add(sendNotification(
        uid: uid,
        type: NotificationType.crateAvailable,
        title: '📦 DAILY SUPPLY CRATE READY',
        body: 'Your Hunter Guild Supply Crate is available! Tap to claim your daily XP boost.',
      ));
      alreadySent['crate'] = true;
    }

    if (hasPendingDuels && alreadySent['duel'] != true) {
      futures.add(sendNotification(
        uid: uid,
        type: NotificationType.incomingDuel,
        title: '⚔️ DUEL CHALLENGE RECEIVED',
        body: 'A rival hunter has challenged you to a Stat Battle. Accept or decline in the Arena!',
      ));
      alreadySent['duel'] = true;
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
      await sentRef.set(alreadySent);
    }
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final notificationsServiceProvider = Provider<NotificationsService>((ref) {
  return NotificationsService();
});

final hunterNotificationsProvider =
    StreamProvider.family<List<HunterNotification>, String>((ref, uid) {
  if (uid.isEmpty) return Stream.value([]);
  return ref.watch(notificationsServiceProvider).watchNotifications(uid);
});

/// Derived provider: count of unread notifications for badge display.
final unreadNotificationsCountProvider =
    Provider.family<int, String>((ref, uid) {
  final notifs = ref.watch(hunterNotificationsProvider(uid));
  return notifs.maybeWhen(
    data: (list) => list.where((n) => !n.isRead).length,
    orElse: () => 0,
  );
});
