import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import '../models/question_model.dart';

class QuizService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Question>> getQuestionsForSubject(String subjectId, {int count = 5}) async {
    final snapshot = await _firestore
        .collection('questionBank')
        .doc(subjectId)
        .collection('questions')
        .get();

    if (snapshot.docs.isEmpty) return [];

    final allQuestions = snapshot.docs
        .map((doc) => Question.fromJson({'id': doc.id, ...doc.data()}))
        .toList();

    allQuestions.shuffle(Random());
    return allQuestions.take(count).toList();
  }

  double scoreQuiz(List<Question> questions, List<int> userAnswers) {
    if (questions.isEmpty || questions.length != userAnswers.length) return 0.0;
    
    int correct = 0;
    for (int i = 0; i < questions.length; i++) {
      if (questions[i].correctIndex == userAnswers[i]) {
        correct++;
      }
    }
    
    return correct / questions.length;
  }
}
