import 'package:flutter/material.dart';
import 'package:formcoach/app/routes.dart';
import 'package:formcoach/features/form_coach/engine/body_side.dart';
import 'package:formcoach/features/form_coach/exercises/registry.dart';
import 'package:go_router/go_router.dart';

/// Lists the exercises the AI form coach can watch.
class CoachScreen extends StatelessWidget {
  const CoachScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Coach')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Pick an exercise to get live feedback on your form.'),
          ),
          for (final definition in coachExercises.values)
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: Text(definition.name),
              subtitle: Text(
                definition.view == CameraView.side
                    ? 'Film yourself from the side'
                    : 'Film yourself from the front',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.coachSession(definition.key)),
            ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Push-up, lunge, plank and jumping jack are coming.'),
          ),
        ],
      ),
    );
  }
}
