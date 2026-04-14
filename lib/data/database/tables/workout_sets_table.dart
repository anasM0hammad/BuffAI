import 'package:drift/drift.dart';
import 'exercises_table.dart';

class WorkoutSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get exerciseId => integer().references(Exercises, #id)();

  /// For weight+reps and weight+time exercises. 0 for exercises that don't
  /// use weight (e.g. plank) to avoid migration churn.
  RealColumn get weight => real().withDefault(const Constant(0))();

  /// Rep count for rep-based exercises. 0 for time / distance exercises.
  IntColumn get reps => integer().withDefault(const Constant(0))();

  /// Optional duration in seconds. Used for time / weight+time / distance+time.
  IntColumn get durationSec => integer().nullable()();

  /// Optional distance in meters. Used for distance+time.
  RealColumn get distanceM => real().nullable()();

  /// Optional added weight (on top of bodyweight) for `reps_bodyweight`
  /// variants like weighted pull-ups or dips.
  RealColumn get addedWeight => real().nullable()();

  /// If this set is a drop after another set, this points at that parent.
  /// Null for standalone / main sets.
  IntColumn get parentSetId => integer().nullable()();

  /// True if this set is part of a drop-set series (either a parent with
  /// drops or one of the drops itself). Kept separate from parentSetId so
  /// the parent row carries the flag without extra queries.
  BoolColumn get isDropSet => boolean().withDefault(const Constant(false))();

  /// User flag: this set included partial / half reps to failure.
  BoolColumn get isHalfReps => boolean().withDefault(const Constant(false))();

  IntColumn get setNumber => integer()();
  DateTimeColumn get loggedAt => dateTime()();
}
