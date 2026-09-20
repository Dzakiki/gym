/// Route paths used for navigation outside the router definition.
abstract final class AppRoutes {
  static const exerciseLibrary = '/workouts/exercises';
  static const routines = '/workouts/routines';

  static String exerciseDetail(String id) => '$exerciseLibrary/$id';

  static String routineDetail(String id) => '$routines/$id';
}
