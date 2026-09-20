import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/data/repositories/progress_repository.dart';
import 'package:formcoach/features/progress/progress_stats.dart';

CompletedSetRecord _set(
  String exercise,
  DateTime at, {
  double? weight,
  int? reps,
  int? seconds,
}) => CompletedSetRecord(
  exerciseId: 'id-$exercise',
  exerciseName: exercise,
  completedAt: at,
  weightKg: weight,
  reps: reps,
  durationSeconds: seconds,
);

DateTime _day(int month, int day) => DateTime(2026, month, day, 9);

void main() {
  // Wednesday 23 September 2026.
  final now = DateTime(2026, 9, 23, 12);

  group('weeklyVolumes', () {
    test('returns one entry per week, oldest first, ending this week', () {
      final volumes = weeklyVolumes(const [], now, weeks: 4);

      expect(volumes.map((v) => v.weekStart), [
        DateTime(2026, 8, 31),
        DateTime(2026, 9, 7),
        DateTime(2026, 9, 14),
        DateTime(2026, 9, 21),
      ]);
      expect(volumes.every((v) => v.volumeKg == 0), isTrue);
    });

    test('adds up reps x weight within a week', () {
      final volumes = weeklyVolumes(
        [
          _set('Bench', _day(9, 21), weight: 60, reps: 10),
          _set('Bench', _day(9, 22), weight: 60, reps: 8),
          _set('Squat', _day(9, 15), weight: 100, reps: 5),
        ],
        now,
        weeks: 2,
      );

      expect(volumes[0].volumeKg, 500);
      expect(volumes[1].volumeKg, 600 + 480);
    });

    test('ignores sets without a weight or reps', () {
      final volumes = weeklyVolumes(
        [
          _set('Push-up', _day(9, 22), reps: 20),
          _set('Plank', _day(9, 22), seconds: 60),
        ],
        now,
        weeks: 1,
      );

      expect(volumes.single.volumeKg, 0);
    });

    test('leaves out weeks older than the window', () {
      final volumes = weeklyVolumes(
        [_set('Bench', _day(7, 1), weight: 60, reps: 10)],
        now,
        weeks: 3,
      );

      expect(volumes.fold<double>(0, (sum, v) => sum + v.volumeKg), 0);
    });
  });

  group('personalRecords', () {
    test('finds the heaviest weight with its repetitions', () {
      final records = personalRecords([
        _set('Bench', _day(9, 1), weight: 60, reps: 10),
        _set('Bench', _day(9, 8), weight: 80, reps: 5),
        _set('Bench', _day(9, 15), weight: 70, reps: 8),
      ], const []);

      final heaviest = records.singleWhere(
        (r) => r.kind == RecordKind.heaviest,
      );
      expect(heaviest.exerciseName, 'Bench');
      expect(heaviest.value, 80);
      expect(heaviest.reps, 5);
      expect(heaviest.achievedAt, _day(9, 8));
    });

    test('a tie goes to the most recent set', () {
      final records = personalRecords([
        _set('Bench', _day(9, 1), weight: 80, reps: 5),
        _set('Bench', _day(9, 15), weight: 80, reps: 6),
      ], const []);

      expect(records.single.achievedAt, _day(9, 15));
      expect(records.single.reps, 6);
    });

    test('finds the most reps without added weight', () {
      final records = personalRecords([
        _set('Push-up', _day(9, 1), reps: 15),
        _set('Push-up', _day(9, 8), reps: 25),
        _set('Push-up', _day(9, 15), weight: 0, reps: 20),
      ], const []);

      final best = records.singleWhere((r) => r.kind == RecordKind.mostReps);
      expect(best.value, 25);
      expect(records.any((r) => r.kind == RecordKind.heaviest), isFalse);
    });

    test('finds the longest timed hold', () {
      final records = personalRecords([
        _set('Plank', _day(9, 1), seconds: 30),
        _set('Plank', _day(9, 8), seconds: 75),
      ], const []);

      final hold = records.singleWhere((r) => r.kind == RecordKind.longestHold);
      expect(hold.value, 75);
    });

    test('finds the best form score per coached exercise', () {
      final records = personalRecords(const [], [
        CoachScorePoint(exerciseKey: 'squat', score: 80, at: _day(9, 1)),
        CoachScorePoint(exerciseKey: 'squat', score: 95, at: _day(9, 8)),
        CoachScorePoint(exerciseKey: 'squat', score: 90, at: _day(9, 15)),
        CoachScorePoint(exerciseKey: 'pushup', score: 70, at: _day(9, 16)),
      ]);

      final squat = records.singleWhere((r) => r.exerciseName == 'Squat');
      expect(squat.kind, RecordKind.bestForm);
      expect(squat.value, 95);
      expect(records.any((r) => r.exerciseName == 'Push-up'), isTrue);
    });

    test('lists the most recent record first', () {
      final records = personalRecords([
        _set('Bench', _day(9, 1), weight: 80, reps: 5),
        _set('Plank', _day(9, 20), seconds: 60),
      ], const []);

      expect(records.map((r) => r.exerciseName), ['Plank', 'Bench']);
    });

    test('has nothing to report without data', () {
      expect(personalRecords(const [], const []), isEmpty);
    });
  });
}
