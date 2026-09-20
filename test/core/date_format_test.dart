import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/core/date_format.dart';

void main() {
  test('formatDate shows weekday, day, month and year', () {
    expect(formatDate(DateTime(2026, 9, 20)), 'Sun 20 Sep 2026');
    expect(formatDate(DateTime(2026, 1, 5)), 'Mon 5 Jan 2026');
  });

  test('formatTime pads hours and minutes', () {
    expect(formatTime(DateTime(2026, 9, 20, 7, 5)), '07:05');
    expect(formatTime(DateTime(2026, 9, 20, 18, 30)), '18:30');
  });

  test('uses local time for UTC values', () {
    final utc = DateTime.utc(2026, 9, 20, 12);

    expect(formatTime(utc), formatTime(utc.toLocal()));
  });
}
