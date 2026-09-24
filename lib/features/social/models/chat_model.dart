import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _parseNullableDateTime(dynamic val) {
  if (val == null) return null;
  if (val is Timestamp) return val.toDate();
  if (val is String) return DateTime.tryParse(val);
  if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
  return null;
}

class LastMessage {
  final String text;
  final String senderUid;
  final DateTime? timestamp;

  const LastMessage({
    required this.text,
    required this.senderUid,
    this.timestamp,
  });

  factory LastMessage.fromJson(Map<String, dynamic> json) {
    return LastMessage(
      text: (json['text'] as String?) ?? '',
      senderUid: (json['senderUid'] as String?) ?? '',
      timestamp: _parseNullableDateTime(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'senderUid': senderUid,
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : null,
    };
  }

  LastMessage copyWith({
    String? text,
    String? senderUid,
    DateTime? timestamp,
  }) {
    return LastMessage(
      text: text ?? this.text,
      senderUid: senderUid ?? this.senderUid,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

class ChatModel {
  final String id;
  final String type; // "dm" | "party"
  final List<String> memberUids;
  final LastMessage? lastMessage;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? partyId;
  final String? partyName;

  const ChatModel({
    required this.id,
    required this.type,
    required this.memberUids,
    this.lastMessage,
    this.createdAt,
    this.updatedAt,
    this.partyId,
    this.partyName,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    return ChatModel(
      id: (json['id'] as String?) ?? '',
      type: (json['type'] as String?) ?? 'dm',
      memberUids: (json['memberUids'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      lastMessage: json['lastMessage'] != null && json['lastMessage'] is Map<String, dynamic>
          ? LastMessage.fromJson(json['lastMessage'] as Map<String, dynamic>)
          : null,
      createdAt: _parseNullableDateTime(json['createdAt']),
      updatedAt: _parseNullableDateTime(json['updatedAt']),
      partyId: json['partyId'] as String?,
      partyName: json['partyName'] as String?,
    );
  }

  factory ChatModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return ChatModel.fromJson({...data, 'id': doc.id});
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'memberUids': memberUids,
      'lastMessage': lastMessage?.toJson(),
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      if (partyId != null) 'partyId': partyId,
      if (partyName != null) 'partyName': partyName,
    };
  }

  ChatModel copyWith({
    String? id,
    String? type,
    List<String>? memberUids,
    LastMessage? lastMessage,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? partyId,
    String? partyName,
  }) {
    return ChatModel(
      id: id ?? this.id,
      type: type ?? this.type,
      memberUids: memberUids ?? this.memberUids,
      lastMessage: lastMessage ?? this.lastMessage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      partyId: partyId ?? this.partyId,
      partyName: partyName ?? this.partyName,
    );
  }
}

class ChatMessage {
  final String id;
  final String senderUid;
  final String text;
  final DateTime? timestamp;
  final String status;
  final bool reported;

  const ChatMessage({
    required this.id,
    required this.senderUid,
    required this.text,
    this.timestamp,
    this.status = 'sent',
    this.reported = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: (json['id'] as String?) ?? '',
      senderUid: (json['senderUid'] as String?) ?? '',
      text: (json['text'] as String?) ?? '',
      timestamp: _parseNullableDateTime(json['timestamp']),
      status: (json['status'] as String?) ?? 'sent',
      reported: (json['reported'] as bool?) ?? false,
    );
  }

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return ChatMessage.fromJson({...data, 'id': doc.id});
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderUid': senderUid,
      'text': text,
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : null,
      'status': status,
      'reported': reported,
    };
  }

  ChatMessage copyWith({
    String? id,
    String? senderUid,
    String? text,
    DateTime? timestamp,
    String? status,
    bool? reported,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderUid: senderUid ?? this.senderUid,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      reported: reported ?? this.reported,
    );
  }
}
