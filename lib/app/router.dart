import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formcoach/app/app_tab.dart';
import 'package:formcoach/features/coach/coach_screen.dart';
import 'package:formcoach/features/home/home_screen.dart';
import 'package:formcoach/features/profile/profile_screen.dart';
import 'package:formcoach/features/progress/progress_screen.dart';
import 'package:formcoach/features/shell/shell_scaffold.dart';
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
                ),
              ],
            ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
