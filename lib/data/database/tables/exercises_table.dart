import 'package:drift/drift.dart';

class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get muscleGroup => text()();

  /// How this exercise is logged. See [MeasurementType] for the enum —
  /// stored as the string dbValue (e.g. 'weight_reps', 'time').
  /// Defaults to 'weight_reps' so older rows upgrade cleanly.
  TextColumn get measurementType =>
      text().withDefault(const Constant('weight_reps'))();

  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
