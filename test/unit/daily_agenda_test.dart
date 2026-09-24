import 'package:flutter_test/flutter_test.dart';

enum TestAgendaType { subject, focus, fitness, verify, trial, rest }

class TestAgendaItem {
  final int startHour;
  final int endHour;
  final String label;
  final TestAgendaType type;

  const TestAgendaItem({
    required this.startHour,
    required this.endHour,
    required this.label,
    required this.type,
  });
}

List<TestAgendaItem> buildTestAgendaBlocks({
  required List<String> subjects,
  required double intelligence,
}) {
  final blocks = <TestAgendaItem>[];
  final isHighInt = intelligence >= 55;

  if (isHighInt) {
    blocks.add(const TestAgendaItem(
      startHour: 6,
      endHour: 7,
      label: 'Morning Conditioning',
      type: TestAgendaType.fitness,
    ));
  }

  blocks.add(const TestAgendaItem(
    startHour: 8,
    endHour: 9,
    label: 'Focus Protocol I',
    type: TestAgendaType.focus,
  ));

  for (int i = 0; i < subjects.length && i < 3; i++) {
    blocks.add(TestAgendaItem(
      startHour: 9 + i,
      endHour: 10 + i,
      label: subjects[i],
      type: TestAgendaType.subject,
    ));
  }

  if (!isHighInt) {
    blocks.add(const TestAgendaItem(
      startHour: 12,
      endHour: 13,
      label: 'Midday Conditioning',
      type: TestAgendaType.fitness,
    ));
  }

  blocks.add(const TestAgendaItem(
    startHour: 14,
    endHour: 15,
    label: 'Focus Protocol II',
    type: TestAgendaType.focus,
  ));

  for (int i = 3; i < subjects.length && i < 6; i++) {
    blocks.add(TestAgendaItem(
      startHour: 15 + (i - 3),
      endHour: 16 + (i - 3),
      label: subjects[i],
      type: TestAgendaType.subject,
    ));
  }

  blocks.add(const TestAgendaItem(
    startHour: 19,
    endHour: 20,
    label: 'Notes Verification',
    type: TestAgendaType.verify,
  ));

  blocks.add(const TestAgendaItem(
    startHour: 21,
    endHour: 22,
    label: 'Infinite Trial',
    type: TestAgendaType.trial,
  ));

  return blocks;
}

String getConditionString(double fatigue) {
  if (fatigue >= 40) return 'FATIGUED ⚠️';
  if (fatigue >= 20) return 'NORMAL';
  return 'PEAK CONDITION ⚡';
}

void main() {
  group('Daily Agenda Planning Engine', () {
    test('adapts morning schedule for high INT hunters', () {
      final blocks = buildTestAgendaBlocks(
        subjects: ['Math', 'Physics', 'Chemistry'],
        intelligence: 75.0,
      );

      // High INT hunter starts with early morning conditioning at 6am
      expect(blocks.first.startHour, equals(6));
      expect(blocks.first.type, equals(TestAgendaType.fitness));

      // Contains study sessions
      final subjectBlocks = blocks.where((b) => b.type == TestAgendaType.subject).toList();
      expect(subjectBlocks.length, equals(3));
      expect(subjectBlocks[0].label, equals('Math'));
      expect(subjectBlocks[1].label, equals('Physics'));
      expect(subjectBlocks[2].label, equals('Chemistry'));
    });

    test('places midday conditioning for standard INT hunters', () {
      final blocks = buildTestAgendaBlocks(
        subjects: ['History', 'Literature'],
        intelligence: 40.0,
      );

      // First block is Focus Protocol I at 8am (not 6am)
      expect(blocks.first.startHour, equals(8));
      expect(blocks.first.type, equals(TestAgendaType.focus));

      // Midday fitness is at 12pm
      final fitnessBlock = blocks.firstWhere((b) => b.type == TestAgendaType.fitness);
      expect(fitnessBlock.startHour, equals(12));
    });

    test('always schedules end-of-day verification and infinite trial gauntlet', () {
      final blocks = buildTestAgendaBlocks(
        subjects: ['Math', 'Biology'],
        intelligence: 60.0,
      );

      final lastTwo = blocks.sublist(blocks.length - 2);
      expect(lastTwo[0].type, equals(TestAgendaType.verify));
      expect(lastTwo[0].startHour, equals(19));
      expect(lastTwo[1].type, equals(TestAgendaType.trial));
      expect(lastTwo[1].startHour, equals(21));
    });

    test('evaluates fatigue condition tags accurately', () {
      expect(getConditionString(10), equals('PEAK CONDITION ⚡'));
      expect(getConditionString(19.9), equals('PEAK CONDITION ⚡'));
      expect(getConditionString(20), equals('NORMAL'));
      expect(getConditionString(39.9), equals('NORMAL'));
      expect(getConditionString(40), equals('FATIGUED ⚠️'));
      expect(getConditionString(85), equals('FATIGUED ⚠️'));
    });
  });
}
