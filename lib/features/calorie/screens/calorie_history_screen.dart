import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/food_types.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/database/app_database.dart';
import '../../../data/providers/food_logs_provider.dart';

/// Per-day calorie + protein history. Each day is an [ExpansionTile]
/// showing the day's totals plus surplus/deficit computed against the
/// goals that were in effect **when the entries were logged** — not the
/// user's current goal. This means editing today's goal never
/// retroactively rewrites yesterday's verdict.
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

  /// Snapshotted goal for this day. We take the most-recent non-null
  /// snapshot so a user who changed their goal partway through the day
  /// has the later (more current) target reflected. Older logs written
  /// before snapshotting existed will return `null`.
  ({int? kcal, double? proteinG}) get snapshotGoal {
    final sorted = [...entries]..sort(
        (a, b) => b.loggedAt.compareTo(a.loggedAt),
      );
    int? kcal;
    double? protein;
    for (final e in sorted) {
      kcal ??= e.kcalTarget;
      protein ??= e.proteinTargetG;
      if (kcal != null && protein != null) break;
    }
    return (kcal: kcal, proteinG: protein);
  }
}

class _CalorieDayTile extends StatelessWidget {
  final _CalorieDay day;
  const _CalorieDayTile({required this.day});

  @override
  Widget build(BuildContext context) {
    final entries = [...day.entries]
      ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
    final snap = day.snapshotGoal;

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
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            iconColor: AppColors.textSecondary,
            collapsedIconColor: AppColors.textTertiary,
            title: _DayHeader(day: day, snap: snap),
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
}

class _DayHeader extends StatelessWidget {
  final _CalorieDay day;
  final ({int? kcal, double? proteinG}) snap;
  const _DayHeader({required this.day, required this.snap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
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
                      fontWeight: FontWeight.w700,
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
          ],
        ),
        const SizedBox(height: 12),
        _DayTotals(day: day, snap: snap),
      ],
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

/// Two-column stat block under each day: calories on the left (with its
/// surplus/deficit vs the snapshotted goal), protein on the right (with
/// remaining/over against its own snapshotted goal). The two columns
/// carry their own colour accents so neither one feels like an
/// afterthought.
class _DayTotals extends StatelessWidget {
  final _CalorieDay day;
  final ({int? kcal, double? proteinG}) snap;
  const _DayTotals({required this.day, required this.snap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatColumn(
              label: 'Calories',
              value: '${day.totalKcal}',
              goal: snap.kcal == null ? null : '${snap.kcal}',
              unit: 'kcal',
              accent: AppColors.primaryRed,
              delta: _kcalDelta(),
            ),
          ),
          Container(width: 1, height: 40, color: AppColors.divider),
          Expanded(
            child: _StatColumn(
              label: 'Protein',
              value: _formatProtein(day.totalProteinG),
              goal: snap.proteinG == null
                  ? null
                  : _formatProtein(snap.proteinG!),
              unit: 'g',
              accent: AppColors.textPrimary,
              delta: _proteinDelta(),
              proteinMode: true,
            ),
          ),
        ],
      ),
    );
  }

  _StatDelta? _kcalDelta() {
    final g = snap.kcal;
    if (g == null) return null;
    final diff = day.totalKcal - g;
    return _StatDelta(
      label: diff >= 0 ? 'Surplus' : 'Deficit',
      value: diff >= 0 ? '+$diff' : '−${diff.abs()}',
      unit: 'kcal',
      isPositive: diff >= 0,
    );
  }

  _StatDelta? _proteinDelta() {
    final g = snap.proteinG;
    if (g == null) return null;
    final diff = day.totalProteinG - g;
    // For protein, meeting/exceeding the goal is a neutral-good state
    // (no alert). Falling short shows how many grams are left.
    if (diff >= 0) {
      return _StatDelta(
        label: 'Hit',
        value: '+${_formatProtein(diff)}',
        unit: 'g',
        isPositive: true,
      );
    }
    return _StatDelta(
      label: 'Short',
      value: '−${_formatProtein(diff.abs())}',
      unit: 'g',
      isPositive: false,
    );
  }

  static String _formatProtein(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }
}

class _StatDelta {
  final String label;
  final String value;
  final String unit;
  final bool isPositive;
  const _StatDelta({
    required this.label,
    required this.value,
    required this.unit,
    required this.isPositive,
  });
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final String? goal;
  final String unit;
  final Color accent;
  final _StatDelta? delta;

  /// When true, a positive delta renders as neutral-primary rather than
  /// alert-red. Protein hitting its goal is a good thing, not a warning.
  final bool proteinMode;

  const _StatColumn({
    required this.label,
    required this.value,
    required this.goal,
    required this.unit,
    required this.accent,
    required this.delta,
    this.proteinMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.caption.copyWith(
            color: AppColors.textTertiary,
            letterSpacing: 0.5,
            fontWeight: FontWeight.w700,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: AppTypography.cardTitle.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              goal == null ? unit : '/ $goal $unit',
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (delta != null)
          _DeltaTag(delta: delta!, proteinMode: proteinMode)
        else
          Text(
            'No goal set',
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }
}

class _DeltaTag extends StatelessWidget {
  final _StatDelta delta;
  final bool proteinMode;
  const _DeltaTag({required this.delta, this.proteinMode = false});

  @override
  Widget build(BuildContext context) {
    final useAlert = delta.isPositive && !proteinMode;
    final bg = useAlert ? AppColors.primarySoft : AppColors.surface;
    final fg = useAlert ? AppColors.primaryRed : AppColors.textPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            delta.label.toUpperCase(),
            style: AppTypography.caption.copyWith(
              color: fg.withOpacity(0.7),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              fontSize: 9,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${delta.value} ${delta.unit}',
            style: AppTypography.caption.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
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
        color: AppColors.background,
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
                const SizedBox(height: 6),
                Row(
                  children: [
                    _InlineTag(
                      text:
                          '${_formatAmount(log.portionAmount)} ${unit.shortLabel}',
                    ),
                    const SizedBox(width: 6),
                    _InlineTag(
                      text:
                          '${log.proteinG.toStringAsFixed(1)}g protein',
                      emphasis: true,
                    ),
                  ],
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

class _InlineTag extends StatelessWidget {
  final String text;
  final bool emphasis;
  const _InlineTag({required this.text, this.emphasis = false});

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
