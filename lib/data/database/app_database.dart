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

  Future<int> deleteExercise(int id) {
    return (delete(exercises)..where((e) => e.id.equals(id))).go();
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

  /// Get all sets logged today, ordered by exercise then set number.
  Stream<List<WorkoutSet>> watchTodaySets() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    return (select(workoutSets)
          ..where(
              (s) => s.loggedAt.isBetweenValues(todayStart, todayEnd))
          ..orderBy([
            (s) => OrderingTerm(expression: s.exerciseId),
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
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'BuffAI.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
