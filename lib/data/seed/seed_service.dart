import 'package:formcoach/data/seed/exercise_seeder.dart';
import 'package:formcoach/data/seed/template_seeder.dart';

/// Seeds all built-in data in dependency order (exercises before templates).
class SeedService {
  SeedService({required this._exercises, required this._templates});

  final ExerciseSeeder _exercises;
  final TemplateSeeder _templates;

  Future<void> seedAll() async {
    await _exercises.seed();
    await _templates.seed();
  }
}
