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
final addExerciseProvider = Provider<
    Future<int> Function({
      required String name,
      required String muscleGroup,
      required String measurementType,
    })>((ref) {
  final db = ref.watch(databaseProvider);
  return ({
    required String name,
    required String muscleGroup,
    required String measurementType,
  }) {
    return db.insertExercise(
      ExercisesCompanion.insert(
        name: name,
        muscleGroup: muscleGroup,
        measurementType: Value(measurementType),
        isCustom: const Value(true),
      ),
    );
  };
});

/// Provider for updating an exercise's name/muscle group/measurement type.
final updateExerciseProvider = Provider<
    Future<bool> Function({
      required int id,
      required String name,
      required String muscleGroup,
      required String measurementType,
      required bool isCustom,
      required DateTime createdAt,
    })>((ref) {
  final db = ref.watch(databaseProvider);
  return ({
    required int id,
    required String name,
    required String muscleGroup,
    required String measurementType,
    required bool isCustom,
    required DateTime createdAt,
  }) {
    return db.updateExercise(
      ExercisesCompanion(
        id: Value(id),
        name: Value(name),
        muscleGroup: Value(muscleGroup),
        measurementType: Value(measurementType),
        isCustom: Value(isCustom),
        createdAt: Value(createdAt),
      ),
    );
  };
});

/// Provider for deleting a custom exercise.
final deleteExerciseProvider = Provider<Future<int> Function(int id)>((ref) {
  final db = ref.watch(databaseProvider);
  return (int id) => db.deleteExercise(id);
});
