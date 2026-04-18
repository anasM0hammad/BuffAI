import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import 'database_provider.dart';

/// Every food in the library (curated + user-custom), alphabetical.
final allFoodsProvider = StreamProvider<List<Food>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllFoods();
});

/// One food by id — used by edit sheets and the portion preview.
final foodByIdProvider = FutureProvider.family<Food?, int>((ref, id) {
  final db = ref.watch(databaseProvider);
  return db.getFoodById(id);
});

/// Save a new custom food. Returns the inserted row id.
final addCustomFoodProvider = Provider<
    Future<int> Function({
      required String name,
      required String category,
      required double baseAmount,
      required String baseUnit,
      required int kcal,
      required double proteinG,
    })>((ref) {
  final db = ref.watch(databaseProvider);
  return ({
    required String name,
    required String category,
    required double baseAmount,
    required String baseUnit,
    required int kcal,
    required double proteinG,
  }) {
    return db.insertCustomFood(
      name: name,
      category: category,
      baseAmount: baseAmount,
      baseUnit: baseUnit,
      kcal: kcal,
      proteinG: proteinG,
    );
  };
});

/// Delete a food. Any logs referencing it are orphaned (name snapshot kept).
final deleteFoodProvider =
    Provider<Future<int> Function(int id)>((ref) {
  final db = ref.watch(databaseProvider);
  return (int id) => db.deleteFood(id);
});
