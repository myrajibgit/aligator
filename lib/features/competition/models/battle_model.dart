import 'package:cloud_firestore/cloud_firestore.dart';

/// Single round of a 3-round RPG Stat Duel.
class BattleRound {
  final int roundNumber;
  final String statCategory; // e.g. "math_10", "iq", "knowledgePower"
  final String label;        // e.g. "Mathematics Duel", "IQ & Accuracy", "Knowledge Power"
  final int scoreA;
  final int scoreB;
  final String? winnerUid;

  const BattleRound({
    required this.roundNumber,
    required this.statCategory,
    required this.label,
    required this.scoreA,
    required this.scoreB,
    this.winnerUid,
  });

  factory BattleRound.fromJson(Map<String, dynamic> json) {
    return BattleRound(
      roundNumber: (json['roundNumber'] as num?)?.toInt() ?? 1,
      statCategory: json['statCategory'] as String? ?? '',
      label: json['label'] as String? ?? '',
      scoreA: (json['scoreA'] as num?)?.toInt() ?? 0,
      scoreB: (json['scoreB'] as num?)?.toInt() ?? 0,
      winnerUid: json['winnerUid'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'roundNumber': roundNumber,
    'statCategory': statCategory,
    'label': label,
    'scoreA': scoreA,
    'scoreB': scoreB,
    'winnerUid': winnerUid,
  };
}

/// Head-to-head 3-round asynchronous stat duel between two students.
class BattleModel {
  final String id;
  final String challengerUid;
  final String challengerName;
  final String? challengerPhotoUrl;
  final String challengedUid;
  final String challengedName;
  final String? challengedPhotoUrl;
  final String schoolId;
  final String classId;
  final String status; // "pending" | "accepted" | "completed" | "declined"
  final List<BattleRound> rounds;
  final String? winnerUid;
  final DateTime? createdAt;
  final DateTime? completedAt;

  const BattleModel({
    required this.id,
    required this.challengerUid,
    required this.challengerName,
    this.challengerPhotoUrl,
    required this.challengedUid,
    required this.challengedName,
    this.challengedPhotoUrl,
    required this.schoolId,
    required this.classId,
    required this.status,
    required this.rounds,
    this.winnerUid,
    this.createdAt,
    this.completedAt,
  });

  factory BattleModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      return null;
    }

    final rawRounds = json['rounds'] as List<dynamic>? ?? [];
    final roundsList = rawRounds
        .map((r) => BattleRound.fromJson(r as Map<String, dynamic>))
        .toList();

    return BattleModel(
      id: json['id'] as String? ?? '',
      challengerUid: json['challengerUid'] as String? ?? '',
      challengerName: json['challengerName'] as String? ?? 'Challenger',
      challengerPhotoUrl: json['challengerPhotoUrl'] as String?,
      challengedUid: json['challengedUid'] as String? ?? '',
      challengedName: json['challengedName'] as String? ?? 'Opponent',
      challengedPhotoUrl: json['challengedPhotoUrl'] as String?,
      schoolId: json['schoolId'] as String? ?? '',
      classId: json['classId'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      rounds: roundsList,
      winnerUid: json['winnerUid'] as String?,
      createdAt: parseDate(json['createdAt']),
      completedAt: parseDate(json['completedAt']),
    );
  }

  factory BattleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return BattleModel.fromJson({'id': doc.id, ...data});
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'challengerUid': challengerUid,
    'challengerName': challengerName,
    'challengerPhotoUrl': challengerPhotoUrl,
    'challengedUid': challengedUid,
    'challengedName': challengedName,
    'challengedPhotoUrl': challengedPhotoUrl,
    'schoolId': schoolId,
    'classId': classId,
    'status': status,
    'rounds': rounds.map((r) => r.toJson()).toList(),
    'winnerUid': winnerUid,
    'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
  };
}
