import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formcoach/app/app_tab.dart';
import 'package:formcoach/features/coach/coach_screen.dart';
import 'package:formcoach/features/exercises/exercise_detail_screen.dart';
import 'package:formcoach/features/exercises/exercise_library_screen.dart';
import 'package:formcoach/features/form_coach/ui/coach_session_screen.dart';
import 'package:formcoach/features/history/workout_detail_screen.dart';
import 'package:formcoach/features/home/home_screen.dart';
import 'package:formcoach/features/profile/profile_screen.dart';
import 'package:formcoach/features/progress/progress_screen.dart';
import 'package:formcoach/features/routines/routine_builder_screen.dart';
import 'package:formcoach/features/routines/routine_detail_screen.dart';
import 'package:formcoach/features/shell/shell_scaffold.dart';
import 'package:formcoach/features/workout/active_workout_screen.dart';
import 'package:formcoach/features/workouts/workouts_screen.dart';
import 'package:go_router/go_router.dart';

/// Builds the root screen of each tab.
Widget _screenFor(AppTab tab) => switch (tab) {
  AppTab.home => const HomeScreen(),
  AppTab.workouts => const WorkoutsScreen(),
  AppTab.coach => const CoachScreen(),
  AppTab.progress => const ProgressScreen(),
  AppTab.profile => const ProfileScreen(),
};

/// Screens pushed on top of a tab's root screen.
List<RouteBase> _subRoutesFor(AppTab tab) => switch (tab) {
  AppTab.workouts => [
    GoRoute(
      path: 'exercises',
      builder: (context, state) => const ExerciseLibraryScreen(),
      routes: [
        GoRoute(
          path: ':id',
          builder: (context, state) =>
              ExerciseDetailScreen(exerciseId: state.pathParameters['id']!),
        ),
      ],
    ),
    GoRoute(
      path: 'pick-exercise',
      builder: (context, state) =>
          const ExerciseLibraryScreen(selectMode: true),
    ),
    // 'routines/new' must come before 'routines/:id' so it is not read as an id.
    GoRoute(
      path: 'routines/new',
      builder: (context, state) => const RoutineBuilderScreen(),
    ),
    GoRoute(
      path: 'routines/:id',
      builder: (context, state) =>
          RoutineDetailScreen(routineId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: 'routines/:id/edit',
      builder: (context, state) =>
          RoutineBuilderScreen(routineId: state.pathParameters['id']),
    ),
  ],
  AppTab.progress => [
    GoRoute(
      path: 'workouts/:id',
      builder: (context, state) =>
          WorkoutDetailScreen(workoutId: state.pathParameters['id']!),
    ),
  ],
  _ => const [],
};

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppTab.home.path,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ShellScaffold(navigationShell: navigationShell),
        branches: [
          for (final tab in AppTab.values)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: tab.path,
                  builder: (context, state) => _screenFor(tab),
                  routes: _subRoutesFor(tab),
                ),
              ],
            ),
        ],
      ),
      // Full screen, above the tab bar, so the whole picture is visible.
      GoRoute(
        path: '/coach-session/:key',
        builder: (context, state) => CoachSessionScreen(
          coachKey: state.pathParameters['key']!,
          setLogId: state.uri.queryParameters['set'],
        ),
      ),
      // Full screen, above the tab bar, so nothing distracts while training.
      GoRoute(
        path: '/workout/:id',
        builder: (context, state) =>
            ActiveWorkoutScreen(workoutId: state.pathParameters['id']!),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
