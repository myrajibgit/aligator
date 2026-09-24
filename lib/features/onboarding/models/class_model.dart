import 'package:cloud_firestore/cloud_firestore.dart';

class ClassModel {
  final String id;
  final String schoolId;
  final String grade;
  final String stream;
  final List<String> subjectIds;

  const ClassModel({
    required this.id,
    required this.schoolId,
    required this.grade,
    required this.stream,
    required this.subjectIds,
  });

  factory ClassModel.fromJson(Map<String, dynamic> json) {
    return ClassModel(
      id: (json['id'] as String?) ?? '',
      schoolId: (json['schoolId'] as String?) ?? '',
      grade: (json['grade'] as String?) ?? '',
      stream: (json['stream'] as String?) ?? '',
      subjectIds: (json['subjectIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  factory ClassModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return ClassModel.fromJson({...data, 'id': doc.id});
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'schoolId': schoolId,
      'grade': grade,
      'stream': stream,
      'subjectIds': subjectIds,
    };
  }

  Map<String, dynamic> toFirestore() {
    return toJson()..remove('id');
  }

  ClassModel copyWith({
    String? id,
    String? schoolId,
    String? grade,
    String? stream,
    List<String>? subjectIds,
  }) {
    return ClassModel(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      grade: grade ?? this.grade,
      stream: stream ?? this.stream,
      subjectIds: subjectIds ?? this.subjectIds,
    );
  }
}
