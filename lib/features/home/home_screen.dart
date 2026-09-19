import 'package:flutter/material.dart';
import 'package:formcoach/core/widgets/empty_state.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: const EmptyState(
        icon: Icons.home,
        title: 'Home',
        message: 'Your workout for today will show up here.',
      ),
    );
  }
}
