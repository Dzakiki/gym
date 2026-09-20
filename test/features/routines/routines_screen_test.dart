import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_harness.dart';

void main() {
  appTest('lists the program templates and an empty routines section', (
    tester,
    db,
  ) async {
    await openWorkoutsTab(tester);

    expect(find.text('Push day'), findsOneWidget);
    expect(find.text('Beginner full body'), findsOneWidget);
    expect(
      find.text('No routines yet. Copy a program template below to start.'),
      findsOneWidget,
    );
  });

  appTest('a template shows its exercises and a copy button', (
    tester,
    db,
  ) async {
    await openWorkoutsTab(tester);

    await tester.tap(find.text('Push day'));
    await tester.pumpAndSettle();

    expect(find.text('Bench press'), findsOneWidget);
    expect(find.text('4 x 8'), findsOneWidget);
    expect(find.text('Copy to my routines'), findsOneWidget);
    expect(find.byTooltip('Delete routine'), findsNothing);
  });

  appTest('copying a template adds it to my routines', (tester, db) async {
    await openWorkoutsTab(tester);
    await tester.tap(find.text('Push day'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Copy to my routines'));
    await tester.pumpAndSettle();

    expect(find.text('Added to my routines'), findsOneWidget);
    expect(find.text('Copy to my routines'), findsNothing);
    expect(find.byTooltip('Delete routine'), findsOneWidget);
  });

  appTest('deleting a routine removes it from the list', (tester, db) async {
    await openWorkoutsTab(tester);
    await tester.tap(find.text('Push day'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy to my routines'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete routine'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(
      find.text('No routines yet. Copy a program template below to start.'),
      findsOneWidget,
    );
  });
}
