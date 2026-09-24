import 'package:cloud_firestore/cloud_firestore.dart';

/// Single entry in a ranked leaderboard (Class, School, Area, or Weekly Elite).
class LeaderboardEntry {
  final String uid;
  final String displayName;
  final String username;
  final String? photoUrl;
  final int xp;
  final int knowledgePower;
  final int iq;
  final int battleIq;
  final int rank;
  final String? schoolId;
  final String? classId;
  final String? area;
  final bool isCurrentUser;

  const LeaderboardEntry({
    required this.uid,
    required this.displayName,
    required this.username,
    this.photoUrl,
    required this.xp,
    required this.knowledgePower,
    required this.iq,
    required this.battleIq,
    required this.rank,
    this.schoolId,
    this.classId,
    this.area,
    this.isCurrentUser = false,
  });

  factory LeaderboardEntry.fromFirestore(DocumentSnapshot doc, int rank, {String? currentUid}) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final stats = data['stats'] as Map<String, dynamic>? ?? {};

    return LeaderboardEntry(
      uid: doc.id,
      displayName: data['displayName'] as String? ?? 'Student',
      username: data['username'] as String? ?? 'user',
      photoUrl: data['photoUrl'] as String?,
      xp: (data['xp'] as num?)?.toInt() ?? 0,
      knowledgePower: (data['knowledgePower'] as num?)?.toInt() ?? (stats['knowledgePower'] as num?)?.toInt() ?? 0,
      iq: (data['iq'] as num?)?.toInt() ?? (stats['iq'] as num?)?.toInt() ?? 100,
      battleIq: (stats['battleIQ'] as num?)?.toInt() ?? (stats['battleIq'] as num?)?.toInt() ?? 0,
      rank: rank,
      schoolId: data['schoolId'] as String?,
      classId: data['classId'] as String?,
      area: data['area'] as String?,
      isCurrentUser: doc.id == currentUid,
    );
  }

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json, int rank, {String? currentUid}) {
    final stats = json['stats'] as Map<String, dynamic>? ?? {};
    final uid = json['uid'] as String? ?? '';

    return LeaderboardEntry(
      uid: uid,
      displayName: json['displayName'] as String? ?? 'Student',
      username: json['username'] as String? ?? 'user',
      photoUrl: json['photoUrl'] as String?,
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      knowledgePower: (json['knowledgePower'] as num?)?.toInt() ?? (stats['knowledgePower'] as num?)?.toInt() ?? 0,
      iq: (json['iq'] as num?)?.toInt() ?? (stats['iq'] as num?)?.toInt() ?? 100,
      battleIq: (stats['battleIQ'] as num?)?.toInt() ?? (stats['battleIq'] as num?)?.toInt() ?? 0,
      rank: rank,
      schoolId: json['schoolId'] as String?,
      classId: json['classId'] as String?,
      area: json['area'] as String?,
      isCurrentUser: uid == currentUid,
    );
  }
}
