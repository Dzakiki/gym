import 'package:flutter/material.dart';
import 'package:formcoach/app/routes.dart';
import 'package:go_router/go_router.dart';

class WorkoutsScreen extends StatelessWidget {
  const WorkoutsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workouts')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('Exercise library'),
            subtitle: const Text('Browse and search every exercise'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.exerciseLibrary),
          ),
        ],
      ),
    );
  }
}
