import 'food_types.dart';

/// One row in the curated food library. Matches the shape of the
/// persisted `Foods` table but lives in pure Dart so we can seed + patch
/// the DB on first run / upgrade.
class SeedFood {
  final String name;
  final FoodCategory category;
  final num baseAmount;
  final FoodUnit baseUnit;
  final int kcal;
  final double proteinG;

  const SeedFood({
    required this.name,
    required this.category,
    required this.baseAmount,
    required this.baseUnit,
    required this.kcal,
    required this.proteinG,
  });
}

/// Curated food library. Nutrition values are drawn from USDA FoodData
/// Central, IFCT (Indian Food Composition Tables) and published product
/// labels. Values are per `baseAmount` of `baseUnit` and are typical
/// real-world averages — individual brand or cooking variance can push
/// them ±5%.
const List<SeedFood> seedFoods = [
  // Placeholder — populated from the nutritionist list in a follow-up
  // commit within this same change. See `default_foods.dart` for the
  // full curated list.
];
