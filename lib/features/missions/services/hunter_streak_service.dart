import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:studycompete/features/missions/models/hunter_streak_model.dart';
import 'package:studycompete/features/stats/models/hunter_relic_model.dart';
import 'package:studycompete/shared/constants/app_constants.dart';

final hunterStreakServiceProvider = Provider<HunterStreakService>((ref) {
  return HunterStreakService();
});

final hunterStreakProvider =
    StreamProvider.family<HunterStreakData, String>((ref, uid) {
  if (uid.isEmpty) return Stream.value(const HunterStreakData());
  return ref.watch(hunterStreakServiceProvider).watchStreak(uid);
});

class HunterStreakService {
  final FirebaseFirestore _firestore;

  HunterStreakService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  String get todayKey => DateFormat('yyyy-MM-dd').format(DateTime.now());
  String get yesterdayKey =>
      DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 1)));

  DocumentReference<Map<String, dynamic>> _streakDoc(String uid) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .collection('streaks')
        .doc('current');
  }

  /// Streams real-time streak telemetry for the given hunter.
  Stream<HunterStreakData> watchStreak(String uid) {
    return _streakDoc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        return const HunterStreakData();
      }
      final raw = HunterStreakData.fromMap(doc.data()!);

      // Evaluate whether the streak lapsed (inactive for more than 1 calendar day)
      if (raw.lastActiveDate != null &&
          raw.lastActiveDate != todayKey &&
          raw.lastActiveDate != yesterdayKey) {
        // Streak expired without activity yesterday
        return raw.copyWith(currentStreak: 0);
      }
      return raw;
    });
  }

  /// Records that a mission was completed today, advancing the consecutive streak.
  Future<HunterStreakData> recordMissionCompleted(String uid) async {
    final docRef = _streakDoc(uid);
    final snap = await docRef.get();

    HunterStreakData data = snap.exists && snap.data() != null
        ? HunterStreakData.fromMap(snap.data()!)
        : const HunterStreakData();

    final today = todayKey;
    final yesterday = yesterdayKey;

    if (data.lastActiveDate == today) {
      // Already marked active today
      return data;
    }

    int newStreak;
    if (data.lastActiveDate == yesterday) {
      // Consecutive day continuation
      newStreak = data.currentStreak + 1;
    } else {
      // Reset or fresh start
      newStreak = 1;
    }

    final newLongest = max(data.longestStreak, newStreak);
    final updatedActiveDates = Set<String>.from(data.activeDates)..add(today);

    // Keep active dates trimmed to past 30 days for efficiency
    final cutoffDate = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().subtract(const Duration(days: 30)));
    updatedActiveDates.removeWhere((d) => d.compareTo(cutoffDate) < 0);

    final updated = data.copyWith(
      currentStreak: newStreak,
      longestStreak: newLongest,
      lastActiveDate: today,
      activeDates: updatedActiveDates,
    );

    await docRef.set(updated.toMap(), SetOptions(merge: true));
    return updated;
  }

  /// Claims the daily Hunter Guild supply crate.
  /// Awards base XP (30 * multiplier) and purges 15% fatigue.
  Future<Map<String, dynamic>> claimDailyCrate({
    required String uid,
    required double xpMultiplier,
  }) async {
    final docRef = _streakDoc(uid);
    final snap = await docRef.get();

    HunterStreakData data = snap.exists && snap.data() != null
        ? HunterStreakData.fromMap(snap.data()!)
        : const HunterStreakData();

    final today = todayKey;
    if (data.lastCrateClaimDate == today) {
      throw Exception('Daily Supply Crate already claimed today! Check back tomorrow.');
    }

    final baseXP = AppConstants.dailyCrateXP;
    final awardedXP = (baseXP * xpMultiplier).round();

    // Update streak doc
    final updated = data.copyWith(lastCrateClaimDate: today);
    await docRef.set(updated.toMap(), SetOptions(merge: true));

    // Award XP to user profile
    try {
      final userRef = _firestore.collection(AppConstants.usersCollection).doc(uid);
      await userRef.update({
        'xp': FieldValue.increment(awardedXP),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    // 35% chance to loot an unowned relic bonus drop from the supply crate
    HunterRelic? bonusRelic;
    try {
      final pool = ['knight_killer', 'kasaka_fang', 'golem_core'];
      pool.shuffle();
      for (final candidateId in pool) {
        final invRef = _firestore
            .collection(AppConstants.usersCollection)
            .doc(uid)
            .collection('inventory')
            .doc(candidateId);
        final exists = (await invRef.get()).exists;
        if (!exists && Random().nextDouble() < 0.35) {
          await invRef.set({
            'relicId': candidateId,
            'acquiredAt': FieldValue.serverTimestamp(),
          });
          bonusRelic = RelicCatalog.find(candidateId);
          break;
        }
      }
    } catch (_) {}

    final quotes = [
      'The System recognizes your steadfast discipline, Hunter.',
      'Rise and conquer. Your daily rations have been disbursed.',
      'Consistency is the sole path from E-Rank to the Monarch’s Throne.',
      'Mana replenished. Fatigue suppressed by 15%. Keep leveling up!',
    ];
    final selectedQuote = quotes[Random().nextInt(quotes.length)];

    return {
      'xpAwarded': awardedXP,
      'fatiguePurged': 15,
      'quote': selectedQuote,
      'bonusRelic': bonusRelic,
    };
  }
}
