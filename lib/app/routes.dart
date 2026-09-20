/// Route paths used for navigation outside the router definition.
abstract final class AppRoutes {
  static const exerciseLibrary = '/workouts/exercises';

  static String exerciseDetail(String id) => '$exerciseLibrary/$id';
}
