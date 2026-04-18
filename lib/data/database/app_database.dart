import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../core/constants/default_exercises.dart';
import '../../core/constants/default_foods.dart';
import 'tables/exercises_table.dart';
import 'tables/food_logs_table.dart';
import 'tables/foods_table.dart';
import 'tables/water_logs_table.dart';
import 'tables/workout_sets_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Exercises, WorkoutSets, WaterLogs, Foods, FoodLogs])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _seedDefaultExercises();
          await _seedDefaultFoods();
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
          if (from < 4) {
            // v4 introduces the calorie-tracking feature.
            await m.createTable(foods);
            await m.createTable(foodLogs);
            await _seedDefaultFoods();
          } else {
            // Already on v4+. Backfill any new curated foods added to
            // the library since the last release.
            await _seedMissingFoods();
          }
          if (from < 5) {
            // v5 snapshots the user's daily kcal + protein goals onto
            // each food log entry so past-day deltas stop moving when
            // the goal is later changed.
            await m.addColumn(foodLogs, foodLogs.kcalTarget);
            await m.addColumn(foodLogs, foodLogs.proteinTargetG);
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

  /// Insert every curated food on a fresh install.
  Future<void> _seedDefaultFoods() async {
    for (final f in seedFoods) {
      await into(foods).insert(
        FoodsCompanion.insert(
          name: f.name,
          category: f.category.name,
          baseAmount: f.baseAmount.toDouble(),
          baseUnit: f.baseUnit.name,
          kcal: f.kcal,
          proteinG: f.proteinG,
        ),
      );
    }
  }

  /// Insert any default foods the user doesn't already have, matched
  /// case-insensitively by name. Used on upgrade so older installs pick
  /// up additions to the curated library without duplicating rows.
  Future<void> _seedMissingFoods() async {
    final existing = await select(foods).get();
    final existingNames = existing.map((e) => e.name.toLowerCase()).toSet();

    for (final f in seedFoods) {
      if (existingNames.contains(f.name.toLowerCase())) continue;
      await into(foods).insert(
        FoodsCompanion.insert(
          name: f.name,
          category: f.category.name,
          baseAmount: f.baseAmount.toDouble(),
          baseUnit: f.baseUnit.name,
          kcal: f.kcal,
          proteinG: f.proteinG,
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

  /// All sets logged on or after [since] (inclusive), newest first. Used
  /// by the History tab to group sessions by day.
  Stream<List<WorkoutSet>> watchSetsSince(DateTime since) {
    return (select(workoutSets)
          ..where((s) => s.loggedAt.isBiggerOrEqualValue(since))
          ..orderBy([
            (s) => OrderingTerm.desc(s.loggedAt),
            (s) => OrderingTerm(expression: s.setNumber),
          ]))
        .watch();
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

  /// Watch all water entries from [since] onwards (inclusive), newest
  /// first. Used by the History tab to build per-day totals.
  Stream<List<WaterLog>> watchWaterLogsSince(DateTime since) {
    return (select(waterLogs)
          ..where((l) => l.loggedAt.isBiggerOrEqualValue(since))
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

  // ── Food Queries ──

  Stream<List<Food>> watchAllFoods() =>
      (select(foods)..orderBy([(f) => OrderingTerm(expression: f.name)]))
          .watch();

  Future<Food?> getFoodById(int id) {
    return (select(foods)..where((f) => f.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertCustomFood({
    required String name,
    required String category,
    required double baseAmount,
    required String baseUnit,
    required int kcal,
    required double proteinG,
  }) {
    return into(foods).insert(
      FoodsCompanion.insert(
        name: name,
        category: category,
        baseAmount: baseAmount,
        baseUnit: baseUnit,
        kcal: kcal,
        proteinG: proteinG,
        isCustom: const Value(true),
      ),
    );
  }

  /// Edit a user-custom food. Existing logs keep their snapshotted
  /// name/kcal/protein values on purpose so history isn't rewritten.
  Future<bool> updateCustomFood({
    required int id,
    required String name,
    required String category,
    required double baseAmount,
    required String baseUnit,
    required int kcal,
    required double proteinG,
  }) async {
    final count = await (update(foods)..where((f) => f.id.equals(id))).write(
      FoodsCompanion(
        name: Value(name),
        category: Value(category),
        baseAmount: Value(baseAmount),
        baseUnit: Value(baseUnit),
        kcal: Value(kcal),
        proteinG: Value(proteinG),
      ),
    );
    return count > 0;
  }

  Future<int> deleteFood(int id) async {
    return transaction(() async {
      // Orphan any logs referencing this food so history survives.
      await (update(foodLogs)..where((l) => l.foodId.equals(id))).write(
        const FoodLogsCompanion(foodId: Value(null)),
      );
      return (delete(foods)..where((f) => f.id.equals(id))).go();
    });
  }

  // ── Food Log Queries ──

  /// Today's food entries, newest first.
  Stream<List<FoodLog>> watchTodayFoodLogs() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    return (select(foodLogs)
          ..where((l) => l.loggedAt.isBetweenValues(todayStart, todayEnd))
          ..orderBy([(l) => OrderingTerm.desc(l.loggedAt)]))
        .watch();
  }

  /// Food logs from [since] onwards (inclusive), newest first. Drives
  /// the calorie history screen.
  Stream<List<FoodLog>> watchFoodLogsSince(DateTime since) {
    return (select(foodLogs)
          ..where((l) => l.loggedAt.isBiggerOrEqualValue(since))
          ..orderBy([(l) => OrderingTerm.desc(l.loggedAt)]))
        .watch();
  }

  /// Recently-logged food ids, de-duplicated, newest first. Used to
  /// populate the "Recents" strip above the search bar.
  Future<List<int>> getRecentFoodIds({int limit = 8}) async {
    final now = DateTime.now();
    final since = now.subtract(const Duration(days: 14));
    final rows = await (select(foodLogs)
          ..where((l) =>
              l.loggedAt.isBiggerOrEqualValue(since) &
              l.foodId.isNotNull())
          ..orderBy([(l) => OrderingTerm.desc(l.loggedAt)]))
        .get();
    final seen = <int>{};
    final out = <int>[];
    for (final r in rows) {
      final id = r.foodId;
      if (id == null || seen.contains(id)) continue;
      seen.add(id);
      out.add(id);
      if (out.length >= limit) break;
    }
    return out;
  }

  /// Watch-able version: emits a new list every time food logs change.
  Stream<List<int>> watchRecentFoodIds({int limit = 8}) {
    final now = DateTime.now();
    final since = now.subtract(const Duration(days: 14));
    return (select(foodLogs)
          ..where((l) =>
              l.loggedAt.isBiggerOrEqualValue(since) &
              l.foodId.isNotNull())
          ..orderBy([(l) => OrderingTerm.desc(l.loggedAt)]))
        .watch()
        .map((rows) {
      final seen = <int>{};
      final out = <int>[];
      for (final r in rows) {
        final id = r.foodId;
        if (id == null || seen.contains(id)) continue;
        seen.add(id);
        out.add(id);
        if (out.length >= limit) break;
      }
      return out;
    });
  }

  Future<int> insertFoodLog({
    required int? foodId,
    required String foodName,
    required double portionAmount,
    required String portionUnit,
    required int kcal,
    required double proteinG,
    int? kcalTarget,
    double? proteinTargetG,
    DateTime? loggedAt,
  }) {
    return into(foodLogs).insert(
      FoodLogsCompanion.insert(
        foodId: Value(foodId),
        foodName: foodName,
        portionAmount: portionAmount,
        portionUnit: portionUnit,
        kcal: kcal,
        proteinG: proteinG,
        kcalTarget: Value(kcalTarget),
        proteinTargetG: Value(proteinTargetG),
        loggedAt: loggedAt ?? DateTime.now(),
      ),
    );
  }

  Future<int> deleteFoodLog(int id) {
    return (delete(foodLogs)..where((l) => l.id.equals(id))).go();
  }

  Future<bool> updateFoodLog({
    required int id,
    required double portionAmount,
    required int kcal,
    required double proteinG,
  }) async {
    final count = await (update(foodLogs)..where((l) => l.id.equals(id)))
        .write(
      FoodLogsCompanion(
        portionAmount: Value(portionAmount),
        kcal: Value(kcal),
        proteinG: Value(proteinG),
      ),
    );
    return count > 0;
  }

  // ── Bulk Reset ──

  /// Wipes every user-generated log (workout sets, water entries, food
  /// entries) and the user-created custom exercises / foods. The
  /// curated default libraries are preserved so the user can
  /// immediately resume logging. Profile data and simple app
  /// preferences are stored outside the database and are untouched by
  /// this call.
  Future<void> resetAllLoggedData() async {
    await transaction(() async {
      await delete(workoutSets).go();
      await delete(waterLogs).go();
      await delete(foodLogs).go();
      await (delete(exercises)..where((e) => e.isCustom.equals(true))).go();
      await (delete(foods)..where((f) => f.isCustom.equals(true))).go();
    });
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
