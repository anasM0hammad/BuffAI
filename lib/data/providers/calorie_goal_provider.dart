import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keys used in SharedPreferences to persist the user's daily intake goals.
const _kKcalGoalKey = 'calorie_daily_kcal_goal';
const _kProteinGoalKey = 'calorie_daily_protein_goal_g';

/// Sensible defaults so the UI has something to render on first launch.
const int kDefaultDailyKcalGoal = 2000;
const double kDefaultDailyProteinGoalG = 100;

/// Immutable pair of kcal + protein target.
class CalorieGoal {
  final int kcal;
  final double proteinG;

  const CalorieGoal({required this.kcal, required this.proteinG});

  static const defaults = CalorieGoal(
    kcal: kDefaultDailyKcalGoal,
    proteinG: kDefaultDailyProteinGoalG,
  );
}

/// Loads the persisted goals exactly once. The [StateNotifier] below
/// reseeds from this the first time it rebuilds after the Future resolves.
final _persistedCalorieGoalProvider = FutureProvider<CalorieGoal>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return CalorieGoal(
    kcal: prefs.getInt(_kKcalGoalKey) ?? kDefaultDailyKcalGoal,
    proteinG: prefs.getDouble(_kProteinGoalKey) ?? kDefaultDailyProteinGoalG,
  );
});

/// User's current daily kcal + protein goal. Writes are persisted.
final calorieGoalProvider =
    StateNotifierProvider<CalorieGoalNotifier, CalorieGoal>((ref) {
  final initial =
      ref.watch(_persistedCalorieGoalProvider).value ?? CalorieGoal.defaults;
  return CalorieGoalNotifier(initial);
});

class CalorieGoalNotifier extends StateNotifier<CalorieGoal> {
  CalorieGoalNotifier(super.state);

  Future<void> set({required int kcal, required double proteinG}) async {
    if (kcal < 500 || kcal > 10000) return;
    if (proteinG < 0 || proteinG > 500) return;
    state = CalorieGoal(kcal: kcal, proteinG: proteinG);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kKcalGoalKey, kcal);
    await prefs.setDouble(_kProteinGoalKey, proteinG);
  }
}
