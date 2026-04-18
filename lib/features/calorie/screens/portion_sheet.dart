import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/food_types.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/database/app_database.dart';
import '../../../data/providers/calorie_goal_provider.dart';
import '../../../data/providers/food_logs_provider.dart';
import '../../../data/providers/foods_provider.dart';
import '../../../shared/widgets/buff_button.dart';

/// Bottom sheet for recording a portion of a food.
///
/// Two modes:
///   • [PortionSheet.log] — user just picked a food; default the amount
///     to the food's base portion and show live kcal/protein as they
///     scale up or down.
///   • [PortionSheet.edit] — user tapped an existing log entry; amount
///     is prefilled from the log, and saving calls `updateFoodLog`.
class PortionSheet extends ConsumerStatefulWidget {
  final Food? food;
  final FoodLog? existingLog;

  const PortionSheet._({this.food, this.existingLog});

  factory PortionSheet.log({required Food food}) =>
      PortionSheet._(food: food);

  factory PortionSheet.edit({required FoodLog existingLog}) =>
      PortionSheet._(existingLog: existingLog);

  bool get isEditing => existingLog != null;

  @override
  ConsumerState<PortionSheet> createState() => _PortionSheetState();
}

class _PortionSheetState extends ConsumerState<PortionSheet> {
  final _amountController = TextEditingController();

  /// Source food for edit mode; resolved async when the sheet opens.
  Food? _resolvedFood;
  bool _foodMissing = false;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final f = widget.food;
    if (f != null) {
      _resolvedFood = f;
      _amountController.text = _formatAmount(f.baseAmount);
    } else {
      final log = widget.existingLog!;
      _amountController.text = _formatAmount(log.portionAmount);
      // Try to reattach the source food so the preview can update live.
      if (log.foodId != null) {
        Future.microtask(() async {
          final food = await ref.read(foodByIdProvider(log.foodId!).future);
          if (!mounted) return;
          setState(() {
            _resolvedFood = food;
            _foodMissing = food == null;
          });
        });
      } else {
        _foodMissing = true;
      }
    }
    _amountController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double? get _amount {
    final text = _amountController.text.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  /// For log mode + edit mode where the source food is still present,
  /// re-scale from the base food. For edit mode where the source is
  /// gone, scale the saved snapshot relative to its original portion.
  ({int kcal, double proteinG})? _computed() {
    final amount = _amount;
    if (amount == null || amount <= 0) return null;

    final food = _resolvedFood;
    if (food != null) {
      final factor = amount / food.baseAmount;
      return (
        kcal: (food.kcal * factor).round(),
        proteinG: food.proteinG * factor,
      );
    }

    final log = widget.existingLog;
    if (log != null && log.portionAmount > 0) {
      final factor = amount / log.portionAmount;
      return (
        kcal: (log.kcal * factor).round(),
        proteinG: log.proteinG * factor,
      );
    }

    return null;
  }

  Future<void> _save() async {
    final amount = _amount;
    final computed = _computed();
    if (amount == null || amount <= 0 || computed == null || _saving) {
      return;
    }

    setState(() => _saving = true);

    if (widget.isEditing) {
      final update = ref.read(updateFoodLogProvider);
      await update(
        id: widget.existingLog!.id,
        portionAmount: amount,
        kcal: computed.kcal,
        proteinG: computed.proteinG,
      );
    } else {
      final food = widget.food!;
      final goal = ref.read(calorieGoalProvider);
      final add = ref.read(addFoodLogProvider);
      await add(
        foodId: food.id,
        foodName: food.name,
        portionAmount: amount,
        portionUnit: food.baseUnit,
        kcal: computed.kcal,
        proteinG: computed.proteinG,
        kcalTarget: goal.kcal,
        proteinTargetG: goal.proteinG,
      );
    }

    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _deleteLog() async {
    final log = widget.existingLog;
    if (log == null) return;
    final delete = ref.read(deleteFoodLogProvider);
    await delete(log.id);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;

    // Name + unit come from whichever source is available. Even in edit
    // mode with the food gone, the log has a name snapshot + unit.
    final name = widget.food?.name ?? widget.existingLog?.foodName ?? '';
    final unitKey = widget.food?.baseUnit ??
        widget.existingLog?.portionUnit ??
        FoodUnit.g.name;
    final unit = FoodUnit.fromDb(unitKey);

    final computed = _computed();

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
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
                const SizedBox(height: 16),
                Text(
                  widget.isEditing ? 'Edit portion' : 'Log portion',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(name, style: AppTypography.sectionHeader),
                if (_foodMissing && widget.isEditing) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Source food was removed. Scaling from the saved portion.',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textTertiary),
                  ),
                ],
                const SizedBox(height: 18),
                _AmountField(
                  controller: _amountController,
                  unit: unit,
                ),
                const SizedBox(height: 16),
                _PreviewCard(
                  kcal: computed?.kcal ?? 0,
                  proteinG: computed?.proteinG ?? 0,
                  valid: computed != null,
                ),
                const SizedBox(height: 22),
                BuffButton(
                  label: widget.isEditing ? 'Update' : 'Save',
                  onPressed: _save,
                  isLoading: _saving,
                ),
                if (widget.isEditing) ...[
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _saving ? null : _deleteLog,
                    child: Text(
                      'Delete entry',
                      style: AppTypography.body.copyWith(
                        color: AppColors.primaryRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatAmount(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(1);
}

class _AmountField extends StatelessWidget {
  final TextEditingController controller;
  final FoodUnit unit;
  const _AmountField({required this.controller, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              textAlign: TextAlign.center,
              style: AppTypography.inputNumber,
              cursorColor: AppColors.primaryRed,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            unit.shortLabel,
            style: AppTypography.cardTitle.copyWith(
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final int kcal;
  final double proteinG;
  final bool valid;
  const _PreviewCard({
    required this.kcal,
    required this.proteinG,
    required this.valid,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: _PreviewMetric(
              label: 'Calories',
              value: valid ? '$kcal' : '—',
              unit: 'kcal',
              accent: AppColors.primaryRed,
            ),
          ),
          Container(
            width: 1,
            height: 32,
            color: AppColors.divider,
          ),
          Expanded(
            child: _PreviewMetric(
              label: 'Protein',
              value: valid
                  ? proteinG.toStringAsFixed(proteinG >= 100 ? 0 : 1)
                  : '—',
              unit: 'g',
              accent: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewMetric extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color accent;
  const _PreviewMetric({
    required this.label,
    required this.value,
    required this.unit,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: AppTypography.cardTitle.copyWith(
                color: accent,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              unit,
              style: AppTypography.caption
                  .copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
      ],
    );
  }
}
