import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/features/workout/set_input.dart';
import 'package:formcoach/features/workout/workout_formatting.dart';

void main() {
  group('formatClock', () {
    test('formats minutes and padded seconds', () {
      expect(formatClock(0), '0:00');
      expect(formatClock(65), '1:05');
      expect(formatClock(600), '10:00');
    });

    test('never shows a negative time', () {
      expect(formatClock(-5), '0:00');
    });
  });

  group('formatDuration', () {
    test('uses seconds under a minute', () {
      expect(formatDuration(const Duration(seconds: 42)), '42 s');
    });

    test('uses minutes under an hour', () {
      expect(formatDuration(const Duration(minutes: 45)), '45 min');
    });

    test('uses hours and minutes', () {
      expect(formatDuration(const Duration(hours: 1, minutes: 5)), '1 h 5 min');
      expect(formatDuration(const Duration(hours: 2)), '2 h');
    });
  });

  group('formatVolume', () {
    test('adds thousands separators and rounds', () {
      expect(formatVolume(0), '0 kg');
      expect(formatVolume(960), '960 kg');
      expect(formatVolume(1440.4), '1,440 kg');
      expect(formatVolume(1234567), '1,234,567 kg');
    });
  });

  group('MaxValueFormatter', () {
    const formatter = MaxValueFormatter(100);
    const old = TextEditingValue(text: '50');

    TextEditingValue apply(String text) =>
        formatter.formatEditUpdate(old, TextEditingValue(text: text));

    test('accepts values up to the maximum', () {
      expect(apply('100').text, '100');
      expect(apply('7').text, '7');
    });

    test('rejects values above the maximum', () {
      expect(apply('101').text, '50');
    });

    test('accepts an empty field', () {
      expect(apply('').text, '');
    });

    test('reads a comma as a decimal point', () {
      expect(apply('99,5').text, '99,5');
      expect(apply('100,5').text, '50');
    });
  });

  group('parsing', () {
    test('parseWholeNumber', () {
      expect(parseWholeNumber('12'), 12);
      expect(parseWholeNumber(' 8 '), 8);
      expect(parseWholeNumber(''), isNull);
      expect(parseWholeNumber('abc'), isNull);
    });

    test('parseWeight accepts dot and comma', () {
      expect(parseWeight('62.5'), 62.5);
      expect(parseWeight('62,5'), 62.5);
      expect(parseWeight(''), isNull);
    });

    test('formatWeight drops a trailing .0', () {
      expect(formatWeight(null), '');
      expect(formatWeight(60), '60');
      expect(formatWeight(62.5), '62.5');
    });
  });
}
