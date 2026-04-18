import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/food_types.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/database/app_database.dart';
import '../../../data/providers/food_logs_provider.dart';

/// Per-day calorie + protein history. Each day is an [ExpansionTile] with
/// the day's totals on the header and every logged entry inside when
/// expanded. Shows the last ~90 days.
class CalorieHistoryScreen extends ConsumerWidget {
  const CalorieHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final since = DateTime.now().subtract(const Duration(days: 90));
    final logsAsync = ref.watch(foodLogsSinceProvider(
      DateTime(since.year, since.month, since.day),
    ));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        title: Text('Calorie history', style: AppTypography.sectionHeader),
      ),
      body: SafeArea(
        top: false,
        child: logsAsync.when(
          data: (logs) {
            if (logs.isEmpty) return const _EmptyHistory();
            final days = _groupByDay(logs);
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: days.length,
              itemBuilder: (_, i) => _CalorieDayTile(day: days[i]),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primaryRed),
          ),
          error: (err, _) => Center(
            child: Text(
              'Failed to load history.\n$err',
              textAlign: TextAlign.center,
              style: AppTypography.body
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }

  List<_CalorieDay> _groupByDay(List<FoodLog> logs) {
    final buckets = <DateTime, List<FoodLog>>{};
    final order = <DateTime>[];
    for (final l in logs) {
      final d = DateTime(l.loggedAt.year, l.loggedAt.month, l.loggedAt.day);
      if (!buckets.containsKey(d)) order.add(d);
      buckets.putIfAbsent(d, () => []).add(l);
    }
    return [
      for (final d in order) _CalorieDay(day: d, entries: buckets[d]!),
    ];
  }
}

class _CalorieDay {
  final DateTime day;
  final List<FoodLog> entries;
  _CalorieDay({required this.day, required this.entries});

  int get totalKcal => entries.fold(0, (sum, l) => sum + l.kcal);
  double get totalProteinG =>
      entries.fold(0.0, (sum, l) => sum + l.proteinG);
}

class _CalorieDayTile extends StatelessWidget {
  final _CalorieDay day;
  const _CalorieDayTile({required this.day});

  @override
  Widget build(BuildContext context) {
    final entries = [...day.entries]
      ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            iconColor: AppColors.textSecondary,
            collapsedIconColor: AppColors.textTertiary,
            title: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${day.day.day}',
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryRed,
                          fontSize: 15,
                          height: 1.05,
                        ),
                      ),
                      Text(
                        _monthAbbr(day.day.month),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primaryRed,
                          fontSize: 9,
                          letterSpacing: 0.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatDate(day.day),
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${day.entries.length} '
                        '${day.entries.length == 1 ? 'entry' : 'entries'}',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${day.totalKcal}',
                          style: AppTypography.cardTitle.copyWith(
                            color: AppColors.primaryRed,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'kcal',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${day.totalProteinG.toStringAsFixed(day.totalProteinG >= 100 ? 0 : 1)}g protein',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            children: [
              for (int i = 0; i < entries.length; i++)
                _EntryRow(
                  log: entries[i],
                  isLast: i == entries.length - 1,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _monthAbbr(int m) {
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
    ];
    return months[m - 1];
  }
}

class _EntryRow extends StatelessWidget {
  final FoodLog log;
  final bool isLast;
  const _EntryRow({required this.log, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final unit = FoodUnit.fromDb(log.portionUnit);
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
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
          const SizedBox(width: 10),
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
    );
  }

  String _formatAmount(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

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
              'No calorie history yet.\n'
              'Logged foods from the last 90 days will appear here.',
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
