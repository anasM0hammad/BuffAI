import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import 'database_provider.dart';

/// A single day's aggregated water intake (midnight-based).
class DailyWaterTotal {
  final DateTime day;
  final int totalMl;

  const DailyWaterTotal(this.day, this.totalMl);
}

/// Start of day `N` days ago (N=0 is today).
DateTime _daysAgo(int n) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day).subtract(Duration(days: n));
}

/// All water logs from the last 7 days, newest first.
final last7DaysWaterLogsProvider = StreamProvider<List<WaterLog>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchWaterLogsSince(_daysAgo(6));
});

/// Daily totals for the last 7 days, oldest first. Missing days are
/// filled with zero so the graph has one point per day.
final last7DaysWaterTotalsProvider = Provider<List<DailyWaterTotal>>((ref) {
  final logsAsync = ref.watch(last7DaysWaterLogsProvider);
  final logs = logsAsync.value ?? const [];

  final buckets = <String, int>{};
  for (final l in logs) {
    final d = DateTime(l.loggedAt.year, l.loggedAt.month, l.loggedAt.day);
    final key = '${d.year}-${d.month}-${d.day}';
    buckets[key] = (buckets[key] ?? 0) + l.amountMl;
  }

  return List.generate(7, (i) {
    // i=0 is six days ago, i=6 is today — left-to-right chronological.
    final d = _daysAgo(6 - i);
    final key = '${d.year}-${d.month}-${d.day}';
    return DailyWaterTotal(d, buckets[key] ?? 0);
  });
});

/// Every workout set from the last 30 days, newest first. 30 days keeps
/// the history tab fast while still covering a typical training block.
final recentWorkoutSetsProvider = StreamProvider<List<WorkoutSet>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchSetsSince(_daysAgo(30));
});

/// Workout sets grouped by calendar day, newest first.
class WorkoutDay {
  final DateTime day;
  final List<WorkoutSet> sets;
  const WorkoutDay(this.day, this.sets);
}

final recentWorkoutDaysProvider = Provider<List<WorkoutDay>>((ref) {
  final setsAsync = ref.watch(recentWorkoutSetsProvider);
  final sets = setsAsync.value ?? const [];
  final byDay = <String, List<WorkoutSet>>{};
  final dayKeys = <String, DateTime>{};
  for (final s in sets) {
    final d = DateTime(s.loggedAt.year, s.loggedAt.month, s.loggedAt.day);
    final key = '${d.year}-${d.month}-${d.day}';
    byDay.putIfAbsent(key, () => []).add(s);
    dayKeys[key] = d;
  }
  final days = dayKeys.values.toList()
    ..sort((a, b) => b.compareTo(a)); // newest first
  return [
    for (final d in days)
      WorkoutDay(
        d,
        byDay['${d.year}-${d.month}-${d.day}']!
          ..sort((a, b) {
            final t = a.loggedAt.compareTo(b.loggedAt);
            if (t != 0) return t;
            return a.setNumber.compareTo(b.setNumber);
          }),
      ),
  ];
});
