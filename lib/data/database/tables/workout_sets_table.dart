import 'package:drift/drift.dart';
import 'exercises_table.dart';

class WorkoutSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  RealColumn get weight => real()();
  IntColumn get reps => integer()();
  IntColumn get setNumber => integer()();
  DateTimeColumn get loggedAt => dateTime()();
}
