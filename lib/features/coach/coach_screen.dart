import 'package:flutter/material.dart';
import 'package:formcoach/core/widgets/empty_state.dart';

class CoachScreen extends StatelessWidget {
  const CoachScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Coach')),
      body: const EmptyState(
        icon: Icons.videocam,
        title: 'Coach',
        message: 'The AI form coach will live here.',
      ),
    );
  }
}
