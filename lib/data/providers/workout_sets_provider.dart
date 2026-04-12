import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import 'database_provider.dart';

/// Watches all sets logged today, reactive to changes.
final todaySetsProvider = StreamProvider<List<WorkoutSet>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchTodaySets();
});

/// Gets today's sets for a specific exercise.
final todaySetsForExerciseProvider =
    FutureProvider.family<List<WorkoutSet>, int>((ref, exerciseId) {
  final db = ref.watch(databaseProvider);
  return db.getTodaySetsForExercise(exerciseId);
});

/// Gets all sets for an exercise (for history screen).
final allSetsForExerciseProvider =
    FutureProvider.family<List<WorkoutSet>, int>((ref, exerciseId) {
  final db = ref.watch(databaseProvider);
  return db.getAllSetsForExercise(exerciseId);
});

/// Service provider for logging a new set.
final logSetProvider = Provider<
    Future<int> Function({
      required int exerciseId,
      required double weight,
      required int reps,
      required int setNumber,
    })>((ref) {
  final db = ref.watch(databaseProvider);
  return ({
    required int exerciseId,
    required double weight,
    required int reps,
    required int setNumber,
  }) {
    return db.insertWorkoutSet(
      WorkoutSetsCompanion.insert(
        exerciseId: exerciseId,
        weight: weight,
        reps: reps,
        setNumber: setNumber,
        loggedAt: DateTime.now(),
      ),
    );
  };
});

/// Service provider for deleting a set.
final deleteSetProvider = Provider<Future<int> Function(int id)>((ref) {
  final db = ref.watch(databaseProvider);
  return (int id) => db.deleteWorkoutSet(id);
});

/// Groups today's sets by exercise ID for the Today screen.
final todaySetsByExerciseProvider =
    Provider<Map<int, List<WorkoutSet>>>((ref) {
  final setsAsync = ref.watch(todaySetsProvider);
  return setsAsync.when(
    data: (sets) {
      final map = <int, List<WorkoutSet>>{};
      for (final set in sets) {
        map.putIfAbsent(set.exerciseId, () => []).add(set);
      }
      return map;
    },
    loading: () => {},
    error: (_, __) => {},
  );
});
