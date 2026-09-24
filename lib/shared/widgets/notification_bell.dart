import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:studycompete/shared/services/notifications_service.dart';

/// A bell icon widget that displays an unread-count badge and opens a
/// notification drawer when tapped.
///
/// WHY THIS WIDGET EXISTS:
/// Players had no ambient feedback about incoming duels, streak warnings, or
/// crate drops unless they manually navigated to each screen. This bell gives
/// them a persistent, low-friction way to see what the System wants them to do.
///
/// Usage: Drop `NotificationBell(uid: uid)` into any AppBar's `actions` list.
class NotificationBell extends ConsumerWidget {
  final String uid;

  const NotificationBell({super.key, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationsCountProvider(uid));

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Hunter Notifications',
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () => _showNotificationPanel(context, ref),
        ),
        if (unreadCount > 0)
          Positioned(
            top: 6,
            right: 6,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  unreadCount > 9 ? '9+' : '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showNotificationPanel(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NotificationPanel(uid: uid),
    );
  }
}

class _NotificationPanel extends ConsumerWidget {
  final String uid;

  const _NotificationPanel({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(hunterNotificationsProvider(uid));
    final service = ref.read(notificationsServiceProvider);
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Handle bar ──────────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active, color: Color(0xFF38BDF8), size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'SYSTEM NOTIFICATIONS',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => service.markAllRead(uid),
                    child: const Text(
                      'Mark All Read',
                      style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white10, height: 16),

            // ── Notification list ────────────────────────────────────────────
            Expanded(
              child: notifsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Text('Error: $err', style: const TextStyle(color: Colors.redAccent)),
                ),
                data: (notifications) {
                  if (notifications.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_none, size: 48, color: cs.onSurface.withOpacity(0.3)),
                          const SizedBox(height: 12),
                          Text(
                            'No notifications yet.\nComplete missions to receive System alerts.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: cs.onSurface.withOpacity(0.5), fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                    itemBuilder: (_, i) {
                      final n = notifications[i];
                      return _NotificationTile(
                        notification: n,
                        onTap: () => service.markRead(uid, n.id),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final HunterNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  Color get _typeColor {
    switch (notification.type) {
      case NotificationType.streakAtRisk:
        return const Color(0xFFF59E0B);
      case NotificationType.incomingDuel:
        return const Color(0xFFEF4444);
      case NotificationType.crateAvailable:
        return const Color(0xFF22C55E);
      case NotificationType.levelUp:
        return const Color(0xFFFFD700);
      case NotificationType.questComplete:
        return const Color(0xFF10B981);
      case NotificationType.systemAlert:
        return const Color(0xFF38BDF8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('MMM d, h:mm a').format(notification.createdAt);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: notification.isRead
              ? Colors.transparent
              : _typeColor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Emoji badge ─────────────────────────────────────────────────
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _typeColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(notification.typeEmoji, style: const TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 12),

            // ── Content ─────────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            color: _typeColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _typeColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notification.body,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeStr,
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
