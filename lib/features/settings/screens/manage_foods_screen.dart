import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/food_types.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/database/app_database.dart';
import '../../../data/providers/foods_provider.dart';
import '../../calorie/screens/custom_food_sheet.dart';

/// Library management for user-created custom foods. Mirrors
/// [ManageExercisesScreen]: curated foods are read-only and don't surface
/// edit/delete actions; custom foods can be edited or removed from here.
/// Past log entries keep their snapshotted name + macros so deleting a
/// food never rewrites history.
class ManageFoodsScreen extends ConsumerWidget {
  const ManageFoodsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foodsAsync = ref.watch(allFoodsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Manage Foods', style: AppTypography.cardTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: foodsAsync.when(
        data: (foods) {
          if (foods.isEmpty) {
            return const _EmptyLibrary();
          }
          final grouped = <FoodCategory, List<Food>>{};
          for (final f in foods) {
            grouped
                .putIfAbsent(FoodCategory.fromDb(f.category), () => [])
                .add(f);
          }
          final groups = grouped.keys.toList()
            ..sort((a, b) => a.label.compareTo(b.label));

          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: groups.expand((group) {
              final items = grouped[group]!;
              return [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    group.label,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                ...items.map((food) => _FoodTile(food: food)),
              ];
            }).toList(),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryRed),
        ),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryRed,
        onPressed: () => _openFoodSheet(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

Future<void> _openFoodSheet(BuildContext context, {Food? existing}) async {
  await showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CustomFoodSheet(existingFood: existing),
  );
}

class _FoodTile extends ConsumerWidget {
  final Food food;
  const _FoodTile({required this.food});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = FoodUnit.fromDb(food.baseUnit);
    final amount = food.baseAmount == food.baseAmount.roundToDouble()
        ? food.baseAmount.toInt().toString()
        : food.baseAmount.toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        title: Row(
          children: [
            Flexible(
              child: Text(
                food.name,
                style: AppTypography.body,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (food.isCustom) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Custom',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primaryRed,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            'per $amount ${unit.shortLabel}  ·  ${food.kcal} kcal  ·  '
            '${food.proteinG.toStringAsFixed(1)}g protein',
            style: AppTypography.caption
                .copyWith(color: AppColors.textTertiary, fontSize: 11),
          ),
        ),
        trailing: food.isCustom
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        color: AppColors.textSecondary, size: 20),
                    tooltip: 'Edit',
                    onPressed: () =>
                        _openFoodSheet(context, existing: food),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: AppColors.textSecondary, size: 20),
                    tooltip: 'Delete',
                    onPressed: () => _confirmDelete(context, ref),
                  ),
                ],
              )
            : null,
        dense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text('Delete food?', style: AppTypography.cardTitle),
        content: Text(
          'This removes "${food.name}" from your library. Past log entries '
          'that referenced it stay intact.',
          style:
              AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: AppTypography.body
                    .copyWith(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style:
                  AppTypography.body.copyWith(color: AppColors.primaryRed),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(deleteFoodProvider)(food.id);
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.restaurant_menu_rounded,
                color: AppColors.textTertiary, size: 52),
            const SizedBox(height: 14),
            Text(
              'No foods yet.\nTap + to add your first one.',
              textAlign: TextAlign.center,
              style: AppTypography.body
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
