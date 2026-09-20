import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/domain/weight_unit.dart';
import 'package:formcoach/features/settings/settings_store.dart';
import 'package:formcoach/features/workout/set_input.dart';
import 'package:formcoach/features/workout/workout_formatting.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/app_harness.dart';

Future<void> _openProfile(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Profile'),
    ),
  );
  await settle(tester);
}

void main() {
  group('WeightUnit', () {
    test('kg is the identity', () {
      expect(WeightUnit.kg.fromKg(60), 60);
      expect(WeightUnit.kg.toKg(60), 60);
    });

    test('converts between kg and lb', () {
      expect(WeightUnit.lb.fromKg(100), closeTo(220.462, 0.001));
      expect(WeightUnit.lb.toKg(220.462), closeTo(100, 0.001));
    });

    test('a round trip keeps the number', () {
      expect(
        WeightUnit.lb.toKg(WeightUnit.lb.fromKg(72.5)),
        closeTo(72.5, 1e-9),
      );
    });
  });

  group('formatting in pounds', () {
    test('weights are converted and rounded to one decimal', () {
      expect(formatWeight(60, unit: WeightUnit.lb), '132.3');
      expect(formatWeight(WeightUnit.lb.toKg(135), unit: WeightUnit.lb), '135');
      expect(formatWeight(null, unit: WeightUnit.lb), '');
    });

    test('volume shows the unit', () {
      expect(formatVolume(1000, unit: WeightUnit.lb), '2,205 lb');
      expect(formatVolume(1000), '1,000 kg');
    });
  });

  group('SettingsStore', () {
    test('has sensible defaults', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SettingsStore(await SharedPreferences.getInstance());

      expect(store.weightUnit, WeightUnit.kg);
      expect(store.voiceCues, isTrue);
    });

    test('remembers what was chosen', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      await SettingsStore(preferences).setWeightUnit(WeightUnit.lb);
      await SettingsStore(preferences).setVoiceCues(enabled: false);

      final reloaded = SettingsStore(preferences);
      expect(reloaded.weightUnit, WeightUnit.lb);
      expect(reloaded.voiceCues, isFalse);
    });

    test('ignores an unknown stored unit', () async {
      SharedPreferences.setMockInitialValues({'weight_unit': 'stone'});
      final store = SettingsStore(await SharedPreferences.getInstance());

      expect(store.weightUnit, WeightUnit.kg);
    });
  });

  appTest('the profile screen shows the settings', (tester, db) async {
    await _openProfile(tester);

    expect(find.text('Weight unit'), findsOneWidget);
    expect(find.text('Spoken cues'), findsOneWidget);
    expect(find.textContaining('not medical advice'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  appTest('the voice switch can be turned off', (tester, db) async {
    await _openProfile(tester);

    await tester.tap(find.byType(Switch));
    await settle(tester);

    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  appTest('a saved unit is used when the app starts', (tester, db) async {
    await _openProfile(tester);

    final selected = tester.widget<SegmentedButton<WeightUnit>>(
      find.byType(SegmentedButton<WeightUnit>),
    );
    expect(selected.selected, {WeightUnit.lb});
  }, initialSettings: {'weight_unit': 'lb'});

  appTest('switching to lb changes the workout screen and stores kg', (
    tester,
    db,
  ) async {
    await _openProfile(tester);
    await tester.tap(find.text('lb'));
    await settle(tester);

    await openWorkoutsTab(tester);
    await tester.tap(find.text('Push day'));
    await settle(tester);
    await tester.tap(find.text('Start workout'));
    await settle(tester);

    expect(find.widgetWithText(TextFormField, 'lb'), findsWidgets);
    expect(find.widgetWithText(TextFormField, 'kg'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'lb').first,
      '135',
    );
    await settle(tester);
    final sets = await tester.runAsync(() => db.select(db.setLogs).get());
    final weights = sets!.map((s) => s.weightKg).whereType<double>();
    expect(weights.single, closeTo(61.235, 0.001));
  });
}
