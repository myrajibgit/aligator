import 'package:flutter/material.dart';

/// Represents the student's Solo-Leveling Awakening streak and daily guild crate status.
class HunterStreakData {
  final int currentStreak;
  final int longestStreak;
  final String? lastActiveDate; // yyyy-MM-dd
  final String? lastCrateClaimDate; // yyyy-MM-dd
  final Set<String> activeDates;

  const HunterStreakData({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastActiveDate,
    this.lastCrateClaimDate,
    this.activeDates = const {},
  });

  /// The active multiplier applied to XP earned from daily missions & quizzes.
  double get xpMultiplier {
    if (currentStreak >= 30) return 2.0;
    if (currentStreak >= 14) return 1.5;
    if (currentStreak >= 7) return 1.25;
    if (currentStreak >= 3) return 1.1;
    return 1.0;
  }

  /// Title of the student's streak awakening level.
  String get streakTierName {
    if (currentStreak >= 30) return 'ETERNAL SOVEREIGN';
    if (currentStreak >= 14) return 'MONARCH SURGE';
    if (currentStreak >= 7) return 'GUILD VANGUARD';
    if (currentStreak >= 3) return 'AWAKENED FLOW';
    return 'NOVICE SPARKS';
  }

  /// Representative flame emoji for the streak aura.
  String get flameEmoji {
    if (currentStreak >= 30) return '👑🔥';
    if (currentStreak >= 14) return '🟣🔥';
    if (currentStreak >= 7) return '⚡🔥';
    if (currentStreak >= 3) return '🔷🔥';
    return '🔥';
  }

  /// Theme color associated with the streak tier.
  Color get auraColor {
    if (currentStreak >= 30) return const Color(0xFFFFD700); // Sovereign Gold
    if (currentStreak >= 14) return const Color(0xFFEF4444); // Monarch Crimson
    if (currentStreak >= 7) return const Color(0xFFA855F7); // Vanguard Violet
    if (currentStreak >= 3) return const Color(0xFF38BDF8); // Awakened Cyan
    return const Color(0xFFF97316); // Ember Orange
  }

  /// Checks if the daily guild supply crate is ready to be claimed today.
  bool isCrateClaimable(String todayKey) {
    return lastCrateClaimDate != todayKey;
  }

  /// True if a streak is established but no mission has yet been completed today.
  bool isStreakAtRisk(String todayKey) {
    return currentStreak > 0 && lastActiveDate != todayKey;
  }

  /// Returns whether a specific date had completed study activity.
  bool isDateActive(String dateKey) {
    return activeDates.contains(dateKey);
  }

  factory HunterStreakData.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const HunterStreakData();
    return HunterStreakData(
      currentStreak: (map['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (map['longestStreak'] as num?)?.toInt() ?? 0,
      lastActiveDate: map['lastActiveDate'] as String?,
      lastCrateClaimDate: map['lastCrateClaimDate'] as String?,
      activeDates: Set<String>.from(map['activeDates'] as List? ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'lastActiveDate': lastActiveDate,
      'lastCrateClaimDate': lastCrateClaimDate,
      'activeDates': activeDates.toList(),
    };
  }

  HunterStreakData copyWith({
    int? currentStreak,
    int? longestStreak,
    String? lastActiveDate,
    String? lastCrateClaimDate,
    Set<String>? activeDates,
  }) {
    return HunterStreakData(
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      lastCrateClaimDate: lastCrateClaimDate ?? this.lastCrateClaimDate,
      activeDates: activeDates ?? this.activeDates,
    );
  }
}
