import 'package:drift/drift.dart';

/// Individual water intake entries. Each row is one "drink" the user logged,
/// so the same day can have many rows. We aggregate at query time.
class WaterLogs extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Amount drunk in millilitres.
  IntColumn get amountMl => integer()();

  /// When the drink was logged. Used to scope daily totals.
  DateTimeColumn get loggedAt => dateTime()();
}
