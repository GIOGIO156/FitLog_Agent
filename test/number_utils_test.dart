import 'package:fitlog_local/core/utils/number_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toNullableInt maps missing or sentinel values to null', () {
    expect(NumberUtils.toNullableInt(null), isNull);
    expect(NumberUtils.toNullableInt('not-a-number'), isNull);
    expect(NumberUtils.toNullableInt(-1), isNull);
  });

  test('toNullableInt parses valid integer-like values', () {
    expect(NumberUtils.toNullableInt(3), 3);
    expect(NumberUtils.toNullableInt(3.8), 3);
    expect(NumberUtils.toNullableInt('42'), 42);
  });
}
