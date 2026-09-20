import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/features/home/streak.dart';

void main() {
  // Wednesday 23 September 2026 (local time).
  final now = DateTime(2026, 9, 23, 12);

  DateTime day(int month, int dayOfMonth) =>
      DateTime(2026, month, dayOfMonth, 9);

  group('weekStart', () {
    test('is the Monday of the week', () {
      expect(weekStart(DateTime(2026, 9, 23)), DateTime(2026, 9, 21));
      expect(weekStart(DateTime(2026, 9, 21, 23, 59)), DateTime(2026, 9, 21));
      expect(weekStart(DateTime(2026, 9, 27)), DateTime(2026, 9, 21));
    });

    test('crosses month and year boundaries', () {
      expect(weekStart(DateTime(2026, 10, 1)), DateTime(2026, 9, 28));
      expect(weekStart(DateTime(2026, 1, 1)), DateTime(2025, 12, 29));
    });
  });

  group('computeStreak', () {
    test('no workouts means no streak', () {
      final streak = computeStreak(const [], now);

      expect(streak.weeks, 0);
      expect(streak.thisWeek, 0);
    });

    test('counts workouts this week', () {
      final streak = computeStreak([day(9, 21), day(9, 22)], now);

      expect(streak.weeks, 1);
      expect(streak.thisWeek, 2);
    });

    test('counts consecutive weeks', () {
      final streak = computeStreak([
        day(9, 22),
        day(9, 15),
        day(9, 8),
        day(9, 1),
      ], now);

      expect(streak.weeks, 4);
      expect(streak.thisWeek, 1);
    });

    test('a missed week breaks the streak', () {
      final streak = computeStreak([day(9, 22), day(9, 8)], now);

      expect(streak.weeks, 1);
    });

    test('a quiet start to the week does not break the streak yet', () {
      final streak = computeStreak([day(9, 16), day(9, 9)], now);

      expect(streak.weeks, 2);
      expect(streak.thisWeek, 0);
    });

    test('two quiet weeks do break it', () {
      final streak = computeStreak([day(9, 9)], now);

      expect(streak.weeks, 0);
    });

    test('several workouts in a week count once for the streak', () {
      final streak = computeStreak([
        day(9, 15),
        day(9, 16),
        day(9, 17),
        day(9, 8),
      ], now);

      expect(streak.weeks, 2);
    });

    test('works across a year boundary', () {
      final january = DateTime(2026, 1, 7, 12); // a Wednesday
      final streak = computeStreak([
        DateTime(2026, 1, 5, 9),
        DateTime(2025, 12, 30, 9),
      ], january);

      expect(streak.weeks, 2);
    });
  });
}
