import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/mission_model.dart';
import '../../auth/models/user_model.dart';
import '../../../shared/constants/app_constants.dart';

class MissionsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get _todayKey => DateFormat('yyyy-MM-dd').format(DateTime.now());

  Future<DailyMissions?> getTodaysMissions(String uid) async {
    final doc = await _firestore
        .collection('missions')
        .doc(uid)
        .collection('daily')
        .doc(_todayKey)
        .get();
        
    if (doc.exists && doc.data() != null) {
      return DailyMissions.fromJson(doc.data()!);
    }
    return null;
  }

  Future<DailyMissions> initTodaysMissions(String uid, UserModel user) async {
    final docRef = _firestore.collection('missions').doc(uid).collection('daily').doc(_todayKey);
    final doc = await docRef.get();

    if (!doc.exists) {
      final subjectMissions = user.subjectIds
          .map((id) => SubjectMission(
                subjectId: id,
                subjectName: id,
                status: 'pending',
              ))
          .toList();

      final newMissions = DailyMissions(
        uid: uid,
        date: _todayKey,
        subjectMissions: subjectMissions,
        fitnessMission: const FitnessMission(status: 'pending'),
        studyMission: const StudyMission(status: 'pending'),
      );

      await docRef.set(newMissions.toJson());
      return newMissions;
    } else {
      return DailyMissions.fromJson(doc.data()!);
    }
  }

  Stream<DailyMissions?> watchTodaysMissions(String uid) {
    return _firestore
        .collection('missions')
        .doc(uid)
        .collection('daily')
        .doc(_todayKey)
        .snapshots()
        .map((doc) => doc.exists && doc.data() != null ? DailyMissions.fromJson(doc.data()!) : null);
  }

  Future<void> completeSubjectMission({
    required String uid,
    required String subjectId,
    required int xpAwarded,
    double xpMultiplier = 1.0,
  }) async {
    // Apply streak multiplier to the XP awarded.
    // This is the core mechanic: hunters with high streaks earn boosted XP.
    final boostedXp = (xpAwarded * xpMultiplier).round();
    final docRef = _firestore.collection('missions').doc(uid).collection('daily').doc(_todayKey);

    await _firestore.runTransaction((transaction) async {
      final dailyDoc = await transaction.get(docRef);
      if (!dailyDoc.exists || dailyDoc.data() == null) return;

      final missions = DailyMissions.fromJson(dailyDoc.data()!);
      final updatedSubjectMissions = missions.subjectMissions.map((m) {
        if (m.subjectId == subjectId) {
          return m.copyWith(status: 'completed', xpAwarded: boostedXp);
        }
        return m;
      }).toList();

      transaction.update(docRef, {
        'subjectMissions': updatedSubjectMissions.map((e) => e.toJson()).toList(),
      });
    });

    // Also increment the global XP counter on the user profile.
    try {
      await _firestore.collection('users').doc(uid).update({
        'xp': FieldValue.increment(boostedXp),
      });
    } catch (_) {}
  }

  Future<void> completeFitnessMission({
    required String uid,
    required bool fitStepsVerified,
  }) async {
    const xp = AppConstants.fitnessMissionXP;
    final docRef = _firestore.collection('missions').doc(uid).collection('daily').doc(_todayKey);

    await _firestore.runTransaction((transaction) async {
      transaction.update(docRef, {
        'fitnessMission.status': 'completed',
        'fitnessMission.completedAt': FieldValue.serverTimestamp(),
        'fitnessMission.fitStepsVerified': fitStepsVerified,
        'fitnessMission.xpAwarded': xp,
      });
    });
  }

  Future<void> completeStudyMission({
    required String uid,
    required String subjectId,
    required String chapterId,
    required double quizScore,
    String? photoStorageRef,
  }) async {
    const xp = AppConstants.studyMissionXP;
    final docRef = _firestore.collection('missions').doc(uid).collection('daily').doc(_todayKey);

    await _firestore.runTransaction((transaction) async {
      transaction.update(docRef, {
        'studyMission.status': 'completed',
        'studyMission.subjectId': subjectId,
        'studyMission.chapterId': chapterId,
        'studyMission.quizScore': quizScore,
        'studyMission.photoRef': photoStorageRef,
        'studyMission.xpAwarded': xp,
      });
    });
  }

  Future<void> updateStats(String uid) async {
    final dailyQuery = await _firestore
        .collection('missions')
        .doc(uid)
        .collection('daily')
        .orderBy(FieldPath.documentId, descending: true)
        .limit(60) // look back up to 60 days for streak
        .get();

    int totalKnowledgePower = 0;
    double totalIqProxy = 0;
    int evaluatedMissionsCount = 0;
    Map<String, int> subjectStats = {};

    // ── Compute streak ──────────────────────────────────────────────────────
    int streak = 0;
    // Build a set of dates that were "fully complete"
    final completedDates = <String>{};
    for (var doc in dailyQuery.docs) {
      final data = doc.data();
      final missions = DailyMissions.fromJson(data);
      final allSubjectsDone = missions.subjectMissions.every((m) => m.status == 'completed');
      final fitnessDone = missions.fitnessMission.status == 'completed';
      final studyDone = missions.studyMission.status == 'completed';
      if (allSubjectsDone && fitnessDone && studyDone) {
        completedDates.add(doc.id); // doc.id is 'yyyy-MM-dd'
      }
    }

    // Walk back from today
    var checkDate = DateTime.now();
    for (int i = 0; i < 60; i++) {
      final key = DateFormat('yyyy-MM-dd').format(checkDate);
      if (completedDates.contains(key)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    // ── Compute XP aggregates ───────────────────────────────────────────────
    for (var doc in dailyQuery.docs) {
      final data = doc.data();
      final missions = DailyMissions.fromJson(data);

      for (var sm in missions.subjectMissions) {
        if (sm.status == 'completed') {
          totalKnowledgePower += sm.xpAwarded;
          subjectStats[sm.subjectId] = (subjectStats[sm.subjectId] ?? 0) + sm.xpAwarded;
          totalIqProxy += (sm.xpAwarded / 50.0);
          evaluatedMissionsCount++;
        }
      }

      if (missions.studyMission.status == 'completed') {
        totalKnowledgePower += missions.studyMission.xpAwarded;
        if (missions.studyMission.subjectId != null) {
          final sId = missions.studyMission.subjectId!;
          subjectStats[sId] = (subjectStats[sId] ?? 0) + missions.studyMission.xpAwarded;
        }
        totalIqProxy += (missions.studyMission.xpAwarded / 50.0);
        evaluatedMissionsCount++;
      }
    }

    int iq = 0;
    if (evaluatedMissionsCount > 0) {
      iq = ((totalIqProxy / evaluatedMissionsCount) * 100).round();
    }

    // ── Write to nested 'stats' map (matches UserModel / UserStats) ─────────
    await _firestore.collection('users').doc(uid).update({
      'stats.knowledgePower': totalKnowledgePower,
      'stats.iq': iq,
      'stats.subjectStats': subjectStats,
      'stats.streak': streak,
    });
  }

  /// Records a completed Deep Focus Protocol session.
  ///
  /// WHY THIS EXISTS: The Focus Session screen previously showed a completion
  /// banner with "+50 XP" but the button did nothing — it just called `context.pop()`.
  /// This method wires the reward to Firestore so focus work is genuinely tracked.
  ///
  /// [focusMinutes] — duration the hunter selected (15, 25, or 50 min).
  /// [distractionBreaches] — how many times they left the app during the session.
  ///   More breaches = reduced XP reward.
  Future<Map<String, dynamic>> recordFocusSession({
    required String uid,
    required int focusMinutes,
    required int distractionBreaches,
    double xpMultiplier = 1.0,
  }) async {
    // Distraction penalty: each breach cuts XP by 20%, floored at 0.
    final penaltyFactor = (1.0 - (distractionBreaches * 0.2)).clamp(0.0, 1.0);
    final baseXP = AppConstants.focusSessionXP;
    final awarded = (baseXP * penaltyFactor * xpMultiplier).round();

    // Write XP and total focus minutes to user profile atomically.
    if (awarded > 0) {
      await _firestore.collection('users').doc(uid).update({
        'xp': FieldValue.increment(awarded),
        'stats.totalFocusMinutes': FieldValue.increment(focusMinutes),
      });
    } else {
      // Even 0 XP sessions still count towards focus time tracked.
      await _firestore.collection('users').doc(uid).update({
        'stats.totalFocusMinutes': FieldValue.increment(focusMinutes),
      });
    }

    return {
      'xpAwarded': awarded,
      'focusMinutes': focusMinutes,
      'distractionBreaches': distractionBreaches,
      'penaltyFactor': penaltyFactor,
    };
  }
}
