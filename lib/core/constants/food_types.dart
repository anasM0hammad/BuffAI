/// Broad classification used to color-code search results and organise
/// the curated library. Stored in the DB as the enum `name`.
enum FoodCategory {
  protein('Protein'),
  grains('Grains'),
  dairy('Dairy'),
  fruits('Fruits'),
  vegetables('Vegetables'),
  legumes('Legumes'),
  nuts('Nuts & seeds'),
  snacks('Snacks'),
  beverages('Beverages'),
  preparedDishes('Prepared'),
  condiments('Condiments'),
  fats('Fats & oils');

  const FoodCategory(this.label);
  final String label;

  static FoodCategory fromDb(String value) {
    return FoodCategory.values.firstWhere(
      (c) => c.name == value,
      orElse: () => FoodCategory.preparedDishes,
    );
  }
}

/// Portion units we support. Each food has one — users scale by a
/// multiplier expressed in that unit.
enum FoodUnit {
  g('g', 'grams'),
  ml('ml', 'millilitres'),
  piece('pc', 'pieces'),
  serving('sv', 'servings');

  const FoodUnit(this.shortLabel, this.longLabel);
  final String shortLabel;
  final String longLabel;

  /// Whether the user should type a fractional amount. Grams/ml allow
  /// decimals; pieces / servings are typically whole (but we still allow
  /// 0.5 for half items).
  bool get allowsFraction => true;

  static FoodUnit fromDb(String value) {
    return FoodUnit.values.firstWhere(
      (u) => u.name == value,
      orElse: () => FoodUnit.g,
    );
  }
}
