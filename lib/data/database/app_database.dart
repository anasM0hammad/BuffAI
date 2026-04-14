import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../core/constants/default_exercises.dart';
import 'tables/exercises_table.dart';
import 'tables/workout_sets_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Exercises, WorkoutSets])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _seedDefaultExercises();
        },
      );

  Future<void> _seedDefaultExercises() async {
    for (final exercise in defaultExercises) {
      await into(exercises).insert(
        ExercisesCompanion.insert(
          name: exercise.name,
          muscleGroup: exercise.muscleGroup.name,
        ),
      );
    }
  }

  // ── Exercise Queries ──

  Future<List<Exercise>> getAllExercises() => select(exercises).get();

  Stream<List<Exercise>> watchAllExercises() => select(exercises).watch();

  Stream<List<Exercise>> watchExercisesByGroup(String group) {
    return (select(exercises)..where((e) => e.muscleGroup.equals(group)))
        .watch();
  }

  Future<Exercise> getExerciseById(int id) {
    return (select(exercises)..where((e) => e.id.equals(id))).getSingle();
  }

  Future<int> insertExercise(ExercisesCompanion entry) {
    return into(exercises).insert(entry);
  }

  Future<bool> updateExercise(ExercisesCompanion entry) {
    return update(exercises).replace(entry);
  }

  /// Deletes an exercise along with every set that referenced it. Wrapped in
  /// a transaction so we never leave orphan sets on failure.
  Future<int> deleteExercise(int id) async {
    return transaction(() async {
      await (delete(workoutSets)..where((s) => s.exerciseId.equals(id))).go();
      return (delete(exercises)..where((e) => e.id.equals(id))).go();
    });
  }

  // ── Workout Set Queries ──

  Future<int> insertWorkoutSet(WorkoutSetsCompanion entry) {
    return into(workoutSets).insert(entry);
  }

  Future<bool> updateWorkoutSet(WorkoutSetsCompanion entry) {
    return update(workoutSets).replace(entry);
  }

  Future<int> deleteWorkoutSet(int id) {
    return (delete(workoutSets)..where((s) => s.id.equals(id))).go();
  }

  /// Delete all of today's sets for a specific exercise.
  Future<int> deleteTodaySetsForExercise(int exerciseId) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    return (delete(workoutSets)
          ..where((s) =>
              s.exerciseId.equals(exerciseId) &
              s.loggedAt.isBetweenValues(todayStart, todayEnd)))
        .go();
  }

  /// Get all sets logged today, ordered by time logged so callers can derive
  /// "order of first appearance" grouping.
  Stream<List<WorkoutSet>> watchTodaySets() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    return (select(workoutSets)
          ..where(
              (s) => s.loggedAt.isBetweenValues(todayStart, todayEnd))
          ..orderBy([
            (s) => OrderingTerm(expression: s.loggedAt),
            (s) => OrderingTerm(expression: s.setNumber),
          ]))
        .watch();
  }

  /// Get today's sets for a specific exercise.
  Future<List<WorkoutSet>> getTodaySetsForExercise(int exerciseId) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    return (select(workoutSets)
          ..where((s) =>
              s.exerciseId.equals(exerciseId) &
              s.loggedAt.isBetweenValues(todayStart, todayEnd))
          ..orderBy([(s) => OrderingTerm(expression: s.setNumber)]))
        .get();
  }

  /// Get the most recent session's sets for an exercise (excluding today).
  Future<List<WorkoutSet>> getLastSessionSets(int exerciseId) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    // Find the most recent set before today
    final lastSet = await (select(workoutSets)
          ..where((s) =>
              s.exerciseId.equals(exerciseId) &
              s.loggedAt.isSmallerThanValue(todayStart))
          ..orderBy([(s) => OrderingTerm.desc(s.loggedAt)])
          ..limit(1))
        .getSingleOrNull();

    if (lastSet == null) return [];

    // Get the start/end of that day
    final sessionDate = DateTime(
      lastSet.loggedAt.year,
      lastSet.loggedAt.month,
      lastSet.loggedAt.day,
    );
    final sessionEnd = sessionDate.add(const Duration(days: 1));

    return (select(workoutSets)
          ..where((s) =>
              s.exerciseId.equals(exerciseId) &
              s.loggedAt.isBetweenValues(sessionDate, sessionEnd))
          ..orderBy([(s) => OrderingTerm(expression: s.setNumber)]))
        .get();
  }

  /// Get all sessions for an exercise, grouped by date, newest first.
  Future<List<WorkoutSet>> getAllSetsForExercise(int exerciseId) {
    return (select(workoutSets)
          ..where((s) => s.exerciseId.equals(exerciseId))
          ..orderBy([
            (s) => OrderingTerm.desc(s.loggedAt),
            (s) => OrderingTerm(expression: s.setNumber),
          ]))
        .get();
  }

  /// Get the most recent set for an exercise (for auto-fill).
  Future<WorkoutSet?> getMostRecentSet(int exerciseId) {
    return (select(workoutSets)
          ..where((s) => s.exerciseId.equals(exerciseId))
          ..orderBy([(s) => OrderingTerm.desc(s.loggedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Watch the personal record (heaviest single set) for every exercise that
  /// has at least one logged set. Emits whenever any set changes. Ties on
  /// weight are broken by reps descending, then loggedAt descending so the
  /// most impressive recent set wins.
  Stream<Map<int, WorkoutSet>> watchPersonalRecords() {
    return select(workoutSets).watch().map((sets) {
      final records = <int, WorkoutSet>{};
      for (final set in sets) {
        final current = records[set.exerciseId];
        if (current == null || _isBetterPr(set, current)) {
          records[set.exerciseId] = set;
        }
      }
      return records;
    });
  }

  static bool _isBetterPr(WorkoutSet candidate, WorkoutSet current) {
    if (candidate.weight != current.weight) {
      return candidate.weight > current.weight;
    }
    if (candidate.reps != current.reps) {
      return candidate.reps > current.reps;
    }
    return candidate.loggedAt.isAfter(current.loggedAt);
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'BuffAI.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
