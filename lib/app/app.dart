import 'package:flutter/material.dart';

/// Root widget of the FormCoach app.
class FormCoachApp extends StatelessWidget {
  const FormCoachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FormCoach',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const Scaffold(body: Center(child: Text('FormCoach'))),
    );
  }
}
