import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../core/constants/default_exercises.dart';
import 'tables/exercises_table.dart';
import 'tables/water_logs_table.dart';
import 'tables/workout_sets_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Exercises, WorkoutSets, WaterLogs])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _seedDefaultExercises();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            // Add new columns introduced in v2.
            await m.addColumn(exercises, exercises.measurementType);
            await m.addColumn(workoutSets, workoutSets.durationSec);
            await m.addColumn(workoutSets, workoutSets.distanceM);
            await m.addColumn(workoutSets, workoutSets.addedWeight);
            await m.addColumn(workoutSets, workoutSets.parentSetId);
            await m.addColumn(workoutSets, workoutSets.isDropSet);
            await m.addColumn(workoutSets, workoutSets.isHalfReps);

            // Backfill: seed any new defaults the user doesn't already
            // have, and repair measurement types on existing defaults.
            await _seedMissingDefaults();
            await _backfillMeasurementTypes();
          }
          if (from < 3) {
            // v3 introduces the water-intake log.
            await m.createTable(waterLogs);
          }
        },
      );

  Future<void> _seedDefaultExercises() async {
    for (final exercise in defaultExercises) {
      await into(exercises).insert(
        ExercisesCompanion.insert(
          name: exercise.name,
          muscleGroup: exercise.muscleGroup.name,
          measurementType: Value(exercise.measurementType.dbValue),
        ),
      );
    }
  }

  /// Insert any default exercises that the user doesn't already have
  /// (matched by name). Used on upgrade to bring older installs up to the
  /// current curated library without duplicating existing rows.
  Future<void> _seedMissingDefaults() async {
    final existing = await select(exercises).get();
    final existingNames = existing.map((e) => e.name.toLowerCase()).toSet();

    for (final exercise in defaultExercises) {
      if (existingNames.contains(exercise.name.toLowerCase())) continue;
      await into(exercises).insert(
        ExercisesCompanion.insert(
          name: exercise.name,
          muscleGroup: exercise.muscleGroup.name,
          measurementType: Value(exercise.measurementType.dbValue),
        ),
      );
    }
  }

  /// For each built-in exercise name, align the stored measurement type
  /// with the curated value. User customs are left alone.
  Future<void> _backfillMeasurementTypes() async {
    final byName = {
      for (final d in defaultExercises) d.name.toLowerCase(): d,
    };
    final all = await select(exercises).get();
    for (final row in all) {
      if (row.isCustom) continue;
      final match = byName[row.name.toLowerCase()];
      if (match == null) continue;
      if (row.measurementType == match.measurementType.dbValue) continue;
      await (update(exercises)..where((e) => e.id.equals(row.id))).write(
        ExercisesCompanion(
          measurementType: Value(match.measurementType.dbValue),
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

  /// Watch the personal-record set for every exercise. PR semantics depend
  /// on measurement type: max weight for loaded work, max duration for
  /// timed work, max distance for cardio. Emits whenever sets change.
  ///
  /// Drops (sets with a non-null parentSetId) are excluded — we measure
  /// PRs against clean working sets only.
  Stream<Map<int, WorkoutSet>> watchPersonalRecords() {
    return select(workoutSets).watch().map((sets) {
      final records = <int, WorkoutSet>{};
      for (final set in sets) {
        if (set.parentSetId != null) continue;
        final current = records[set.exerciseId];
        if (current == null || _isBetterPr(set, current)) {
          records[set.exerciseId] = set;
        }
      }
      return records;
    });
  }

  // ── Water Log Queries ──

  /// Watch today's water entries, newest first.
  Stream<List<WaterLog>> watchTodayWaterLogs() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    return (select(waterLogs)
          ..where((l) => l.loggedAt.isBetweenValues(todayStart, todayEnd))
          ..orderBy([(l) => OrderingTerm.desc(l.loggedAt)]))
        .watch();
  }

  Future<int> insertWaterLog(int amountMl) {
    return into(waterLogs).insert(
      WaterLogsCompanion.insert(
        amountMl: amountMl,
        loggedAt: DateTime.now(),
      ),
    );
  }

  Future<int> deleteWaterLog(int id) {
    return (delete(waterLogs)..where((l) => l.id.equals(id))).go();
  }

  static bool _isBetterPr(WorkoutSet candidate, WorkoutSet current) {
    // Distance-based (e.g. rowing): prefer longer distance, then faster time.
    if (candidate.distanceM != null || current.distanceM != null) {
      final cd = candidate.distanceM ?? 0;
      final rd = current.distanceM ?? 0;
      if (cd != rd) return cd > rd;
      final ct = candidate.durationSec ?? 0;
      final rt = current.durationSec ?? 0;
      if (ct != rt) return ct < rt; // faster = better at same distance
      return candidate.loggedAt.isAfter(current.loggedAt);
    }

    // Weight-based (with or without reps / time).
    final cw = candidate.weight + (candidate.addedWeight ?? 0);
    final rw = current.weight + (current.addedWeight ?? 0);
    if (cw != rw) return cw > rw;

    if (candidate.reps != current.reps) {
      return candidate.reps > current.reps;
    }

    // Pure time (e.g. plank): longer hold wins.
    final cdur = candidate.durationSec ?? 0;
    final rdur = current.durationSec ?? 0;
    if (cdur != rdur) return cdur > rdur;

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
