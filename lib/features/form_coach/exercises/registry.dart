import 'package:formcoach/features/form_coach/engine/exercise_definition.dart';
import 'package:formcoach/features/form_coach/exercises/dip.dart';
import 'package:formcoach/features/form_coach/exercises/lunge.dart';
import 'package:formcoach/features/form_coach/exercises/plank.dart';
import 'package:formcoach/features/form_coach/exercises/pullup.dart';
import 'package:formcoach/features/form_coach/exercises/pushup.dart';
import 'package:formcoach/features/form_coach/exercises/squat.dart';

/// Every exercise the Form Coach supports, by `coach_key`.
final Map<String, ExerciseDefinition> coachExercises = {
  for (final definition in [squat, pushup, plank, dip, pullup, lunge])
    definition.key: definition,
};

/// The coach definition for [coachKey], or null if the exercise is not (yet)
/// supported by the coach.
ExerciseDefinition? coachDefinitionFor(String? coachKey) =>
    coachKey == null ? null : coachExercises[coachKey];
