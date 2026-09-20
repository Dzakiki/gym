import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/app/app_tab.dart';
import 'package:formcoach/features/coach/coach_screen.dart';
import 'package:formcoach/features/home/home_screen.dart';
import 'package:formcoach/features/profile/profile_screen.dart';
import 'package:formcoach/features/progress/progress_screen.dart';
import 'package:formcoach/features/workouts/workouts_screen.dart';

import 'helpers/app_harness.dart';

void main() {
  appTest('starts on the Home tab', (tester, db) async {
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  appTest('shows one destination per tab', (tester, db) async {
    expect(
      find.byType(NavigationDestination),
      findsNWidgets(AppTab.values.length),
    );
  });

  appTest('tapping each tab shows its screen', (tester, db) async {
    final screens = <AppTab, Type>{
      AppTab.workouts: WorkoutsScreen,
      AppTab.coach: CoachScreen,
      AppTab.progress: ProgressScreen,
      AppTab.profile: ProfileScreen,
      AppTab.home: HomeScreen,
    };

    for (final entry in screens.entries) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(entry.key.label),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(entry.value), findsOneWidget, reason: entry.key.name);
    }
  });
}
