import 'package:flutter/material.dart';
import 'package:formcoach/core/widgets/empty_state.dart';

class WorkoutsScreen extends StatelessWidget {
  const WorkoutsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workouts')),
      body: const EmptyState(
        icon: Icons.fitness_center,
        title: 'Workouts',
        message: 'Routines and the exercise library will live here.',
      ),
    );
  }
}
