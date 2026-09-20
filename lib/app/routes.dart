/// Route paths used for navigation outside the router definition.
abstract final class AppRoutes {
  static const workouts = '/workouts';
  static const exerciseLibrary = '/workouts/exercises';
  static const pickExercise = '/workouts/pick-exercise';
  static const routines = '/workouts/routines';
  static const newRoutine = '/workouts/routines/new';

  /// The coach screen for [coachKey]. With [setLogId] the results can be saved
  /// into that set of the workout in progress.
  static String coachSession(String coachKey, {String? setLogId}) {
    final path = '/coach-session/$coachKey';
    return setLogId == null ? path : '$path?set=$setLogId';
  }

  static String historyDetail(String id) => '/progress/workouts/$id';

  static String workout(String id) => '/workout/$id';

  static String exerciseDetail(String id) => '$exerciseLibrary/$id';

  static String routineDetail(String id) => '$routines/$id';

  static String editRoutine(String id) => '$routines/$id/edit';
}
