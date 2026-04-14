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
  return allSets.whenData((sets) {
    final filtered =
        sets.where((s) => s.exerciseId == exerciseId).toList();
    filtered.sort((a, b) {
      final n = a.setNumber.compareTo(b.setNumber);
      if (n != 0) return n;
      final dropOrder =
          (a.isDropSet ? 1 : 0).compareTo(b.isDropSet ? 1 : 0);
      if (dropOrder != 0) return dropOrder;
      return a.id.compareTo(b.id);
    });
    return filtered;
  });
});

/// Gets all sets for an exercise (for history screen).
final allSetsForExerciseProvider =
    FutureProvider.family<List<WorkoutSet>, int>((ref, exerciseId) {
  final db = ref.watch(databaseProvider);
  return db.getAllSetsForExercise(exerciseId);
});

/// Service provider for logging a new set. All metric fields are optional
/// so the same function serves every measurement type.
final logSetProvider = Provider<
    Future<int> Function({
      required int exerciseId,
      required int setNumber,
      double weight,
      int reps,
      int? durationSec,
      double? distanceM,
      double? addedWeight,
      int? parentSetId,
      bool isDropSet,
      bool isHalfReps,
    })>((ref) {
  final db = ref.watch(databaseProvider);
  return ({
    required int exerciseId,
    required int setNumber,
    double weight = 0,
    int reps = 0,
    int? durationSec,
    double? distanceM,
    double? addedWeight,
    int? parentSetId,
    bool isDropSet = false,
    bool isHalfReps = false,
  }) {
    return db.insertWorkoutSet(
      WorkoutSetsCompanion.insert(
        exerciseId: exerciseId,
        weight: Value(weight),
        reps: Value(reps),
        durationSec: Value(durationSec),
        distanceM: Value(distanceM),
        addedWeight: Value(addedWeight),
        parentSetId: Value(parentSetId),
        isDropSet: Value(isDropSet),
        isHalfReps: Value(isHalfReps),
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
      required int setNumber,
      required DateTime loggedAt,
      double weight,
      int reps,
      int? durationSec,
      double? distanceM,
      double? addedWeight,
      int? parentSetId,
      bool isDropSet,
      bool isHalfReps,
    })>((ref) {
  final db = ref.watch(databaseProvider);
  return ({
    required int id,
    required int exerciseId,
    required int setNumber,
    required DateTime loggedAt,
    double weight = 0,
    int reps = 0,
    int? durationSec,
    double? distanceM,
    double? addedWeight,
    int? parentSetId,
    bool isDropSet = false,
    bool isHalfReps = false,
  }) {
    return db.updateWorkoutSet(
      WorkoutSetsCompanion(
        id: Value(id),
        exerciseId: Value(exerciseId),
        weight: Value(weight),
        reps: Value(reps),
        durationSec: Value(durationSec),
        distanceM: Value(distanceM),
        addedWeight: Value(addedWeight),
        parentSetId: Value(parentSetId),
        isDropSet: Value(isDropSet),
        isHalfReps: Value(isHalfReps),
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

/// Watches the heaviest (PR) set per exercise across all history.
final personalRecordsProvider =
    StreamProvider<Map<int, WorkoutSet>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchPersonalRecords();
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
