import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/data/repositories/routine_draft.dart';

final _squat = DraftItem.forExercise(exerciseId: 'e1', exerciseName: 'Squat');

RoutineDraft _valid() => RoutineDraft(name: 'Legs', items: [_squat]);

void main() {
  group('DraftItem', () {
    test('defaults to 3 x 10 with 90 s rest', () {
      expect(_squat.targetSets, 3);
      expect(_squat.targetReps, 10);
      expect(_squat.targetSeconds, isNull);
      expect(_squat.restSeconds, 90);
      expect(_squat.validationError, isNull);
    });

    test('withSeconds replaces the rep target', () {
      final timed = _squat.withSeconds(45);

      expect(timed.targetReps, isNull);
      expect(timed.targetSeconds, 45);
      expect(timed.validationError, isNull);
    });

    test('withReps replaces the duration target', () {
      final reps = _squat.withSeconds(45).withReps(12);

      expect(reps.targetSeconds, isNull);
      expect(reps.targetReps, 12);
    });

    test('copyWith keeps id and targets it does not change', () {
      final copy = const DraftItem(
        id: 'row-1',
        exerciseId: 'e1',
        exerciseName: 'Squat',
        targetReps: 10,
      ).copyWith(targetSets: 5);

      expect(copy.id, 'row-1');
      expect(copy.targetSets, 5);
      expect(copy.targetReps, 10);
    });

    test('rejects out-of-range values', () {
      expect(_squat.copyWith(targetSets: 0).validationError, isNotNull);
      expect(_squat.copyWith(targetSets: 21).validationError, isNotNull);
      expect(_squat.withReps(0).validationError, isNotNull);
      expect(_squat.withReps(201).validationError, isNotNull);
      expect(_squat.withSeconds(3601).validationError, isNotNull);
      expect(_squat.copyWith(restSeconds: -1).validationError, isNotNull);
      expect(_squat.copyWith(restSeconds: 601).validationError, isNotNull);
    });

    test('rejects an item with neither reps nor seconds', () {
      const item = DraftItem(
        exerciseId: 'e1',
        exerciseName: 'Squat',
        targetReps: null,
      );

      expect(item.validationError, 'Set either reps or seconds.');
    });
  });

  group('RoutineDraft', () {
    test('a named routine with an exercise is valid', () {
      expect(_valid().validationError, isNull);
    });

    test('requires a name', () {
      expect(_valid().copyWith(name: '   ').validationError, isNotNull);
    });

    test('rejects an overlong name', () {
      expect(_valid().copyWith(name: 'x' * 101).validationError, isNotNull);
    });

    test('requires at least one exercise', () {
      expect(_valid().copyWith(items: const []).validationError, isNotNull);
    });

    test('rejects invalid weekdays', () {
      expect(_valid().copyWith(scheduleDays: [0]).validationError, isNotNull);
      expect(_valid().copyWith(scheduleDays: [8]).validationError, isNotNull);
      expect(_valid().copyWith(scheduleDays: [1, 7]).validationError, isNull);
    });

    test('reports which exercise has a problem', () {
      final draft = _valid().copyWith(items: [_squat.copyWith(targetSets: 0)]);

      expect(draft.validationError, startsWith('Squat:'));
    });
  });
}
