import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formcoach/app/app.dart';
import 'package:formcoach/data/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();
  // Make sure the built-in exercise library exists before the UI reads it.
  await container.read(exerciseSeederProvider).seed();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const FormCoachApp(),
    ),
  );
}
