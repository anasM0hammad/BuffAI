import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/food_types.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/database/app_database.dart';
import '../../../data/providers/food_logs_provider.dart';
import '../../../shared/widgets/empty_state.dart';
import 'food_picker_sheet.dart';
import 'portion_sheet.dart';

/// Calorie tab. Header shows today's running kcal + protein totals. Body
/// lists each food the user has logged today — tap to edit the portion,
/// swipe to delete. The primary CTA opens the food picker.
class CalorieScreen extends ConsumerWidget {
  const CalorieScreen({super.key});

  Future<void> _openPicker(BuildContext context) async {
    final logged = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FoodPickerSheet(),
    );
    // No follow-up action needed — the stream provider refreshes itself.
    // [logged] is just handy for future haptics / toasts.
    if (logged == true) return;
  }

  Future<void> _openEdit(BuildContext context, FoodLog log) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PortionSheet.edit(existingLog: log),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(todayFoodLogsProvider);
    final intake = ref.watch(todayIntakeProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        automaticallyImplyLeading: false,
        title: Text('Calories', style: AppTypography.sectionHeader),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _IntakeHeader(intake: intake),
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

// ── Header ────────────────────────────────────────────────────────────

class _IntakeHeader extends StatelessWidget {
  final DailyIntake intake;
  const _IntakeHeader({required this.intake});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider, width: 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: _Metric(
                label: 'Calories',
                value: '${intake.kcal}',
                unit: 'kcal',
                accent: AppColors.primaryRed,
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: AppColors.divider,
            ),
            Expanded(
              child: _Metric(
                label: 'Protein',
                value: intake.proteinG.toStringAsFixed(
                    intake.proteinG >= 100 ? 0 : 1),
                unit: 'g',
                accent: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color accent;
  const _Metric({
    required this.label,
    required this.value,
    required this.unit,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: AppTypography.heroNumber.copyWith(
                fontSize: 30,
                color: accent,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                unit,
                style: AppTypography.caption
                    .copyWith(color: AppColors.textTertiary),
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
                    const SizedBox(height: 2),
                    Text(
                      '${_formatAmount(log.portionAmount)} ${unit.shortLabel}'
                      '  ·  ${log.proteinG.toStringAsFixed(1)}g protein',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textTertiary),
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
