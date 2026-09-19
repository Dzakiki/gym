import 'package:flutter/material.dart';
import 'package:formcoach/core/widgets/empty_state.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: const EmptyState(
        icon: Icons.show_chart,
        title: 'Progress',
        message: 'Charts and personal records will live here.',
      ),
    );
  }
}
