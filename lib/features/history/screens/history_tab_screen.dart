import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/measurement_type.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/database/app_database.dart';
import '../../../data/providers/exercises_provider.dart';
import '../../../data/providers/history_provider.dart';
import '../../../data/providers/water_provider.dart';

/// Weekly water chart on top, a scrollable list of workout days below.
/// Each day is an [ExpansionTile] that opens to show every exercise done
/// that day with its sets (reps / weight / time / distance as applicable).
class HistoryTabScreen extends ConsumerWidget {
  const HistoryTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(last7DaysWaterTotalsProvider);
    final target = ref.watch(dailyWaterTargetProvider);
    final days = ref.watch(recentWorkoutDaysProvider);
    final exercisesAsync = ref.watch(allExercisesProvider);
    final exercises = exercisesAsync.value ?? const <Exercise>[];
    final exerciseById = {for (final e in exercises) e.id: e};

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        title: Text('History', style: AppTypography.sectionHeader),
      ),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverToBoxAdapter(
                child: _HistorySubtitle(),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              sliver: SliverToBoxAdapter(
                child: _WaterWeekCard(totals: totals, targetMl: target),
              ),
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
              sliver: SliverToBoxAdapter(
                child: _SectionLabel('WORKOUT HISTORY'),
              ),
            ),
            if (days.isEmpty)
              const SliverToBoxAdapter(child: _EmptyWorkouts())
            else
              SliverList.builder(
                itemCount: days.length,
                itemBuilder: (context, i) {
                  final day = days[i];
                  return _WorkoutDayTile(
                    day: day,
                    exerciseById: exerciseById,
                  );
                },
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _HistorySubtitle extends StatelessWidget {
  const _HistorySubtitle();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Last 7 days of hydration and training',
      style: AppTypography.caption,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.caption.copyWith(
        color: AppColors.primaryRed,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
  }
}

/// Card that wraps the water intake line chart.
class _WaterWeekCard extends StatelessWidget {
  final List<DailyWaterTotal> totals;
  final int targetMl;

  const _WaterWeekCard({required this.totals, required this.targetMl});

  @override
  Widget build(BuildContext context) {
    final maxVal = totals.isEmpty
        ? 0
        : totals.map((t) => t.totalMl).reduce((a, b) => a > b ? a : b);
    final weekAvg = totals.isEmpty
        ? 0
        : (totals.fold<int>(0, (s, t) => s + t.totalMl) / totals.length)
            .round();
    final hitTargetDays =
        totals.where((t) => targetMl > 0 && t.totalMl >= targetMl).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.water_drop_rounded,
                  size: 16, color: AppColors.primaryRed),
              const SizedBox(width: 6),
              Text(
                'WATER · 7 DAYS',
                style: AppTypography.caption.copyWith(
                  color: AppColors.primaryRed,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              Text(
                '${hitTargetDays}/7 days on target',
                style: AppTypography.caption
                    .copyWith(color: AppColors.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: CustomPaint(
              size: Size.infinite,
              painter: _WaterChartPainter(
                totals: totals,
                targetMl: targetMl,
                maxMl: maxVal,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _StatChip(
                label: 'Avg',
                value: '${(weekAvg / 1000).toStringAsFixed(1)} L',
              ),
              const SizedBox(width: 10),
              _StatChip(
                label: 'Goal',
                value: '${(targetMl / 1000).toStringAsFixed(1)} L',
              ),
              const SizedBox(width: 10),
              _StatChip(
                label: 'Peak',
                value: maxVal == 0
                    ? '—'
                    : '${(maxVal / 1000).toStringAsFixed(1)} L',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
                letterSpacing: 0.4,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: AppTypography.body.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Polyline chart with dots for each day, a dashed target line, and a
/// soft gradient fill under the curve. Day labels (Mon / Tue / ...) sit
/// beneath the axis.
class _WaterChartPainter extends CustomPainter {
  final List<DailyWaterTotal> totals;
  final int targetMl;
  final int maxMl;

  _WaterChartPainter({
    required this.totals,
    required this.targetMl,
    required this.maxMl,
  });

  static const _weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void paint(Canvas canvas, Size size) {
    if (totals.isEmpty) return;

    const topPad = 8.0;
    const bottomPad = 24.0;
    const leftPad = 8.0;
    const rightPad = 8.0;

    final chartTop = topPad;
    final chartBottom = size.height - bottomPad;
    final chartLeft = leftPad;
    final chartRight = size.width - rightPad;
    final chartW = chartRight - chartLeft;
    final chartH = chartBottom - chartTop;

    // Axis ceiling: target plus a little headroom, or the peak.
    final ceiling = [
      targetMl.toDouble(),
      maxMl.toDouble(),
      1000.0,
    ].reduce((a, b) => a > b ? a : b) *
        1.15;

    double yFor(int ml) {
      final clamped = ml.clamp(0, ceiling.toInt()).toDouble();
      return chartBottom - (clamped / ceiling) * chartH;
    }

    double xFor(int i) {
      if (totals.length == 1) return chartLeft + chartW / 2;
      return chartLeft + (i / (totals.length - 1)) * chartW;
    }

    // Target dashed line.
    if (targetMl > 0) {
      final y = yFor(targetMl);
      final dashPaint = Paint()
        ..color = AppColors.primaryRed.withOpacity(0.45)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      double x = chartLeft;
      while (x < chartRight) {
        canvas.drawLine(
          Offset(x, y),
          Offset((x + 6).clamp(chartLeft, chartRight), y),
          dashPaint,
        );
        x += 10;
      }
      final tp = _textPainter(
        'GOAL',
        AppColors.primaryRed.withOpacity(0.65),
        fontSize: 9,
        weight: FontWeight.w700,
      );
      tp.paint(canvas, Offset(chartLeft, y - tp.height - 1));
    }

    // Build the line path.
    final linePath = Path();
    final fillPath = Path();
    for (int i = 0; i < totals.length; i++) {
      final p = Offset(xFor(i), yFor(totals[i].totalMl));
      if (i == 0) {
        linePath.moveTo(p.dx, p.dy);
        fillPath.moveTo(p.dx, chartBottom);
        fillPath.lineTo(p.dx, p.dy);
      } else {
        linePath.lineTo(p.dx, p.dy);
        fillPath.lineTo(p.dx, p.dy);
      }
    }
    fillPath.lineTo(xFor(totals.length - 1), chartBottom);
    fillPath.close();

    // Gradient fill under the line.
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.primaryRed.withOpacity(0.35),
          AppColors.primaryRed.withOpacity(0.02),
        ],
      ).createShader(Rect.fromLTWH(0, chartTop, size.width, chartH));
    canvas.drawPath(fillPath, fillPaint);

    // The line itself.
    final linePaint = Paint()
      ..color = AppColors.primaryRed
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, linePaint);

    // Data points.
    for (int i = 0; i < totals.length; i++) {
      final p = Offset(xFor(i), yFor(totals[i].totalMl));
      final hit = targetMl > 0 && totals[i].totalMl >= targetMl;
      final fill = Paint()
        ..color = hit ? AppColors.primaryRed : AppColors.background
        ..style = PaintingStyle.fill;
      final border = Paint()
        ..color = AppColors.primaryRed
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(p, 4, fill);
      canvas.drawCircle(p, 4, border);
    }

    // Day labels.
    for (int i = 0; i < totals.length; i++) {
      final d = totals[i].day;
      // Dart's DateTime.weekday: Mon=1 .. Sun=7
      final label = _weekdayShort[d.weekday - 1];
      final isToday = _isSameDay(d, DateTime.now());
      final tp = _textPainter(
        label,
        isToday ? AppColors.primaryRed : AppColors.textTertiary,
        fontSize: 10,
        weight: isToday ? FontWeight.w700 : FontWeight.w500,
      );
      tp.paint(
        canvas,
        Offset(xFor(i) - tp.width / 2, chartBottom + 6),
      );
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  TextPainter _textPainter(
    String text,
    Color color, {
    double fontSize = 10,
    FontWeight weight = FontWeight.w500,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    return tp;
  }

  @override
  bool shouldRepaint(covariant _WaterChartPainter old) {
    return old.totals != totals ||
        old.targetMl != targetMl ||
        old.maxMl != maxMl;
  }
}

class _EmptyWorkouts extends StatelessWidget {
  const _EmptyWorkouts();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.fitness_center_rounded,
                color: AppColors.textTertiary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No workouts yet',
                  style: AppTypography.body
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'Logged sessions from the last 30 days will appear here.',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One expandable row per workout day. Collapsed: date + quick stats.
/// Expanded: every exercise done that day, grouped with its sets.
class _WorkoutDayTile extends StatelessWidget {
  final WorkoutDay day;
  final Map<int, Exercise> exerciseById;

  const _WorkoutDayTile({
    required this.day,
    required this.exerciseById,
  });

  @override
  Widget build(BuildContext context) {
    // Preserve order-of-first-appearance for exercises that day.
    final order = <int>[];
    final grouped = <int, List<WorkoutSet>>{};
    for (final s in day.sets) {
      if (!grouped.containsKey(s.exerciseId)) {
        order.add(s.exerciseId);
      }
      grouped.putIfAbsent(s.exerciseId, () => []).add(s);
    }

    final totalSets = day.sets.where((s) => s.parentSetId == null).length;
    final exerciseCount = order.length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Theme(
          // ExpansionTile inherits the Material theme's dividerColor and
          // draws a default separator we don't want.
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
                        '$exerciseCount ${exerciseCount == 1 ? 'exercise' : 'exercises'} · '
                        '$totalSets ${totalSets == 1 ? 'set' : 'sets'}',
                        style: AppTypography.caption,
                      ),
                      if (order.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _MuscleGroupChips(
                          groups: [
                            for (final id in order)
                              exerciseById[id]?.muscleGroup ?? 'Other',
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            children: [
              for (int i = 0; i < order.length; i++)
                _ExerciseBlock(
                  exercise: exerciseById[order[i]],
                  sets: grouped[order[i]]!,
                  isLast: i == order.length - 1,
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

class _ExerciseBlock extends StatelessWidget {
  final Exercise? exercise;
  final List<WorkoutSet> sets;
  final bool isLast;

  const _ExerciseBlock({
    required this.exercise,
    required this.sets,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final measurement = exercise == null
        ? MeasurementType.weightReps
        : MeasurementType.fromString(exercise!.measurementType);
    final name = exercise?.name ?? 'Exercise';
    final muscle = exercise?.muscleGroup;

    final ordered = [...sets]..sort((a, b) {
        final n = a.setNumber.compareTo(b.setNumber);
        if (n != 0) return n;
        final dropOrder =
            (a.isDropSet ? 1 : 0).compareTo(b.isDropSet ? 1 : 0);
        if (dropOrder != 0) return dropOrder;
        return a.id.compareTo(b.id);
      });

    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTypography.body
                          .copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (muscle != null && muscle.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        muscle,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...ordered.map(
            (set) => Padding(
              padding: EdgeInsets.fromLTRB(
                  set.isDropSet ? 20 : 0, 4, 0, 4),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: set.isDropSet
                          ? AppColors.primarySoft
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: set.isDropSet
                        ? const Icon(Icons.south_rounded,
                            size: 12, color: AppColors.primaryRed)
                        : Text(
                            '${set.setNumber}',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      formatSetMetrics(set, measurement),
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (set.isHalfReps)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: AppColors.primaryRed.withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.front_hand_outlined,
                        size: 11,
                        color: AppColors.primaryRed,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal strip of small muscle-group pill chips shown in the
/// collapsed workout-day tile. Order is preserved and duplicates are
/// kept intentionally so the user can see "3 chest, 1 back" at a
/// glance without expanding.
class _MuscleGroupChips extends StatelessWidget {
  final List<String> groups;
  const _MuscleGroupChips({required this.groups});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final g in groups) _MuscleChip(label: g),
      ],
    );
  }
}

class _MuscleChip extends StatelessWidget {
  final String label;
  const _MuscleChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: AppColors.primaryRed.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: AppColors.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
