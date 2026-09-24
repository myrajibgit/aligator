import 'package:cloud_firestore/cloud_firestore.dart';

class Question {
  final String id;
  final String text;
  final List<String> options;
  final int correctIndex;
  final String difficulty;
  final List<String> tags;
  final String subjectId;
  final String chapterId;

  const Question({
    required this.id,
    required this.text,
    required this.options,
    required this.correctIndex,
    required this.difficulty,
    required this.tags,
    required this.subjectId,
    required this.chapterId,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: (json['id'] as String?) ?? '',
      text: (json['text'] as String?) ?? '',
      options: (json['options'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      correctIndex: (json['correctIndex'] as num?)?.toInt() ?? 0,
      difficulty: (json['difficulty'] as String?) ?? 'easy',
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      subjectId: (json['subjectId'] as String?) ?? '',
      chapterId: (json['chapterId'] as String?) ?? '',
    );
  }

  factory Question.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return Question.fromJson({...data, 'id': doc.id});
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'options': options,
      'correctIndex': correctIndex,
      'difficulty': difficulty,
      'tags': tags,
      'subjectId': subjectId,
      'chapterId': chapterId,
    };
  }

  Map<String, dynamic> toFirestore() {
    return toJson()..remove('id');
  }

  Question copyWith({
    String? id,
    String? text,
    List<String>? options,
    int? correctIndex,
    String? difficulty,
    List<String>? tags,
    String? subjectId,
    String? chapterId,
  }) {
    return Question(
      id: id ?? this.id,
      text: text ?? this.text,
      options: options ?? this.options,
      correctIndex: correctIndex ?? this.correctIndex,
      difficulty: difficulty ?? this.difficulty,
      tags: tags ?? this.tags,
      subjectId: subjectId ?? this.subjectId,
      chapterId: chapterId ?? this.chapterId,
    );
  }
}
