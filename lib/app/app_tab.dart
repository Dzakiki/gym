import 'package:flutter/material.dart';

/// The five top-level destinations of the bottom navigation bar.
///
/// The order here is the order of the tabs and of the router branches.
enum AppTab {
  home(
    path: '/home',
    label: 'Home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
  ),
  workouts(
    path: '/workouts',
    label: 'Workouts',
    icon: Icons.fitness_center_outlined,
    selectedIcon: Icons.fitness_center,
  ),
  coach(
    path: '/coach',
    label: 'Coach',
    icon: Icons.videocam_outlined,
    selectedIcon: Icons.videocam,
  ),
  progress(
    path: '/progress',
    label: 'Progress',
    icon: Icons.show_chart_outlined,
    selectedIcon: Icons.show_chart,
  ),
  profile(
    path: '/profile',
    label: 'Profile',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
  );

  const AppTab({
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
