import 'package:formcoach/domain/enums.dart';

/// Human-readable names for enum values shown in the UI.
extension ExerciseCategoryLabel on ExerciseCategory {
  String get label => switch (this) {
    ExerciseCategory.strength => 'Strength',
    ExerciseCategory.cardio => 'Cardio',
    ExerciseCategory.core => 'Core',
    ExerciseCategory.mobility => 'Mobility',
  };
}

extension EquipmentLabel on Equipment {
  String get label => switch (this) {
    Equipment.bodyweight => 'Bodyweight',
    Equipment.dumbbell => 'Dumbbell',
    Equipment.barbell => 'Barbell',
    Equipment.kettlebell => 'Kettlebell',
    Equipment.machine => 'Machine',
    Equipment.band => 'Band',
  };
}

extension MuscleGroupLabel on MuscleGroup {
  String get label => switch (this) {
    MuscleGroup.chest => 'Chest',
    MuscleGroup.back => 'Back',
    MuscleGroup.shoulders => 'Shoulders',
    MuscleGroup.biceps => 'Biceps',
    MuscleGroup.triceps => 'Triceps',
    MuscleGroup.forearms => 'Forearms',
    MuscleGroup.core => 'Core',
    MuscleGroup.glutes => 'Glutes',
    MuscleGroup.quadriceps => 'Quadriceps',
    MuscleGroup.hamstrings => 'Hamstrings',
    MuscleGroup.calves => 'Calves',
    MuscleGroup.fullBody => 'Full body',
  };
}
