import 'package:drift/drift.dart';

import 'foods_table.dart';

/// One row per "I ate this" entry. We intentionally snapshot the food's
/// name and computed nutrition at log time so editing or deleting a food
/// later doesn't silently rewrite history.
class FoodLogs extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Reference back to the source food, if it still exists. Nullable so
  /// deleting a custom food doesn't orphan the log.
  IntColumn get foodId => integer().nullable().references(Foods, #id)();

  /// Snapshotted name for display (in case `foodId` is gone).
  TextColumn get foodName => text()();

  /// How much the user logged, in `portionUnit`. e.g. 2 (pieces), 150 (g).
  RealColumn get portionAmount => real()();

  /// Snapshot of the food's base unit at log time.
  TextColumn get portionUnit => text()();

  /// Pre-computed totals for this log entry.
  IntColumn get kcal => integer()();
  RealColumn get proteinG => real()();

  /// Snapshot of the user's daily calorie + protein goals at the moment
  /// this entry was logged. History displays deltas against these
  /// snapshots so changing the goal today doesn't retroactively rewrite
  /// past days. Nullable for rows written before goals were introduced.
  IntColumn get kcalTarget => integer().nullable()();
  RealColumn get proteinTargetG => real().nullable()();

  DateTimeColumn get loggedAt => dateTime()();
}
