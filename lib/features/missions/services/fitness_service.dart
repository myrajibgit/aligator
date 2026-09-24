import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import 'package:intl/intl.dart';
import 'package:studycompete/features/missions/models/mission_model.dart';
import 'package:studycompete/shared/constants/app_constants.dart';

final fitnessServiceProvider = Provider<FitnessService>((ref) => FitnessService());

/// Handles the 30-minute fitness mission: timer logic + Health API verification.
class FitnessService {
  final FirebaseFirestore _firestore;
  final Health _health;

  FitnessService({FirebaseFirestore? firestore, Health? health})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _health = health ?? Health();

  String get _todayKey => DateFormat('yyyy-MM-dd').format(DateTime.now());

  static const List<HealthDataType> _healthTypes = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  // ─── Permission request ───────────────────────────────────────────────────

  Future<bool> requestHealthPermissions() async {
    try {
      return await _health.requestAuthorization(_healthTypes);
    } catch (_) {
      return false;
    }
  }

  // ─── Start workout session ────────────────────────────────────────────────

  /// Records workoutStartTime and marks mission as 'in_progress'.
  Future<void> startFitnessTimer(String uid) async {
    final docRef = _firestore
        .collection(AppConstants.missionsCollection)
        .doc(uid)
        .collection('daily')
        .doc(_todayKey);

    await docRef.update({
      'fitnessMission.status': 'in_progress',
      'fitnessMission.startedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Verify workout using Health API ─────────────────────────────────────

  /// Queries Health API for [workoutStartTime, workoutEndTime].
  /// Minimum: 300 steps OR ≥15 active minutes (900 kcal proxy).
  Future<FitnessVerificationResult> verifyFitnessActivity({
    required DateTime workoutStart,
    required DateTime workoutEnd,
  }) async {
    try {
      final hasPermission = await requestHealthPermissions();
      if (!hasPermission) {
        return FitnessVerificationResult(
          verified: false,
          steps: 0,
          activeMinutes: 0,
          reason: 'Health permissions not granted.',
        );
      }

      final healthData = await _health.getHealthDataFromTypes(
        types: _healthTypes,
        startTime: workoutStart,
        endTime: workoutEnd,
      );

      int totalSteps = 0;
      double totalCalories = 0;

      for (final point in healthData) {
        if (point.type == HealthDataType.STEPS) {
          totalSteps += (point.value as NumericHealthValue).numericValue.toInt();
        } else if (point.type == HealthDataType.ACTIVE_ENERGY_BURNED) {
          totalCalories +=
              (point.value as NumericHealthValue).numericValue.toDouble();
        }
      }

      // ~4 kcal per active minute → 15 min = 60 kcal
      final activeMinutes = (totalCalories / 4.0).round();
      final verified = totalSteps >= 300 || activeMinutes >= 15;

      return FitnessVerificationResult(
        verified: verified,
        steps: totalSteps,
        activeMinutes: activeMinutes,
        reason: verified
            ? 'Activity verified! $totalSteps steps, ~$activeMinutes active min.'
            : 'Not enough activity. Got $totalSteps steps / $activeMinutes active min. '
                'Need 300 steps or 15 active minutes.',
      );
    } catch (e) {
      return FitnessVerificationResult(
        verified: false,
        steps: 0,
        activeMinutes: 0,
        reason: 'Error reading health data: $e',
      );
    }
  }

  // ─── Complete fitness mission ─────────────────────────────────────────────

  Future<void> completeFitnessMission({
    required String uid,
    required bool fitStepsVerified,
  }) async {
    const xp = AppConstants.fitnessMissionXP;
    final docRef = _firestore
        .collection(AppConstants.missionsCollection)
        .doc(uid)
        .collection('daily')
        .doc(_todayKey);

    await _firestore.runTransaction((tx) async {
      tx.update(docRef, {
        'fitnessMission.status': 'completed',
        'fitnessMission.completedAt': FieldValue.serverTimestamp(),
        'fitnessMission.fitStepsVerified': fitStepsVerified,
        'fitnessMission.xpAwarded': xp,
      });
    });
  }

  // ─── Complete study mission ───────────────────────────────────────────────

  Future<void> completeStudyMission({
    required String uid,
    required String subjectId,
    required String chapterId,
    required double quizScore,
    String? photoStorageRef,
  }) async {
    const xp = AppConstants.studyMissionXP;
    final docRef = _firestore
        .collection(AppConstants.missionsCollection)
        .doc(uid)
        .collection('daily')
        .doc(_todayKey);

    await _firestore.runTransaction((tx) async {
      tx.update(docRef, {
        'studyMission.status': 'completed',
        'studyMission.subjectId': subjectId,
        'studyMission.chapterId': chapterId,
        'studyMission.quizScore': quizScore,
        'studyMission.photoRef': photoStorageRef,
        'studyMission.xpAwarded': xp,
      });
    });
  }

  // ─── Anti-cheat: upload study photo & return storage path ────────────────

  Future<String> uploadStudyPhoto({
    required String uid,
    required List<int> imageBytes,
    required String subjectId,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ref = FirebaseStorage.instance
        .ref('study_photos/$uid/${subjectId}_$timestamp.jpg');
    await ref.putData(
      Uint8List.fromList(imageBytes),
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return ref.fullPath;
  }
}

/// Result from the Health API verification step.
class FitnessVerificationResult {
  final bool verified;
  final int steps;
  final int activeMinutes;
  final String reason;

  const FitnessVerificationResult({
    required this.verified,
    required this.steps,
    required this.activeMinutes,
    required this.reason,
  });
}
