/// Enums persisted by name in the local database and (later) in Supabase.
///
/// Renaming or removing a value breaks stored data. Add new values instead.
library;

enum ExerciseCategory { strength, cardio, core, mobility }

enum Equipment { bodyweight, dumbbell, barbell, kettlebell, machine, band }

enum MuscleGroup {
  chest,
  back,
  shoulders,
  biceps,
  triceps,
  forearms,
  core,
  glutes,
  quadriceps,
  hamstrings,
  calves,
  fullBody,
}
