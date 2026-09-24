import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studycompete/features/auth/providers/auth_provider.dart';
import 'package:studycompete/features/competition/models/battle_model.dart';
import 'package:studycompete/features/competition/models/leaderboard_entry_model.dart';
import 'package:studycompete/features/competition/services/battle_service.dart';
import 'package:studycompete/features/competition/services/leaderboard_service.dart';

// ─── Service Singletons ───────────────────────────────────────────────────────

final battleServiceProvider = Provider<BattleService>((ref) {
  return BattleService();
});

final leaderboardServiceProvider = Provider<LeaderboardService>((ref) {
  return LeaderboardService();
});

// ─── Battles Stream Providers ─────────────────────────────────────────────────

final userBattlesStreamProvider = StreamProvider.autoDispose.family<List<BattleModel>, String>((ref, uid) {
  final service = ref.watch(battleServiceProvider);
  return service.watchUserBattles(uid);
});

final pendingChallengesStreamProvider = StreamProvider.autoDispose.family<List<BattleModel>, String>((ref, uid) {
  final service = ref.watch(battleServiceProvider);
  return service.watchPendingChallenges(uid);
});

// ─── Leaderboard Stream Providers ─────────────────────────────────────────────

final classLeaderboardProvider = StreamProvider.autoDispose<List<LeaderboardEntry>>((ref) {
  final userProfile = ref.watch(currentUserProfileProvider).value;
  final currentUid = ref.watch(currentUserProvider)?.uid ?? '';
  if (userProfile == null || userProfile.classId.isEmpty) {
    return Stream.value([]);
  }
  final service = ref.watch(leaderboardServiceProvider);
  return service.watchClassLeaderboard(userProfile.classId, currentUid: currentUid);
});

final schoolLeaderboardProvider = StreamProvider.autoDispose<List<LeaderboardEntry>>((ref) {
  final userProfile = ref.watch(currentUserProfileProvider).value;
  final currentUid = ref.watch(currentUserProvider)?.uid ?? '';
  if (userProfile == null || userProfile.schoolId.isEmpty) {
    return Stream.value([]);
  }
  final service = ref.watch(leaderboardServiceProvider);
  return service.watchSchoolLeaderboard(userProfile.schoolId, currentUid: currentUid);
});

final areaLeaderboardProvider = StreamProvider.autoDispose<List<LeaderboardEntry>>((ref) {
  final userProfile = ref.watch(currentUserProfileProvider).value;
  final currentUid = ref.watch(currentUserProvider)?.uid ?? '';
  if (userProfile == null || userProfile.area.isEmpty) {
    return Stream.value([]);
  }
  final service = ref.watch(leaderboardServiceProvider);
  return service.watchAreaLeaderboard(userProfile.area, currentUid: currentUid);
});

final weeklyLeaderboardProvider = StreamProvider.autoDispose<List<LeaderboardEntry>>((ref) {
  final userProfile = ref.watch(currentUserProfileProvider).value;
  final currentUid = ref.watch(currentUserProvider)?.uid ?? '';
  if (userProfile == null || userProfile.classId.isEmpty) {
    return Stream.value([]);
  }
  final service = ref.watch(leaderboardServiceProvider);
  return service.watchWeeklyLeaderboard(userProfile.classId, currentUid: currentUid);
});

// ─── Cross-School Scout Status ────────────────────────────────────────────────

final scoutStatusProvider = FutureProvider.autoDispose<ScoutStatusResult>((ref) async {
  final userProfile = ref.watch(currentUserProfileProvider).value;
  final currentUid = ref.watch(currentUserProvider)?.uid ?? '';
  if (userProfile == null || userProfile.classId.isEmpty) {
    return const ScoutStatusResult(
      isScout: false,
      rank: 0,
      totalParticipants: 0,
      percentile: 0.0,
    );
  }
  final service = ref.watch(leaderboardServiceProvider);
  return service.checkCrossSchoolScoutStatus(currentUid, userProfile.classId);
});

final crossSchoolOpponentsProvider = FutureProvider.autoDispose<List<LeaderboardEntry>>((ref) async {
  final userProfile = ref.watch(currentUserProfileProvider).value;
  if (userProfile == null) return [];
  final service = ref.watch(leaderboardServiceProvider);
  return service.getCrossSchoolOpponents(
    currentSchoolId: userProfile.schoolId,
    area: userProfile.area,
  );
});
