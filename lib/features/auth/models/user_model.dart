import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_stats.dart';

DateTime _parseDateTime(dynamic val) {
  if (val == null) return DateTime.now();
  if (val is Timestamp) return val.toDate();
  if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
  if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
  return DateTime.now();
}

class UserModel {
  final String uid;
  final String displayName;
  final String username;
  final String? photoUrl;
  final String bio;
  final String schoolId;
  final String classId;
  final String streamId;
  final String area;
  final List<String> subjectIds;
  final int xp;
  final UserStats stats;
  final List<String> blockedUids;
  final DateTime createdAt;
  final DateTime lastActive;
  final bool onboardingComplete;

  const UserModel({
    required this.uid,
    required this.displayName,
    required this.username,
    this.photoUrl,
    required this.bio,
    required this.schoolId,
    required this.classId,
    required this.streamId,
    required this.area,
    required this.subjectIds,
    this.xp = 0,
    required this.stats,
    this.blockedUids = const [],
    required this.createdAt,
    required this.lastActive,
    this.onboardingComplete = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: (json['uid'] as String?) ?? '',
      displayName: (json['displayName'] as String?) ?? '',
      username: (json['username'] as String?) ?? '',
      photoUrl: json['photoUrl'] as String?,
      bio: (json['bio'] as String?) ?? '',
      schoolId: (json['schoolId'] as String?) ?? '',
      classId: (json['classId'] as String?) ?? '',
      streamId: (json['streamId'] as String?) ?? '',
      area: (json['area'] as String?) ?? '',
      subjectIds: (json['subjectIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      stats: json['stats'] != null && json['stats'] is Map<String, dynamic>
          ? UserStats.fromJson(json['stats'] as Map<String, dynamic>)
          : const UserStats(),
      blockedUids: (json['blockedUids'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      createdAt: _parseDateTime(json['createdAt']),
      lastActive: _parseDateTime(json['lastActive']),
      onboardingComplete: (json['onboardingComplete'] as bool?) ?? false,
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return UserModel.fromJson({...data, 'uid': doc.id});
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'displayName': displayName,
      'username': username,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'bio': bio,
      'schoolId': schoolId,
      'classId': classId,
      'streamId': streamId,
      'area': area,
      'subjectIds': subjectIds,
      'xp': xp,
      'stats': stats.toJson(),
      'blockedUids': blockedUids,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActive': Timestamp.fromDate(lastActive),
      'onboardingComplete': onboardingComplete,
    };
  }

  Map<String, dynamic> toFirestore() {
    return toJson()..remove('uid');
  }

  UserModel copyWith({
    String? uid,
    String? displayName,
    String? username,
    String? photoUrl,
    String? bio,
    String? schoolId,
    String? classId,
    String? streamId,
    String? area,
    List<String>? subjectIds,
    int? xp,
    UserStats? stats,
    List<String>? blockedUids,
    DateTime? createdAt,
    DateTime? lastActive,
    bool? onboardingComplete,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      schoolId: schoolId ?? this.schoolId,
      classId: classId ?? this.classId,
      streamId: streamId ?? this.streamId,
      area: area ?? this.area,
      subjectIds: subjectIds ?? this.subjectIds,
      xp: xp ?? this.xp,
      stats: stats ?? this.stats,
      blockedUids: blockedUids ?? this.blockedUids,
      createdAt: createdAt ?? this.createdAt,
      lastActive: lastActive ?? this.lastActive,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    );
  }

  String? get avatarUrl => photoUrl;
  int get knowledgePower => stats.knowledgePower;
  int get iq => stats.iq;
  int get battleIQ => stats.battleIQ;
  Map<String, int> get subjectStats => stats.subjectStats;
}
