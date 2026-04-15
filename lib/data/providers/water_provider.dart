import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';
import 'database_provider.dart';

/// Key used in SharedPreferences to persist the user's daily target.
const _kWaterTargetKey = 'water_daily_target_ml';

/// Sensible default target when the user hasn't picked one yet.
const int kDefaultDailyWaterTargetMl = 2500;

/// Today's water log entries (newest first).
final todayWaterLogsProvider = StreamProvider<List<WaterLog>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchTodayWaterLogs();
});

/// Total millilitres drunk today. Derived from the stream above.
final todayWaterTotalMlProvider = Provider<int>((ref) {
  final logs = ref.watch(todayWaterLogsProvider);
  return logs.when(
    data: (list) => list.fold<int>(0, (sum, l) => sum + l.amountMl),
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Async provider that loads the persisted daily target once at startup.
final _persistedWaterTargetProvider = FutureProvider<int>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt(_kWaterTargetKey) ?? kDefaultDailyWaterTargetMl;
});

/// User's daily target in millilitres. Writes are persisted.
final dailyWaterTargetProvider =
    StateNotifierProvider<DailyWaterTarget, int>((ref) {
  final initial = ref.watch(_persistedWaterTargetProvider).value ??
      kDefaultDailyWaterTargetMl;
  return DailyWaterTarget(initial);
});

class DailyWaterTarget extends StateNotifier<int> {
  DailyWaterTarget(super.state);

  Future<void> set(int ml) async {
    if (ml < 250 || ml > 10000) return;
    state = ml;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kWaterTargetKey, ml);
  }
}

/// Add a new water log entry.
final addWaterLogProvider =
    Provider<Future<int> Function(int amountMl)>((ref) {
  final db = ref.watch(databaseProvider);
  return (int amountMl) => db.insertWaterLog(amountMl);
});

/// Delete a water log entry.
final deleteWaterLogProvider =
    Provider<Future<int> Function(int id)>((ref) {
  final db = ref.watch(databaseProvider);
  return (int id) => db.deleteWaterLog(id);
});
