import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/food_types.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/database/app_database.dart';
import '../../../data/providers/calorie_goal_provider.dart';
import '../../../data/providers/food_logs_provider.dart';
import '../../../shared/widgets/empty_state.dart';
import 'calorie_goal_sheet.dart';
import 'calorie_history_screen.dart';
import 'food_picker_sheet.dart';
import 'portion_sheet.dart';

/// Calorie tab. Top card shows today's progress against the kcal + protein
/// goals. Body lists every food logged today — tap to edit the portion,
/// swipe to delete. Primary CTA opens the food picker. AppBar actions let
/// the user edit goals (flag) or open history (clock).
class CalorieScreen extends ConsumerWidget {
  const CalorieScreen({super.key});

  Future<void> _openPicker(BuildContext context) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FoodPickerSheet(),
    );
  }

  Future<void> _openEdit(BuildContext context, FoodLog log) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PortionSheet.edit(existingLog: log),
    );
  }

  Future<void> _openGoals(BuildContext context) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CalorieGoalSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(todayFoodLogsProvider);
    final intake = ref.watch(todayIntakeProvider);
    final goal = ref.watch(calorieGoalProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        automaticallyImplyLeading: false,
        title: Text('Calories', style: AppTypography.sectionHeader),
        actions: [
          IconButton(
            tooltip: 'Daily goals',
            icon: const Icon(Icons.flag_outlined,
                color: AppColors.textSecondary),
            onPressed: () => _openGoals(context),
          ),
          IconButton(
            tooltip: 'Calorie history',
            icon: const Icon(Icons.history_rounded,
                color: AppColors.textSecondary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CalorieHistoryScreen(),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  formatDate(DateTime.now()),
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textTertiary),
                ),
              ),
            ),
            _ProgressCard(intake: intake, goal: goal),
            const SizedBox(height: 8),
            Expanded(
              child: logsAsync.when(
                data: (logs) {
                  if (logs.isEmpty) {
                    return const EmptyState(
                      message:
                          'Nothing logged today.\nTap the button below to add a food.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final log = logs[i];
                      return _FoodLogTile(
                        log: log,
                        onTap: () => _openEdit(context, log),
                        onDelete: () async {
                          final delete = ref.read(deleteFoodLogProvider);
                          await delete(log.id);
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryRed,
                  ),
                ),
                error: (err, _) => EmptyState(
                  message: 'Something went wrong.\n$err',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                height: 56,
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openPicker(context),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: Text('Log Food', style: AppTypography.buttonText),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: AppColors.textPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Progress card ─────────────────────────────────────────────────────

/// Compact two-column readout — calories on the left, protein on the
/// right — each showing `current / goal unit`. No progress bar and no
/// surplus/deficit pill here; that level of detail lives in history.
class _ProgressCard extends StatelessWidget {
  final DailyIntake intake;
  final CalorieGoal goal;

  const _ProgressCard({required this.intake, required this.goal});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider, width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: _StatCell(
                label: 'Calories',
                current: '${intake.kcal}',
                goal: '${goal.kcal}',
                unit: 'kcal',
                accent: AppColors.primaryRed,
              ),
            ),
            Container(width: 1, height: 40, color: AppColors.divider),
            Expanded(
              child: _StatCell(
                label: 'Protein',
                current: _formatProtein(intake.proteinG),
                goal: _formatProtein(goal.proteinG),
                unit: 'g',
                accent: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatProtein(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String current;
  final String goal;
  final String unit;
  final Color accent;

  const _StatCell({
    required this.label,
    required this.current,
    required this.goal,
    required this.unit,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.caption.copyWith(
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              current,
              style: AppTypography.heroNumber.copyWith(
                color: accent,
                fontSize: 24,
                letterSpacing: -0.4,
                height: 1.0,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              '/ $goal $unit',
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Single logged entry ───────────────────────────────────────────────

class _FoodLogTile extends StatelessWidget {
  final FoodLog log;
  final VoidCallback onTap;
  final Future<void> Function() onDelete;

  const _FoodLogTile({
    required this.log,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final unit = FoodUnit.fromDb(log.portionUnit);
    return Dismissible(
      key: ValueKey('foodlog_${log.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.primaryDeep,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline,
            color: Colors.white, size: 22),
      ),
      confirmDismiss: (_) async {
        await onDelete();
        return true;
      },
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider, width: 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.foodName,
                      style: AppTypography.body
                          .copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _MetaChip(
                          text:
                              '${_formatAmount(log.portionAmount)} ${unit.shortLabel}',
                        ),
                        const SizedBox(width: 6),
                        _MetaChip(
                          text:
                              '${log.proteinG.toStringAsFixed(1)}g protein',
                          emphasis: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${log.kcal}',
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
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount == amount.roundToDouble()) return amount.toInt().toString();
    return amount.toStringAsFixed(1);
  }
}

/// Small pill-shaped meta tag used under each log entry. `emphasis`
/// bumps protein so it stands out alongside the amount chip instead of
/// fading into the grey secondary-text band.
class _MetaChip extends StatelessWidget {
  final String text;
  final bool emphasis;
  const _MetaChip({required this.text, this.emphasis = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: emphasis
            ? AppColors.primarySoft
            : AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          color: emphasis ? AppColors.primaryRed : AppColors.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}
