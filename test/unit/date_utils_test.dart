import 'package:flutter_test/flutter_test.dart';
import 'package:studycompete/shared/utils/date_utils.dart' as sc;

void main() {
  group('DateUtils', () {
    test('todayKey produces yyyy-MM-dd format', () {
      final key = sc.DateUtils.todayKey();
      final regex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
      expect(regex.hasMatch(key), isTrue);
    });

    test('startOfToday is at 00:00:00', () {
      final start = sc.DateUtils.startOfToday();
      expect(start.hour, equals(0));
      expect(start.minute, equals(0));
      expect(start.second, equals(0));
      expect(start.millisecond, equals(0));
    });

    test('endOfToday is after startOfToday', () {
      final start = sc.DateUtils.startOfToday();
      final end = sc.DateUtils.endOfToday();
      expect(end.isAfter(start), isTrue);
      expect(end.hour, equals(23));
      expect(end.minute, equals(59));
      expect(end.second, equals(59));
    });
  });
}
