import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import 'database_provider.dart';

/// Watches all exercises from the database.
final allExercisesProvider = StreamProvider<List<Exercise>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllExercises();
});

/// Gets a single exercise by ID.
final exerciseByIdProvider =
    FutureProvider.family<Exercise, int>((ref, id) {
  final db = ref.watch(databaseProvider);
  return db.getExerciseById(id);
});

/// Gets the last session's sets for an exercise (for inline display).
final lastSessionSetsProvider =
    FutureProvider.family<List<WorkoutSet>, int>((ref, exerciseId) {
  final db = ref.watch(databaseProvider);
  return db.getLastSessionSets(exerciseId);
});

/// Gets the most recent set for auto-fill.
final mostRecentSetProvider =
    FutureProvider.family<WorkoutSet?, int>((ref, exerciseId) {
  final db = ref.watch(databaseProvider);
  return db.getMostRecentSet(exerciseId);
});

/// Provider for inserting a new custom exercise.
final addExerciseProvider = Provider<Future<int> Function(String name, String muscleGroup)>((ref) {
  final db = ref.watch(databaseProvider);
  return (String name, String muscleGroup) {
    return db.insertExercise(
      ExercisesCompanion.insert(
        name: name,
        muscleGroup: muscleGroup,
        isCustom: const Value(true),
      ),
    );
  };
});
