import 'package:cloud_firestore/cloud_firestore.dart';

class ChapterInfo {
  final String id;
  final String name;

  const ChapterInfo({
    required this.id,
    required this.name,
  });

  factory ChapterInfo.fromJson(Map<String, dynamic> json) {
    return ChapterInfo(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }

  ChapterInfo copyWith({
    String? id,
    String? name,
  }) {
    return ChapterInfo(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }
}

class SubjectModel {
  final String id;
  final String name;
  final String classId;
  final String iconUrl;
  final List<ChapterInfo> chapters;

  const SubjectModel({
    required this.id,
    required this.name,
    required this.classId,
    this.iconUrl = '',
    required this.chapters,
  });

  factory SubjectModel.fromJson(Map<String, dynamic> json) {
    final chList = json['chapters'] as List<dynamic>?;
    return SubjectModel(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      classId: (json['classId'] as String?) ?? '',
      iconUrl: (json['iconUrl'] as String?) ?? '',
      chapters: chList != null
          ? chList.map((e) => ChapterInfo.fromJson(e as Map<String, dynamic>)).toList()
          : const [],
    );
  }

  factory SubjectModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return SubjectModel.fromJson({...data, 'id': doc.id});
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'classId': classId,
      'iconUrl': iconUrl,
      'chapters': chapters.map((c) => c.toJson()).toList(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return toJson()..remove('id');
  }

  SubjectModel copyWith({
    String? id,
    String? name,
    String? classId,
    String? iconUrl,
    List<ChapterInfo>? chapters,
  }) {
    return SubjectModel(
      id: id ?? this.id,
      name: name ?? this.name,
      classId: classId ?? this.classId,
      iconUrl: iconUrl ?? this.iconUrl,
      chapters: chapters ?? this.chapters,
    );
  }
}
