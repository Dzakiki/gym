import 'package:formcoach/features/form_coach/engine/exercise_definition.dart';
import 'package:formcoach/features/form_coach/exercises/pushup.dart';
import 'package:formcoach/features/form_coach/exercises/squat.dart';

/// Every exercise the Form Coach supports, by `coach_key`.
final Map<String, ExerciseDefinition> coachExercises = {
  for (final definition in [squat, pushup]) definition.key: definition,
};

/// The coach definition for [coachKey], or null if the exercise is not (yet)
/// supported by the coach.
ExerciseDefinition? coachDefinitionFor(String? coachKey) =>
    coachKey == null ? null : coachExercises[coachKey];
