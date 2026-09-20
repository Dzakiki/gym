import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formcoach/app/app.dart';
import 'package:formcoach/data/providers.dart';
import 'package:formcoach/features/settings/settings_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
  );
  // Make sure the built-in exercises and templates exist before the UI reads them.
  await container.read(seedServiceProvider).seedAll();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const FormCoachApp(),
    ),
  );
}
