/// Limits enforced when saving a routine.
abstract final class RoutineLimits {
  static const maxNameLength = 100;
  static const maxSets = 20;
  static const maxReps = 200;
  static const maxSeconds = 3600;
  static const maxRestSeconds = 600;
}

/// One exercise being edited inside a [RoutineDraft].
///
/// A target is either a number of reps or a duration in seconds, never both.
class DraftItem {
  const DraftItem({
    required this.exerciseId,
    required this.exerciseName,
    this.id,
    this.targetSets = 3,
    this.targetReps,
    this.targetSeconds,
    this.restSeconds = 90,
  });

  /// A newly added exercise with the default target of 3 sets x 10 reps.
  factory DraftItem.forExercise({
    required String exerciseId,
    required String exerciseName,
  }) => DraftItem(
    exerciseId: exerciseId,
    exerciseName: exerciseName,
    targetReps: 10,
  );

  /// The id of the saved row, or null for an item that was just added.
  final String? id;
  final String exerciseId;
  final String exerciseName;
  final int targetSets;
  final int? targetReps;
  final int? targetSeconds;
  final int restSeconds;

  DraftItem copyWith({int? targetSets, int? restSeconds}) => DraftItem(
    id: id,
    exerciseId: exerciseId,
    exerciseName: exerciseName,
    targetSets: targetSets ?? this.targetSets,
    targetReps: targetReps,
    targetSeconds: targetSeconds,
    restSeconds: restSeconds ?? this.restSeconds,
  );

  /// Targets [reps] repetitions per set (clears any duration).
  DraftItem withReps(int reps) => DraftItem(
    id: id,
    exerciseId: exerciseId,
    exerciseName: exerciseName,
    targetSets: targetSets,
    targetReps: reps,
    restSeconds: restSeconds,
  );

  /// Targets [seconds] per set (clears any rep target).
  DraftItem withSeconds(int seconds) => DraftItem(
    id: id,
    exerciseId: exerciseId,
    exerciseName: exerciseName,
    targetSets: targetSets,
    targetSeconds: seconds,
    restSeconds: restSeconds,
  );

  /// A message describing the first problem with this item, or null.
  String? get validationError {
    if (targetSets < 1 || targetSets > RoutineLimits.maxSets) {
      return 'Sets must be between 1 and ${RoutineLimits.maxSets}.';
    }
    if ((targetReps == null) == (targetSeconds == null)) {
      return 'Set either reps or seconds.';
    }
    final reps = targetReps;
    if (reps != null && (reps < 1 || reps > RoutineLimits.maxReps)) {
      return 'Reps must be between 1 and ${RoutineLimits.maxReps}.';
    }
    final seconds = targetSeconds;
    if (seconds != null &&
        (seconds < 1 || seconds > RoutineLimits.maxSeconds)) {
      return 'Seconds must be between 1 and ${RoutineLimits.maxSeconds}.';
    }
    if (restSeconds < 0 || restSeconds > RoutineLimits.maxRestSeconds) {
      return 'Rest must be between 0 and ${RoutineLimits.maxRestSeconds} seconds.';
    }
    return null;
  }
}

/// An editable, in-memory version of a routine used by the builder screen.
class RoutineDraft {
  const RoutineDraft({
    this.id,
    this.name = '',
    this.description = '',
    this.scheduleDays = const [],
    this.items = const [],
  });

  /// The id of the saved routine, or null for a new one.
  final String? id;
  final String name;
  final String description;

  /// ISO weekdays (1 = Monday ... 7 = Sunday).
  final List<int> scheduleDays;
  final List<DraftItem> items;

  RoutineDraft copyWith({
    String? name,
    String? description,
    List<int>? scheduleDays,
    List<DraftItem>? items,
  }) => RoutineDraft(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    scheduleDays: scheduleDays ?? this.scheduleDays,
    items: items ?? this.items,
  );

  /// A message describing the first problem with this routine, or null.
  String? get validationError {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Give the routine a name.';
    if (trimmed.length > RoutineLimits.maxNameLength) {
      return 'The name can be at most ${RoutineLimits.maxNameLength} characters.';
    }
    if (items.isEmpty) return 'Add at least one exercise.';
    if (scheduleDays.any((day) => day < 1 || day > 7)) {
      return 'Weekdays must be between 1 and 7.';
    }
    for (final item in items) {
      final error = item.validationError;
      if (error != null) return '${item.exerciseName}: $error';
    }
    return null;
  }
}
