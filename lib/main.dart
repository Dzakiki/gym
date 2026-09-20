import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formcoach/app/app.dart';
import 'package:formcoach/data/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();
  // Make sure the built-in exercises and templates exist before the UI reads them.
  await container.read(seedServiceProvider).seedAll();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const FormCoachApp(),
    ),
  );
}
