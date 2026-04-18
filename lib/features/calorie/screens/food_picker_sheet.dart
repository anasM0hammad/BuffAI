import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/food_types.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/database/app_database.dart';
import '../../../data/providers/food_logs_provider.dart';
import '../../../data/providers/foods_provider.dart';
import 'custom_food_sheet.dart';
import 'portion_sheet.dart';

/// Full-height sheet that lets the user pick a food to log. Shows:
///   - a search bar at the top,
///   - a "Recents" horizontal strip (most-recently logged foods),
///   - a scrollable alphabetical list filtered by the search,
///   - an inline "Add custom food" CTA when the query has no match.
///
/// Popping with `true` means a food was logged downstream.
class FoodPickerSheet extends ConsumerStatefulWidget {
  const FoodPickerSheet({super.key});

  @override
  ConsumerState<FoodPickerSheet> createState() => _FoodPickerSheetState();
}

class _FoodPickerSheetState extends ConsumerState<FoodPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openPortion(Food food) async {
    final logged = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PortionSheet.log(food: food),
    );
    if (logged == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _openAddCustom() async {
    final newId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomFoodSheet(initialName: _query.trim()),
    );
    if (newId == null || !mounted) return;

    // Jump straight into the portion sheet for the food just added.
    final food = await ref.read(foodByIdProvider(newId).future);
    if (food != null && mounted) {
      await _openPortion(food);
    }
  }

  @override
  Widget build(BuildContext context) {
    final foodsAsync = ref.watch(allFoodsProvider);
    final recentIdsAsync = ref.watch(recentFoodIdsProvider);
    final viewInsets = MediaQuery.of(context).viewInsets;
    final maxH = MediaQuery.of(context).size.height * 0.92;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxH),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Pick a food',
                        style: AppTypography.sectionHeader,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _openAddCustom,
                      icon: const Icon(Icons.add_rounded,
                          color: AppColors.primaryRed, size: 18),
                      label: Text(
                        'Add food',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primaryRed,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _SearchField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Expanded(
                child: foodsAsync.when(
                  data: (allFoods) {
                    final query = _query.trim().toLowerCase();
                    final filtered = query.isEmpty
                        ? allFoods
                        : allFoods
                            .where((f) => f.name.toLowerCase().contains(query))
                            .toList();
                    return _PickerBody(
                      query: query,
                      filtered: filtered,
                      allFoods: allFoods,
                      recentIds:
                          recentIdsAsync.valueOrNull ?? const <int>[],
                      onTapFood: _openPortion,
                      onAddCustom: _openAddCustom,
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryRed,
                    ),
                  ),
                  error: (err, _) => Center(
                    child: Text(
                      'Failed to load foods.\n$err',
                      textAlign: TextAlign.center,
                      style: AppTypography.body
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded,
              color: AppColors.textTertiary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: AppTypography.body
                  .copyWith(fontWeight: FontWeight.w500),
              cursorColor: AppColors.primaryRed,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Search food',
                hintStyle: AppTypography.body.copyWith(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            InkResponse(
              onTap: () {
                controller.clear();
                onChanged('');
              },
              radius: 16,
              child: const Icon(Icons.close_rounded,
                  color: AppColors.textTertiary, size: 18),
            ),
        ],
      ),
    );
  }
}

class _PickerBody extends StatelessWidget {
  final String query;
  final List<Food> filtered;
  final List<Food> allFoods;
  final List<int> recentIds;
  final ValueChanged<Food> onTapFood;
  final VoidCallback onAddCustom;

  const _PickerBody({
    required this.query,
    required this.filtered,
    required this.allFoods,
    required this.recentIds,
    required this.onTapFood,
    required this.onAddCustom,
  });

  @override
  Widget build(BuildContext context) {
    // Nothing in the library at all — warm empty state that nudges toward
    // adding a custom food.
    if (allFoods.isEmpty) {
      return _LibraryEmpty(onAddCustom: onAddCustom);
    }

    // Search yielded nothing — offer to add a custom food using the query
    // as a seed name.
    if (filtered.isEmpty) {
      return _NoMatch(query: query, onAddCustom: onAddCustom);
    }

    final byId = {for (final f in allFoods) f.id: f};
    final recents = <Food>[];
    for (final id in recentIds) {
      final f = byId[id];
      if (f != null) recents.add(f);
    }

    return ListView(
      padding: const EdgeInsets.only(top: 14, bottom: 20),
      children: [
        if (query.isEmpty && recents.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Recent',
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: recents.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _RecentChip(
                food: recents[i],
                onTap: () => onTapFood(recents[i]),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'All foods',
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
        ...filtered.map(
          (f) => _FoodRow(food: f, onTap: () => onTapFood(f)),
        ),
      ],
    );
  }
}

class _LibraryEmpty extends StatelessWidget {
  final VoidCallback onAddCustom;
  const _LibraryEmpty({required this.onAddCustom});

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
              'Your food library is empty.\n'
              'Add a food with its calories and protein so you can log portions of it.',
              textAlign: TextAlign.center,
              style: AppTypography.body
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onAddCustom,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                'Add a food',
                style: AppTypography.buttonText,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: AppColors.textPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoMatch extends StatelessWidget {
  final String query;
  final VoidCallback onAddCustom;
  const _NoMatch({required this.query, required this.onAddCustom});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              query.isEmpty
                  ? 'No foods found.'
                  : 'No match for "$query".',
              style: AppTypography.body
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onAddCustom,
              icon: const Icon(Icons.add_rounded,
                  color: AppColors.primaryRed, size: 18),
              label: Text(
                query.isEmpty ? 'Add a food' : 'Add "$query"',
                style: AppTypography.body.copyWith(
                  color: AppColors.primaryRed,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentChip extends StatelessWidget {
  final Food food;
  final VoidCallback onTap;
  const _RecentChip({required this.food, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.divider, width: 1),
        ),
        child: Text(
          food.name,
          style: AppTypography.caption.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _FoodRow extends StatelessWidget {
  final Food food;
  final VoidCallback onTap;
  const _FoodRow({required this.food, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final unit = FoodUnit.fromDb(food.baseUnit);
    final amount = food.baseAmount == food.baseAmount.roundToDouble()
        ? food.baseAmount.toInt().toString()
        : food.baseAmount.toStringAsFixed(1);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          food.name,
                          style: AppTypography.body
                              .copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (food.isCustom) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Custom',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.primaryRed,
                              fontWeight: FontWeight.w700,
                              fontSize: 9,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'per $amount ${unit.shortLabel}  ·  ${food.proteinG.toStringAsFixed(1)}g protein',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${food.kcal}',
              style: AppTypography.cardTitle.copyWith(
                color: AppColors.primaryRed,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              'kcal',
              style: AppTypography.caption
                  .copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
