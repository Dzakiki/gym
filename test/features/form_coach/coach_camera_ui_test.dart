import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/features/form_coach/camera/camera_pose_source.dart';
import 'package:formcoach/features/form_coach/coach_input.dart';

import '../../helpers/app_harness.dart';

Future<void> _openSquatCoach(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Coach'),
    ),
  );
  await settle(tester);
  await tester.tap(find.text('Squat'));
  await settle(tester);
}

Future<CameraPoseSource> _denied(CameraLensDirection lens) async =>
    throw CameraException('CameraAccessDenied', 'Denied.');

void main() {
  appTest('explains the camera before asking for it', (tester, db) async {
    await _openSquatCoach(tester);

    expect(
      find.text('The coach watches you through the camera'),
      findsOneWidget,
    );
    expect(find.textContaining('never uploaded'), findsOneWidget);
    expect(find.text('Start'), findsNothing);

    await tester.tap(find.text('Continue'));
    await settle(tester);

    // The test harness has no camera.
    expect(find.text('The camera could not be opened'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  }, coachInput: CoachInput.camera);

  appTest(
    'says how to allow the camera when it was refused',
    (tester, db) async {
      await _openSquatCoach(tester);
      await tester.tap(find.text('Continue'));
      await settle(tester);

      expect(find.text('Camera access is off'), findsOneWidget);
      expect(find.textContaining('Permissions'), findsOneWidget);
    },
    coachInput: CoachInput.camera,
    openCamera: _denied,
  );

  appTest(
    'explains the camera only once',
    (tester, db) async {
      await _openSquatCoach(tester);

      expect(find.text('Continue'), findsNothing);
      expect(find.text('Camera access is off'), findsOneWidget);
    },
    coachInput: CoachInput.camera,
    openCamera: _denied,
    initialSettings: {'camera_explained': true},
  );

  appTest('the demo can be chosen instead of the camera', (tester, db) async {
    await _openSquatCoach(tester);

    await tester.tap(find.text('Try the demo instead'));
    await settle(tester);

    expect(find.textContaining('Demo mode'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(find.byTooltip('Use the camera'), findsOneWidget);
  }, coachInput: CoachInput.camera);

  appTest('the camera can be chosen from the demo', (tester, db) async {
    await _openSquatCoach(tester);
    expect(find.textContaining('Demo mode'), findsOneWidget);

    await tester.tap(find.byTooltip('Use the camera'));
    await settle(tester);

    expect(
      find.text('The coach watches you through the camera'),
      findsOneWidget,
    );
    expect(find.byTooltip('Use the demo'), findsOneWidget);
  });
}
