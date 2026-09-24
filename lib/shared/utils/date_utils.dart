import 'package:intl/intl.dart';

class DateUtils {
  static String todayKey() {
    final now = DateTime.now();
    return DateFormat('yyyy-MM-dd').format(now);
  }

  static DateTime startOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime endOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  }
}
