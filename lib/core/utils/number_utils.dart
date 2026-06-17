class NumberUtils {
  NumberUtils._();

  static double toDouble(dynamic value, {double fallback = 0}) {
    if (value == null) {
      return fallback;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString()) ?? fallback;
  }

  static int toInt(dynamic value, {int fallback = 0}) {
    if (value == null) {
      return fallback;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString()) ?? fallback;
  }

  static int? toNullableInt(dynamic value) {
    final parsed = toInt(value, fallback: -1);
    return parsed == -1 ? null : parsed;
  }
}
