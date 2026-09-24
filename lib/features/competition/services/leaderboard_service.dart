import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:studycompete/features/competition/models/leaderboard_entry_model.dart';
import 'package:studycompete/shared/constants/app_constants.dart';

class ScoutStatusResult {
  final bool isScout;
  final int rank;
  final int totalParticipants;
  final double percentile;

  const ScoutStatusResult({
    required this.isScout,
    required this.rank,
    required this.totalParticipants,
    required this.percentile,
  });
}

class LeaderboardService {
  final FirebaseFirestore _firestore;

  LeaderboardService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ─── Helper: Get Current Week Key (e.g. "2026-W37") ───────────────────────

  String get _currentWeekKey {
    final now = DateTime.now();
    final d = DateTime.utc(now.year, now.month, now.day);
    final dayNum = d.weekday;
    final thursday = d.add(Duration(days: 4 - dayNum));
    final yearStart = DateTime.utc(thursday.year, 1, 1);
    final weekNo = ((thursday.difference(yearStart).inDays + 1) / 7).ceil();
    return '${thursday.year}-W${weekNo.toString().padLeft(2, '0')}';
  }

  // ─── Tier 1: Class Rank ───────────────────────────────────────────────────

  Stream<List<LeaderboardEntry>> watchClassLeaderboard(String classId, {String? currentUid}) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .where('classId', isEqualTo: classId)
        .orderBy('xp', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) {
          int r = 1;
          return snap.docs
              .map((doc) => LeaderboardEntry.fromFirestore(doc, r++, currentUid: currentUid))
              .toList();
        });
  }

  // ─── Tier 2: School Rank ──────────────────────────────────────────────────

  Stream<List<LeaderboardEntry>> watchSchoolLeaderboard(String schoolId, {String? currentUid}) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .where('schoolId', isEqualTo: schoolId)
        .orderBy('xp', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) {
          int r = 1;
          return snap.docs
              .map((doc) => LeaderboardEntry.fromFirestore(doc, r++, currentUid: currentUid))
              .toList();
        });
  }

  // ─── Tier 2: Area / City Rank ─────────────────────────────────────────────

  Stream<List<LeaderboardEntry>> watchAreaLeaderboard(String area, {String? currentUid}) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .where('area', isEqualTo: area)
        .orderBy('xp', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) {
          int r = 1;
          return snap.docs
              .map((doc) => LeaderboardEntry.fromFirestore(doc, r++, currentUid: currentUid))
              .toList();
        });
  }

  // ─── Tier 3: Weekly Leaderboard ───────────────────────────────────────────

  Stream<List<LeaderboardEntry>> watchWeeklyLeaderboard(String classId, {String? currentUid}) {
    return _firestore
        .collection(AppConstants.leaderboardsCollection)
        .doc(classId)
        .collection('weekly')
        .doc(_currentWeekKey)
        .snapshots()
        .map((snap) {
          if (!snap.exists || snap.data() == null) {
            return [];
          }
          final entries = snap.data()!['entries'] as List<dynamic>? ?? [];
          return entries.asMap().entries.map((item) {
            return LeaderboardEntry.fromJson(
              item.value as Map<String, dynamic>,
              item.key + 1,
              currentUid: currentUid,
            );
          }).toList();
        });
  }

  // ─── Cross-School Scout Status Check ──────────────────────────────────────

  /// Evaluates whether the student ranks within the top 10% of their class/school
  /// to unlock cross-school scouting and battle privileges.
  Future<ScoutStatusResult> checkCrossSchoolScoutStatus(String uid, String classId) async {
    try {
      final snap = await _firestore
          .collection(AppConstants.usersCollection)
          .where('classId', isEqualTo: classId)
          .orderBy('xp', descending: true)
          .get();

      if (snap.docs.isEmpty) {
        return const ScoutStatusResult(
          isScout: false,
          rank: 1,
          totalParticipants: 1,
          percentile: 1.0,
        );
      }

      int userIndex = snap.docs.indexWhere((d) => d.id == uid);
      if (userIndex == -1) {
        return ScoutStatusResult(
          isScout: false,
          rank: snap.docs.length,
          totalParticipants: snap.docs.length,
          percentile: 0.0,
        );
      }

      final rank = userIndex + 1;
      final total = snap.docs.length;
      final percentile = (total - rank + 1) / total;

      // Top 10% or rank 1-3 in small cohorts (< 20 students) unlocks Scout
      final isScout = percentile >= 0.90 || rank <= 3;

      return ScoutStatusResult(
        isScout: isScout,
        rank: rank,
        totalParticipants: total,
        percentile: percentile,
      );
    } catch (_) {
      return const ScoutStatusResult(
        isScout: false,
        rank: 0,
        totalParticipants: 0,
        percentile: 0.0,
      );
    }
  }

  // ─── Cross-School Opponents for Scouts ────────────────────────────────────

  /// Fetches top competitors from peer schools in the same municipality/area
  Future<List<LeaderboardEntry>> getCrossSchoolOpponents({
    required String currentSchoolId,
    required String area,
    int limit = 20,
  }) async {
    try {
      final snap = await _firestore
          .collection(AppConstants.usersCollection)
          .where('area', isEqualTo: area)
          .orderBy('xp', descending: true)
          .limit(limit * 2)
          .get();

      final filtered = snap.docs
          .where((d) => d.data()['schoolId'] != currentSchoolId)
          .take(limit)
          .toList();

      int r = 1;
      return filtered
          .map((d) => LeaderboardEntry.fromFirestore(d, r++))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
