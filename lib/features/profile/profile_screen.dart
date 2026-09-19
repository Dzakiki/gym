import 'package:flutter/material.dart';
import 'package:formcoach/core/widgets/empty_state.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: const EmptyState(
        icon: Icons.person,
        title: 'Profile',
        message: 'Your profile and settings will live here.',
      ),
    );
  }
}
