import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/missions_service.dart';
import '../services/quiz_service.dart';
import '../models/mission_model.dart';
import '../../auth/models/user_model.dart';
import '../models/question_model.dart';
import '../services/hunter_streak_service.dart';
import '../../stats/services/hunter_relic_service.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/utils/hunter_rank.dart';

final missionsServiceProvider = Provider<MissionsService>((ref) {
  return MissionsService();
});

final quizServiceProvider = Provider<QuizService>((ref) {
  return QuizService();
});

final todaysMissionsProvider = StreamProvider.family<DailyMissions?, String>((ref, uid) {
  final service = ref.watch(missionsServiceProvider);
  return service.watchTodaysMissions(uid);
});

class MissionsNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  MissionsNotifier(this.ref) : super(const AsyncValue.data(null));

  Future<void> initMissions(UserModel user) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(missionsServiceProvider);
      await service.initTodaysMissions(user.uid, user);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<List<Question>> startSubjectQuiz(String subjectId) async {
    final service = ref.read(quizServiceProvider);
    return await service.getQuestionsForSubject(subjectId);
  }

  /// Scores a quiz and writes the result with streak-boosted XP.
  Future<double> submitSubjectQuiz({
    required String uid,
    required String subjectId,
    required List<Question> questions,
    required List<int> answers,
    UserModel? userModel,
  }) async {
    final quizSvc = ref.read(quizServiceProvider);
    final missionsSvc = ref.read(missionsServiceProvider);

    final score = quizSvc.scoreQuiz(questions, answers);

    if (score >= AppConstants.quizPassThreshold) {
      double streakMultiplier = 1.0;
      try {
        final streakSvc = ref.read(hunterStreakServiceProvider);
        final streakData = await streakSvc.watchStreak(uid).first;
        streakMultiplier = streakData.xpMultiplier;
      } catch (_) {}

      int baseXp = AppConstants.subjectMissionXP;
      if (userModel != null) {
        final derived = HunterRankUtils.calculateDerivedStats(userModel);
        if (derived.intelligence >= 60) {
          baseXp += AppConstants.intStatBonusXP;
        }
      }

      await missionsSvc.completeSubjectMission(
        uid: uid,
        subjectId: subjectId,
        xpAwarded: baseXp,
        xpMultiplier: streakMultiplier,
      );
    }
    return score;
  }

  Future<Map<String, dynamic>> rewardFocusSession({
    required String uid,
    required int focusMinutes,
    required int distractionBreaches,
  }) async {
    final missionsSvc = ref.read(missionsServiceProvider);

    double streakMultiplier = 1.0;
    try {
      final streakSvc = ref.read(hunterStreakServiceProvider);
      final streakData = await streakSvc.watchStreak(uid).first;
      streakMultiplier = streakData.xpMultiplier;
    } catch (_) {}

    double relicBonus = 0.0;
    try {
      final buffs = ref.read(activeHunterBuffsProvider(uid));
      relicBonus = buffs.xpMultiplierBoost;
    } catch (_) {}

    final totalMultiplier = streakMultiplier + relicBonus;

    return missionsSvc.recordFocusSession(
      uid: uid,
      focusMinutes: focusMinutes,
      distractionBreaches: distractionBreaches,
      xpMultiplier: totalMultiplier,
    );
  }
}

final missionsNotifierProvider =
    StateNotifierProvider<MissionsNotifier, AsyncValue<void>>((ref) {
  return MissionsNotifier(ref);
});
