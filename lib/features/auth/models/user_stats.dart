class UserStats {
  final int knowledgePower;
  final int iq;
  final int battleIQ;
  final int streak;
  final int dailyXpGoal;
  final Map<String, int> subjectStats;
  final int totalFocusMinutes;

  const UserStats({
    this.knowledgePower = 0,
    this.iq = 0,
    this.battleIQ = 0,
    this.streak = 0,
    this.dailyXpGoal = 180,
    this.subjectStats = const {},
    this.totalFocusMinutes = 0,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      knowledgePower: (json['knowledgePower'] as num?)?.toInt() ?? 0,
      iq: (json['iq'] as num?)?.toInt() ?? 0,
      battleIQ: (json['battleIQ'] as num?)?.toInt() ?? 0,
      streak: (json['streak'] as num?)?.toInt() ?? 0,
      dailyXpGoal: (json['dailyXpGoal'] as num?)?.toInt() ?? 180,
      subjectStats: (json['subjectStats'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toInt()),
          ) ??
          const {},
      totalFocusMinutes: (json['totalFocusMinutes'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'knowledgePower': knowledgePower,
      'iq': iq,
      'battleIQ': battleIQ,
      'streak': streak,
      'dailyXpGoal': dailyXpGoal,
      'subjectStats': subjectStats,
      'totalFocusMinutes': totalFocusMinutes,
    };
  }

  UserStats copyWith({
    int? knowledgePower,
    int? iq,
    int? battleIQ,
    int? streak,
    int? dailyXpGoal,
    Map<String, int>? subjectStats,
    int? totalFocusMinutes,
  }) {
    return UserStats(
      knowledgePower: knowledgePower ?? this.knowledgePower,
      iq: iq ?? this.iq,
      battleIQ: battleIQ ?? this.battleIQ,
      streak: streak ?? this.streak,
      dailyXpGoal: dailyXpGoal ?? this.dailyXpGoal,
      subjectStats: subjectStats ?? this.subjectStats,
      totalFocusMinutes: totalFocusMinutes ?? this.totalFocusMinutes,
    );
  }
}
