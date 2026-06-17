import 'package:intl/intl.dart';

class DateUtilsX {
  DateUtilsX._();

  static final DateFormat _dayFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _exportFormat = DateFormat('yyyy_MM_dd');

  static String todayKey() => formatDate(DateTime.now());

  static String formatDate(DateTime date) => _dayFormat.format(date);

  static String formatForExport(DateTime date) => _exportFormat.format(date);

  static DateTime parseDay(String day) => _dayFormat.parse(day);

  static String formatReadable(String day) {
    final DateTime date = parseDay(day);
    return DateFormat('MMM d, yyyy').format(date);
  }
}
