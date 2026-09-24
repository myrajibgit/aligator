import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _parseNullableDateTime(dynamic val) {
  if (val == null) return null;
  if (val is Timestamp) return val.toDate();
  if (val is String) return DateTime.tryParse(val);
  if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
  return null;
}

class PartyModel {
  final String id;
  final String name;
  final String schoolId;
  final String classId;
  final String leaderUid;
  final List<String> memberUids;
  final String inviteCode;
  final String chatId;
  final DateTime? createdAt;

  const PartyModel({
    required this.id,
    required this.name,
    required this.schoolId,
    required this.classId,
    required this.leaderUid,
    required this.memberUids,
    required this.inviteCode,
    required this.chatId,
    this.createdAt,
  });

  factory PartyModel.fromJson(Map<String, dynamic> json) {
    return PartyModel(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      schoolId: (json['schoolId'] as String?) ?? '',
      classId: (json['classId'] as String?) ?? '',
      leaderUid: (json['leaderUid'] as String?) ?? '',
      memberUids: (json['memberUids'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      inviteCode: (json['inviteCode'] as String?) ?? '',
      chatId: (json['chatId'] as String?) ?? '',
      createdAt: _parseNullableDateTime(json['createdAt']),
    );
  }

  factory PartyModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return PartyModel.fromJson({...data, 'id': doc.id});
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'schoolId': schoolId,
      'classId': classId,
      'leaderUid': leaderUid,
      'memberUids': memberUids,
      'inviteCode': inviteCode,
      'chatId': chatId,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
    };
  }

  Map<String, dynamic> toFirestore() {
    return toJson()..remove('id');
  }

  PartyModel copyWith({
    String? id,
    String? name,
    String? schoolId,
    String? classId,
    String? leaderUid,
    List<String>? memberUids,
    String? inviteCode,
    String? chatId,
    DateTime? createdAt,
  }) {
    return PartyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      schoolId: schoolId ?? this.schoolId,
      classId: classId ?? this.classId,
      leaderUid: leaderUid ?? this.leaderUid,
      memberUids: memberUids ?? this.memberUids,
      inviteCode: inviteCode ?? this.inviteCode,
      chatId: chatId ?? this.chatId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class ModerationReport {
  final String reporterUid;
  final String chatId;
  final String messageId;
  final String messageText;
  final String senderUid;
  final String category;
  final DateTime? createdAt;

  const ModerationReport({
    required this.reporterUid,
    required this.chatId,
    required this.messageId,
    required this.messageText,
    required this.senderUid,
    required this.category,
    this.createdAt,
  });

  factory ModerationReport.fromJson(Map<String, dynamic> json) {
    return ModerationReport(
      reporterUid: (json['reporterUid'] as String?) ?? '',
      chatId: (json['chatId'] as String?) ?? '',
      messageId: (json['messageId'] as String?) ?? '',
      messageText: (json['messageText'] as String?) ?? '',
      senderUid: (json['senderUid'] as String?) ?? '',
      category: (json['category'] as String?) ?? 'Other',
      createdAt: _parseNullableDateTime(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reporterUid': reporterUid,
      'chatId': chatId,
      'messageId': messageId,
      'messageText': messageText,
      'senderUid': senderUid,
      'category': category,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
    };
  }
}
