import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/app/app.dart';
import 'package:formcoach/app/app_tab.dart';
import 'package:formcoach/features/coach/coach_screen.dart';
import 'package:formcoach/features/home/home_screen.dart';
import 'package:formcoach/features/profile/profile_screen.dart';
import 'package:formcoach/features/progress/progress_screen.dart';
import 'package:formcoach/features/workouts/workouts_screen.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: FormCoachApp()));
    await tester.pumpAndSettle();
  }

  testWidgets('starts on the Home tab', (tester) async {
    await pumpApp(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('shows one destination per tab', (tester) async {
    await pumpApp(tester);

    expect(
      find.byType(NavigationDestination),
      findsNWidgets(AppTab.values.length),
    );
  });

  testWidgets('tapping each tab shows its screen', (tester) async {
    await pumpApp(tester);
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
