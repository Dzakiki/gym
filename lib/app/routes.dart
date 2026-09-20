/// Route paths used for navigation outside the router definition.
abstract final class AppRoutes {
  static const exerciseLibrary = '/workouts/exercises';
  static const pickExercise = '/workouts/pick-exercise';
  static const routines = '/workouts/routines';
  static const newRoutine = '/workouts/routines/new';

  static String exerciseDetail(String id) => '$exerciseLibrary/$id';

  static String routineDetail(String id) => '$routines/$id';

  static String editRoutine(String id) => '$routines/$id/edit';
}
