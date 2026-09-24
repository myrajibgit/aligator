import 'package:flutter_test/flutter_test.dart';
import 'package:studycompete/features/missions/models/hunter_streak_model.dart';

void main() {
  group('HunterStreakData Model & Progression Mechanics', () {
    test('default streak starts at 0 with 1.0x multiplier', () {
      const streak = HunterStreakData();
      expect(streak.currentStreak, equals(0));
      expect(streak.longestStreak, equals(0));
      expect(streak.xpMultiplier, equals(1.0));
      expect(streak.streakTierName, equals('NOVICE SPARKS'));
      expect(streak.flameEmoji, equals('🔥'));
    });

    test('evaluates tier and multiplier progression properly', () {
      // 3 Days (Awakened Flow)
      const streak3 = HunterStreakData(currentStreak: 3);
      expect(streak3.xpMultiplier, equals(1.1));
      expect(streak3.streakTierName, equals('AWAKENED FLOW'));
      expect(streak3.flameEmoji, equals('🔷🔥'));

      // 7 Days (Guild Vanguard)
      const streak7 = HunterStreakData(currentStreak: 7);
      expect(streak7.xpMultiplier, equals(1.25));
      expect(streak7.streakTierName, equals('GUILD VANGUARD'));
      expect(streak7.flameEmoji, equals('⚡🔥'));

      // 14 Days (Monarch Surge)
      const streak14 = HunterStreakData(currentStreak: 14);
      expect(streak14.xpMultiplier, equals(1.5));
      expect(streak14.streakTierName, equals('MONARCH SURGE'));
      expect(streak14.flameEmoji, equals('🟣🔥'));

      // 30 Days (Eternal Sovereign)
      const streak30 = HunterStreakData(currentStreak: 30);
      expect(streak30.xpMultiplier, equals(2.0));
      expect(streak30.streakTierName, equals('ETERNAL SOVEREIGN'));
      expect(streak30.flameEmoji, equals('👑🔥'));
    });

    test('evaluates daily crate claim eligibility accurately', () {
      const today = '2026-09-18';
      const yesterday = '2026-09-17';

      // Unclaimed
      const unclaimed = HunterStreakData();
      expect(unclaimed.isCrateClaimable(today), isTrue);

      // Claimed yesterday
      const claimedYesterday = HunterStreakData(lastCrateClaimDate: yesterday);
      expect(claimedYesterday.isCrateClaimable(today), isTrue);

      // Claimed today
      const claimedToday = HunterStreakData(lastCrateClaimDate: today);
      expect(claimedToday.isCrateClaimable(today), isFalse);
    });

    test('evaluates streak risk warning before daily study completion', () {
      const today = '2026-09-18';
      const yesterday = '2026-09-17';

      // 0 streak is never at risk
      const zeroStreak = HunterStreakData(currentStreak: 0);
      expect(zeroStreak.isStreakAtRisk(today), isFalse);

      // Active streak, but not studied today -> AT RISK!
      const atRisk = HunterStreakData(
        currentStreak: 5,
        lastActiveDate: yesterday,
      );
      expect(atRisk.isStreakAtRisk(today), isTrue);

      // Already studied today -> SAFE!
      const safe = HunterStreakData(
        currentStreak: 6,
        lastActiveDate: today,
      );
      expect(safe.isStreakAtRisk(today), isFalse);
    });

    test('serializes to and from Map accurately', () {
      final original = HunterStreakData(
        currentStreak: 10,
        longestStreak: 15,
        lastActiveDate: '2026-09-18',
        lastCrateClaimDate: '2026-09-18',
        activeDates: const {'2026-09-17', '2026-09-18'},
      );

      final map = original.toMap();
      final recovered = HunterStreakData.fromMap(map);

      expect(recovered.currentStreak, equals(10));
      expect(recovered.longestStreak, equals(15));
      expect(recovered.lastActiveDate, equals('2026-09-18'));
      expect(recovered.lastCrateClaimDate, equals('2026-09-18'));
      expect(recovered.isDateActive('2026-09-17'), isTrue);
      expect(recovered.isDateActive('2026-09-18'), isTrue);
      expect(recovered.isDateActive('2026-09-16'), isFalse);
    });
  });
}
