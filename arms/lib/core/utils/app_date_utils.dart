import 'package:intl/intl.dart';

class AppDateUtils {
  /// Formats date to 'yyyy-MM-dd' (e.g. 2024-05-20)
  static String formatToYMD(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  /// Formats date to 'd MMM yyyy' (e.g. 20 May 2024)
  static String formatToDMY(DateTime date) {
    return DateFormat('d MMM yyyy').format(date);
  }

  /// Formats date to 'MMM yyyy' (e.g. May 2024)
  static String formatToMY(DateTime date) {
    return DateFormat('MMM yyyy').format(date);
  }

  /// Parses date from 'd MMM yyyy' string
  static DateTime parseDMY(String dateStr) {
    return DateFormat('d MMM yyyy').parse(dateStr.trim());
  }
}
