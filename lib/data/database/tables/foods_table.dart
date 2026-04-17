import 'package:drift/drift.dart';

/// The curated + user-custom food library. One row per distinct food.
/// Nutrition is stored per `baseAmount` of `baseUnit` — e.g. "100 g" of
/// chicken breast, "1 piece" of banana, "250 ml" of milk.
class Foods extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();

  /// `FoodCategory.name` — enum stored as its string key.
  TextColumn get category => text()();

  /// How much of `baseUnit` the kcal / protein values refer to.
  RealColumn get baseAmount => real()();

  /// `FoodUnit.name` — 'g', 'ml', 'piece', or 'serving'.
  TextColumn get baseUnit => text()();

  IntColumn get kcal => integer()();
  RealColumn get proteinG => real()();

  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
