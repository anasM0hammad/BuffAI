import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import 'database_provider.dart';

/// Watches all sets logged today, reactive to changes.
final todaySetsProvider = StreamProvider<List<WorkoutSet>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchTodaySets();
});

/// Watches today's sets for a specific exercise. Derived from the stream
/// provider so it auto-updates when new sets are logged.
final todaySetsForExerciseProvider =
    Provider.family<AsyncValue<List<WorkoutSet>>, int>((ref, exerciseId) {
  final allSets = ref.watch(todaySetsProvider);
  return allSets.whenData(
    (sets) => sets.where((s) => s.exerciseId == exerciseId).toList()
      ..sort((a, b) => a.setNumber.compareTo(b.setNumber)),
  );
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

/// Service provider for updating an existing set.
final updateSetProvider = Provider<
    Future<bool> Function({
      required int id,
      required int exerciseId,
      required double weight,
      required int reps,
      required int setNumber,
      required DateTime loggedAt,
    })>((ref) {
  final db = ref.watch(databaseProvider);
  return ({
    required int id,
    required int exerciseId,
    required double weight,
    required int reps,
    required int setNumber,
    required DateTime loggedAt,
  }) {
    return db.updateWorkoutSet(
      WorkoutSetsCompanion(
        id: Value(id),
        exerciseId: Value(exerciseId),
        weight: Value(weight),
        reps: Value(reps),
        setNumber: Value(setNumber),
        loggedAt: Value(loggedAt),
      ),
    );
  };
});

/// Service provider for deleting a set.
final deleteSetProvider = Provider<Future<int> Function(int id)>((ref) {
  final db = ref.watch(databaseProvider);
  return (int id) => db.deleteWorkoutSet(id);
});

/// Service provider for deleting all of today's sets for an exercise.
final deleteTodaySetsForExerciseProvider =
    Provider<Future<int> Function(int exerciseId)>((ref) {
  final db = ref.watch(databaseProvider);
  return (int exerciseId) => db.deleteTodaySetsForExercise(exerciseId);
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
