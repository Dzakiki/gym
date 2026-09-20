import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/data/local/app_database.dart';
import 'package:formcoach/features/history/set_formatting.dart';

SetLog _set({int? reps, double? weightKg, int? seconds}) {
  final now = DateTime.utc(2026);
  return SetLog(
    id: 's',
    sessionId: 'w',
    exerciseId: 'e',
    exerciseOrder: 0,
    setIndex: 0,
    reps: reps,
    weightKg: weightKg,
    durationSeconds: seconds,
    coached: false,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  test('weight and reps', () {
    expect(formatSetLog(_set(reps: 8, weightKg: 62.5)), '62.5 kg x 8');
    expect(formatSetLog(_set(reps: 10, weightKg: 60)), '60 kg x 10');
  });

  test('reps only', () {
    expect(formatSetLog(_set(reps: 15)), '15 reps');
  });

  test('duration with and without weight', () {
    expect(formatSetLog(_set(seconds: 45)), '45 s');
    expect(formatSetLog(_set(seconds: 45, weightKg: 10)), '10 kg, 45 s');
  });

  test('weight only and empty sets', () {
    expect(formatSetLog(_set(weightKg: 20)), '20 kg');
    expect(formatSetLog(_set()), 'No data');
  });
}
