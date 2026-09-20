import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/data/local/app_database.dart';
import 'package:formcoach/features/routines/routine_formatting.dart';

RoutineExercise _entry({int sets = 3, int? reps, int? seconds}) {
  final now = DateTime.utc(2026);
  return RoutineExercise(
    id: 'x',
    routineId: 'r',
    exerciseId: 'e',
    position: 0,
    targetSets: sets,
    targetReps: reps,
    targetSeconds: seconds,
    restSeconds: 90,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('formatTarget', () {
    test('shows sets x reps', () {
      expect(formatTarget(_entry(sets: 4, reps: 8)), '4 x 8');
    });

    test('shows sets x seconds for timed exercises', () {
      expect(formatTarget(_entry(seconds: 30)), '3 x 30 s');
    });

    test('falls back to the number of sets', () {
      expect(formatTarget(_entry(sets: 5)), '5 sets');
    });
  });

  group('formatRest', () {
    test('uses minutes for whole minutes', () {
      expect(formatRest(120), '2 min');
    });

    test('uses seconds otherwise', () {
      expect(formatRest(90), '90 s');
      expect(formatRest(45), '45 s');
    });
  });

  group('weekdayLabel', () {
    test('maps ISO weekdays', () {
      expect(weekdayLabel(1), 'Mon');
      expect(weekdayLabel(7), 'Sun');
    });

    test('rejects out-of-range days', () {
      expect(() => weekdayLabel(0), throwsRangeError);
      expect(() => weekdayLabel(8), throwsRangeError);
    });
  });
}
