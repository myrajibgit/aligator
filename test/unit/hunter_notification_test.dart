import 'package:flutter_test/flutter_test.dart';
import 'package:studycompete/shared/services/notifications_service.dart';

void main() {
  group('HunterNotification Model & Parsing', () {
    test('default notification properties and emoji resolution', () {
      final now = DateTime(2026, 9, 18, 12, 0);
      final notif = HunterNotification(
        id: 'notif_123',
        type: NotificationType.streakAtRisk,
        title: '[SYSTEM ALERT] STREAK AT RISK',
        body: 'Complete a quest before midnight!',
        createdAt: now,
      );

      expect(notif.id, equals('notif_123'));
      expect(notif.type, equals(NotificationType.streakAtRisk));
      expect(notif.typeEmoji, equals('🔥'));
      expect(notif.isRead, isFalse);
    });

    test('all NotificationType enum values map to signature emojis', () {
      final now = DateTime.now();

      final duel = HunterNotification(
        id: '1',
        type: NotificationType.incomingDuel,
        title: 'Duel',
        body: '',
        createdAt: now,
      );
      expect(duel.typeEmoji, equals('⚔️'));

      final crate = HunterNotification(
        id: '2',
        type: NotificationType.crateAvailable,
        title: 'Crate',
        body: '',
        createdAt: now,
      );
      expect(crate.typeEmoji, equals('📦'));

      final levelUp = HunterNotification(
        id: '3',
        type: NotificationType.levelUp,
        title: 'Level Up',
        body: '',
        createdAt: now,
      );
      expect(levelUp.typeEmoji, equals('⬆️'));

      final quest = HunterNotification(
        id: '4',
        type: NotificationType.questComplete,
        title: 'Quest',
        body: '',
        createdAt: now,
      );
      expect(quest.typeEmoji, equals('✅'));

      final alert = HunterNotification(
        id: '5',
        type: NotificationType.systemAlert,
        title: 'Alert',
        body: '',
        createdAt: now,
      );
      expect(alert.typeEmoji, equals('🤖'));
    });

    test('fromMap parses map fields and falls back gracefully', () {
      final parsed = HunterNotification.fromMap('n_custom', {
        'type': 'incomingDuel',
        'title': 'Challenged by Sung',
        'body': 'Prepare for 3-round battle!',
        'isRead': true,
      });

      expect(parsed.id, equals('n_custom'));
      expect(parsed.type, equals(NotificationType.incomingDuel));
      expect(parsed.title, equals('Challenged by Sung'));
      expect(parsed.body, equals('Prepare for 3-round battle!'));
      expect(parsed.isRead, isTrue);

      // Unknown type gracefully falls back to systemAlert
      final fallback = HunterNotification.fromMap('n_fallback', {
        'type': 'unknownTypeFromFutureUpdate',
      });
      expect(fallback.type, equals(NotificationType.systemAlert));
      expect(fallback.title, equals('[SYSTEM]'));
      expect(fallback.isRead, isFalse);
    });

    test('copyWith updates isRead without mutating other fields', () {
      final now = DateTime(2026, 9, 18, 10, 0);
      final original = HunterNotification(
        id: 'n_toggle',
        type: NotificationType.crateAvailable,
        title: 'Crate Ready',
        body: 'Claim now',
        createdAt: now,
        isRead: false,
      );

      final updated = original.copyWith(isRead: true);

      expect(updated.id, equals('n_toggle'));
      expect(updated.type, equals(NotificationType.crateAvailable));
      expect(updated.title, equals('Crate Ready'));
      expect(updated.createdAt, equals(now));
      expect(updated.isRead, isTrue);
    });
  });
}
