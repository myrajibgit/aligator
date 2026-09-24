import 'package:flutter_test/flutter_test.dart';
import 'package:studycompete/features/auth/models/user_model.dart';
import 'package:studycompete/features/auth/models/user_stats.dart';
import 'package:studycompete/shared/utils/hunter_rank.dart';

void main() {
  group('HunterRankUtils.getRankInfo', () {
    test('returns S-RANK Shadow Monarch for Level 50+', () {
      final rank = HunterRankUtils.getRankInfo(50);
      expect(rank.name, equals('S-RANK'));
      expect(rank.title, equals('SHADOW MONARCH'));
      expect(rank.tier, equals(HunterRankTier.s));
    });

    test('returns A-RANK National Level for Levels 40-49', () {
      final rank = HunterRankUtils.getRankInfo(42);
      expect(rank.name, equals('A-RANK'));
      expect(rank.title, equals('NATIONAL LEVEL'));
      expect(rank.tier, equals(HunterRankTier.a));
    });

    test('returns B-RANK Guild Master for Levels 30-39', () {
      final rank = HunterRankUtils.getRankInfo(35);
      expect(rank.name, equals('B-RANK'));
      expect(rank.title, equals('GUILD MASTER'));
      expect(rank.tier, equals(HunterRankTier.b));
    });

    test('returns C-RANK Raid Leader for Levels 20-29', () {
      final rank = HunterRankUtils.getRankInfo(25);
      expect(rank.name, equals('C-RANK'));
      expect(rank.title, equals('RAID LEADER'));
      expect(rank.tier, equals(HunterRankTier.c));
    });

    test('returns D-RANK Wolf Slayer for Levels 10-19', () {
      final rank = HunterRankUtils.getRankInfo(12);
      expect(rank.name, equals('D-RANK'));
      expect(rank.title, equals('WOLF SLAYER'));
      expect(rank.tier, equals(HunterRankTier.d));
    });

    test('returns E-RANK Novice Hunter for Levels 1-9', () {
      final rank = HunterRankUtils.getRankInfo(3);
      expect(rank.name, equals('E-RANK'));
      expect(rank.title, equals('NOVICE HUNTER'));
      expect(rank.tier, equals(HunterRankTier.e));
    });
  });

  group('HunterRankUtils.calculateDerivedStats', () {
    test('computes and clamps 5-axis RPG stats properly', () {
      final user = UserModel(
        uid: 'user_123',
        displayName: 'Sung Jin',
        username: 'sung_jin',
        bio: 'Solo hunter',
        schoolId: 'sch_1',
        classId: 'cls_1',
        streamId: 'str_1',
        area: 'Seoul',
        subjectIds: ['math', 'physics'],
        xp: 1200, // Level 7
        stats: const UserStats(
          knowledgePower: 40,
          iq: 85,
          battleIQ: 25,
          streak: 5,
        ),
        createdAt: DateTime.now(),
        lastActive: DateTime.now(),
      );

      final derived = HunterRankUtils.calculateDerivedStats(user);

      expect(derived.intelligence, inInclusiveRange(10.0, 100.0));
      expect(derived.sense, inInclusiveRange(10.0, 100.0));
      expect(derived.strength, inInclusiveRange(10.0, 100.0));
      expect(derived.vitality, equals(derived.strength * 0.8));
      expect(derived.agility, inInclusiveRange(10.0, 100.0));
      expect(derived.fatigue, inInclusiveRange(0, 100));

      final radarPoints = derived.toRadarPoints();
      expect(radarPoints.length, equals(5));
      expect(radarPoints.map((p) => p.label).toList(), equals(['INT', 'SEN', 'VIT', 'STR', 'AGI']));
    });

    test('peak condition streak sets fatigue to 0', () {
      final user = UserModel(
        uid: 'user_777',
        displayName: 'Monarch',
        username: 'monarch',
        bio: 'Peak stamina',
        schoolId: 'sch_1',
        classId: 'cls_1',
        streamId: 'str_1',
        area: 'Seoul',
        subjectIds: ['math'],
        xp: 10000,
        stats: const UserStats(streak: 10),
        createdAt: DateTime.now(),
        lastActive: DateTime.now(),
      );

      final derived = HunterRankUtils.calculateDerivedStats(user);
      expect(derived.fatigue, equals(0));
    });
  });
}
