import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import 'database_provider.dart';

/// Aggregate of calories + protein consumed in a day.
class DailyIntake {
  final int kcal;
  final double proteinG;

  const DailyIntake({required this.kcal, required this.proteinG});

  static const zero = DailyIntake(kcal: 0, proteinG: 0);
}

/// Today's food log entries, newest first.
final todayFoodLogsProvider = StreamProvider<List<FoodLog>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchTodayFoodLogs();
});

/// Today's running totals — derived from [todayFoodLogsProvider].
final todayIntakeProvider = Provider<DailyIntake>((ref) {
  final logs = ref.watch(todayFoodLogsProvider);
  return logs.when(
    data: (list) {
      var kcal = 0;
      var protein = 0.0;
      for (final l in list) {
        kcal += l.kcal;
        protein += l.proteinG;
      }
      return DailyIntake(kcal: kcal, proteinG: protein);
    },
    loading: () => DailyIntake.zero,
    error: (_, __) => DailyIntake.zero,
  );
});

/// Ids of the foods the user has logged most recently (de-duplicated).
/// Drives the "Recents" strip in the food picker.
final recentFoodIdsProvider = StreamProvider<List<int>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchRecentFoodIds();
});

/// Food logs from [since] onwards (inclusive), newest first. Used by the
/// calorie history screen to build per-day totals.
final foodLogsSinceProvider =
    StreamProvider.family<List<FoodLog>, DateTime>((ref, since) {
  final db = ref.watch(databaseProvider);
  return db.watchFoodLogsSince(since);
});

/// Log a food. `kcal` and `proteinG` are the totals for the portion the
/// user is saving, not the per-base values — the caller is responsible for
/// scaling from the source food. `kcalTarget` / `proteinTargetG` snapshot
/// the user's daily goal so history deltas don't shift when the goal is
/// later changed.
final addFoodLogProvider = Provider<
    Future<int> Function({
      required int? foodId,
      required String foodName,
      required double portionAmount,
      required String portionUnit,
      required int kcal,
      required double proteinG,
      int? kcalTarget,
      double? proteinTargetG,
      DateTime? loggedAt,
    })>((ref) {
  final db = ref.watch(databaseProvider);
  return ({
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
    return db.insertFoodLog(
      foodId: foodId,
      foodName: foodName,
      portionAmount: portionAmount,
      portionUnit: portionUnit,
      kcal: kcal,
      proteinG: proteinG,
      kcalTarget: kcalTarget,
      proteinTargetG: proteinTargetG,
      loggedAt: loggedAt,
    );
  };
});

/// Edit an existing log entry. Only portion + computed nutrition change;
/// the food link, name snapshot, unit, and timestamp are preserved.
final updateFoodLogProvider = Provider<
    Future<bool> Function({
      required int id,
      required double portionAmount,
      required int kcal,
      required double proteinG,
    })>((ref) {
  final db = ref.watch(databaseProvider);
  return ({
    required int id,
    required double portionAmount,
    required int kcal,
    required double proteinG,
  }) {
    return db.updateFoodLog(
      id: id,
      portionAmount: portionAmount,
      kcal: kcal,
      proteinG: proteinG,
    );
  };
});

final deleteFoodLogProvider =
    Provider<Future<int> Function(int id)>((ref) {
  final db = ref.watch(databaseProvider);
  return (int id) => db.deleteFoodLog(id);
});
