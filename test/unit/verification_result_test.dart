import 'package:flutter_test/flutter_test.dart';
import 'package:studycompete/features/missions/models/gemini_verification_result.dart';

void main() {
  group('GeminiVerificationResult Model', () {
    test('instantiates successfully from raw map and evaluates hasMatch', () {
      final map = {
        'success': true,
        'syllabusAvailable': true,
        'matchedChapterId': 'Electricity',
        'matchedChapterName': 'Electricity and Circuits',
        'extractedText': 'Ohm law states that current is proportional to voltage',
        'coverage': {
          'completedPercent': 80,
          'topicsCovered': ['Current', 'Voltage', 'Resistance'],
          'topicsRemaining': ['Power', 'Joule Heating'],
        },
      };

      final result = GeminiVerificationResult.fromMap(map);

      expect(result.success, isTrue);
      expect(result.syllabusAvailable, isTrue);
      expect(result.matchedChapterId, equals('Electricity'));
      expect(result.matchedChapterName, equals('Electricity and Circuits'));
      expect(result.hasMatch, isTrue);
      expect(result.coverage?.completedPercent, equals(80));
      expect(result.coverage?.topicsCovered.length, equals(3));
      expect(result.coverage?.topicsRemaining.length, equals(2));
    });

    test('handles failed or partial result gracefully', () {
      final map = {
        'success': false,
        'syllabusAvailable': false,
        'error': 'Textbook chapter not recognized',
      };

      final result = GeminiVerificationResult.fromMap(map);

      expect(result.success, isFalse);
      expect(result.hasMatch, isFalse);
      expect(result.syllabusAvailable, isFalse);
      expect(result.error, equals('Textbook chapter not recognized'));
      expect(result.coverage, isNull);
    });
  });
}
