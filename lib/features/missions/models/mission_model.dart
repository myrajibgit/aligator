import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _parseNullableDateTime(dynamic val) {
  if (val == null) return null;
  if (val is Timestamp) return val.toDate();
  if (val is String) return DateTime.tryParse(val);
  if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
  return null;
}

class SubjectMission {
  final String subjectId;
  final String subjectName;
  final String status;
  final int xpAwarded;

  const SubjectMission({
    required this.subjectId,
    required this.subjectName,
    required this.status,
    this.xpAwarded = 0,
  });

  factory SubjectMission.fromJson(Map<String, dynamic> json) {
    return SubjectMission(
      subjectId: (json['subjectId'] as String?) ?? '',
      subjectName: (json['subjectName'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'pending',
      xpAwarded: (json['xpAwarded'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'subjectId': subjectId,
      'subjectName': subjectName,
      'status': status,
      'xpAwarded': xpAwarded,
    };
  }

  SubjectMission copyWith({
    String? subjectId,
    String? subjectName,
    String? status,
    int? xpAwarded,
  }) {
    return SubjectMission(
      subjectId: subjectId ?? this.subjectId,
      subjectName: subjectName ?? this.subjectName,
      status: status ?? this.status,
      xpAwarded: xpAwarded ?? this.xpAwarded,
    );
  }
}

class FitnessMission {
  final String status;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final bool fitStepsVerified;
  final int xpAwarded;

  const FitnessMission({
    required this.status,
    this.startedAt,
    this.completedAt,
    this.fitStepsVerified = false,
    this.xpAwarded = 0,
  });

  factory FitnessMission.fromJson(Map<String, dynamic> json) {
    return FitnessMission(
      status: (json['status'] as String?) ?? 'pending',
      startedAt: _parseNullableDateTime(json['startedAt']),
      completedAt: _parseNullableDateTime(json['completedAt']),
      fitStepsVerified: (json['fitStepsVerified'] as bool?) ?? false,
      xpAwarded: (json['xpAwarded'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'fitStepsVerified': fitStepsVerified,
      'xpAwarded': xpAwarded,
    };
  }

  FitnessMission copyWith({
    String? status,
    DateTime? startedAt,
    DateTime? completedAt,
    bool? fitStepsVerified,
    int? xpAwarded,
  }) {
    return FitnessMission(
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      fitStepsVerified: fitStepsVerified ?? this.fitStepsVerified,
      xpAwarded: xpAwarded ?? this.xpAwarded,
    );
  }
}

class StudyMission {
  final String status;
  final String? chapterId;
  final String? subjectId;
  final String? photoRef;
  final double? quizScore;
  final int xpAwarded;

  const StudyMission({
    required this.status,
    this.chapterId,
    this.subjectId,
    this.photoRef,
    this.quizScore,
    this.xpAwarded = 0,
  });

  factory StudyMission.fromJson(Map<String, dynamic> json) {
    return StudyMission(
      status: (json['status'] as String?) ?? 'pending',
      chapterId: json['chapterId'] as String?,
      subjectId: json['subjectId'] as String?,
      photoRef: json['photoRef'] as String?,
      quizScore: (json['quizScore'] as num?)?.toDouble(),
      xpAwarded: (json['xpAwarded'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      if (chapterId != null) 'chapterId': chapterId,
      if (subjectId != null) 'subjectId': subjectId,
      if (photoRef != null) 'photoRef': photoRef,
      if (quizScore != null) 'quizScore': quizScore,
      'xpAwarded': xpAwarded,
    };
  }

  StudyMission copyWith({
    String? status,
    String? chapterId,
    String? subjectId,
    String? photoRef,
    double? quizScore,
    int? xpAwarded,
  }) {
    return StudyMission(
      status: status ?? this.status,
      chapterId: chapterId ?? this.chapterId,
      subjectId: subjectId ?? this.subjectId,
      photoRef: photoRef ?? this.photoRef,
      quizScore: quizScore ?? this.quizScore,
      xpAwarded: xpAwarded ?? this.xpAwarded,
    );
  }
}

class DailyMissions {
  final String uid;
  final String date;
  final List<SubjectMission> subjectMissions;
  final FitnessMission fitnessMission;
  final StudyMission studyMission;

  const DailyMissions({
    required this.uid,
    required this.date,
    required this.subjectMissions,
    required this.fitnessMission,
    required this.studyMission,
  });

  factory DailyMissions.fromJson(Map<String, dynamic> json) {
    final subList = json['subjectMissions'] as List<dynamic>?;
    return DailyMissions(
      uid: (json['uid'] as String?) ?? '',
      date: (json['date'] as String?) ?? '',
      subjectMissions: subList != null
          ? subList.map((e) => SubjectMission.fromJson(e as Map<String, dynamic>)).toList()
          : const [],
      fitnessMission: json['fitnessMission'] != null
          ? FitnessMission.fromJson(json['fitnessMission'] as Map<String, dynamic>)
          : const FitnessMission(status: 'pending'),
      studyMission: json['studyMission'] != null
          ? StudyMission.fromJson(json['studyMission'] as Map<String, dynamic>)
          : const StudyMission(status: 'pending'),
    );
  }

  factory DailyMissions.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return DailyMissions.fromJson(data);
  }

  Map<String, dynamic> toFirestore() {
    return toJson();
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'date': date,
      'subjectMissions': subjectMissions.map((e) => e.toJson()).toList(),
      'fitnessMission': fitnessMission.toJson(),
      'studyMission': studyMission.toJson(),
    };
  }

  DailyMissions copyWith({
    String? uid,
    String? date,
    List<SubjectMission>? subjectMissions,
    FitnessMission? fitnessMission,
    StudyMission? studyMission,
  }) {
    return DailyMissions(
      uid: uid ?? this.uid,
      date: date ?? this.date,
      subjectMissions: subjectMissions ?? this.subjectMissions,
      fitnessMission: fitnessMission ?? this.fitnessMission,
      studyMission: studyMission ?? this.studyMission,
    );
  }
}
