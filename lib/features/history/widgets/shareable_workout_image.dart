import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/measurement_type.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/database/app_database.dart';
import '../../../data/providers/history_provider.dart';

/// Off-screen widget rendered to PNG for the "share workout" feature.
///
/// Dense, minimal layout: one row per exercise with all sets on the
/// same row (wrapping if there are many). Keeps a 5-exercise session
/// to roughly a 6:5 aspect ratio — no per-card borders, no wasted
/// vertical padding. Dark theme with red accents for brand recognition.
class ShareableWorkoutImage extends StatelessWidget {
  final WorkoutDay day;
  final Map<int, Exercise> exerciseById;

  static const double width = 380;

  const ShareableWorkoutImage({
    super.key,
    required this.day,
    required this.exerciseById,
  });

  @override
  Widget build(BuildContext context) {
    final order = <int>[];
    final grouped = <int, List<WorkoutSet>>{};
    for (final s in day.sets) {
      if (!grouped.containsKey(s.exerciseId)) {
        order.add(s.exerciseId);
      }
      grouped.putIfAbsent(s.exerciseId, () => []).add(s);
    }

    final totalSets = day.sets.where((s) => s.parentSetId == null).length;

    return Container(
      width: width,
      color: AppColors.background,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Header(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: _SessionMeta(
              day: day.day,
              exerciseCount: order.length,
              totalSets: totalSets,
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 10, 20, 4),
            child: _AccentRule(),
          ),
          for (int i = 0; i < order.length; i++)
            _ExerciseRow(
              index: i + 1,
              exercise: exerciseById[order[i]],
              sets: grouped[order[i]]!,
            ),
          const SizedBox(height: 12),
          const _Footer(),
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.primaryRed, width: 2),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset(
              'assets/images/logo.png',
              width: 28,
              height: 28,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'BuffAI',
            style: AppTypography.sectionHeader.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              height: 1.0,
            ),
          ),
          const Spacer(),
          Text(
            'WORKOUT',
            style: AppTypography.caption.copyWith(
              color: AppColors.primaryRed,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionMeta extends StatelessWidget {
  final DateTime day;
  final int exerciseCount;
  final int totalSets;

  const _SessionMeta({
    required this.day,
    required this.exerciseCount,
    required this.totalSets,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEE, MMM d').format(day).toUpperCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          dateStr,
          style: AppTypography.body.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: AppColors.textPrimary,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$exerciseCount ${exerciseCount == 1 ? 'exercise' : 'exercises'}  ·  '
          '$totalSets ${totalSets == 1 ? 'set' : 'sets'}',
          style: AppTypography.caption.copyWith(
            fontSize: 11,
            color: AppColors.textSecondary,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

class _AccentRule extends StatelessWidget {
  const _AccentRule();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 24, height: 2, color: AppColors.primaryRed),
        const SizedBox(width: 4),
        Expanded(
          child: Container(height: 1, color: AppColors.divider),
        ),
      ],
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  final int index;
  final Exercise? exercise;
  final List<WorkoutSet> sets;

  const _ExerciseRow({
    required this.index,
    required this.exercise,
    required this.sets,
  });

  @override
  Widget build(BuildContext context) {
    final measurement = exercise == null
        ? MeasurementType.weightReps
        : MeasurementType.fromString(exercise!.measurementType);
    final name = (exercise?.name ?? 'Exercise').toUpperCase();
    final muscle = exercise?.muscleGroup;

    final ordered = [...sets]..sort((a, b) {
        final n = a.setNumber.compareTo(b.setNumber);
        if (n != 0) return n;
        final d = (a.isDropSet ? 1 : 0).compareTo(b.isDropSet ? 1 : 0);
        if (d != 0) return d;
        return a.id.compareTo(b.id);
      });

    // Group each working set with its drop sets so a working set and
    // all of its drops render inside the same bordered pill.
    final groups = <List<WorkoutSet>>[];
    final groupByParentId = <int, List<WorkoutSet>>{};
    for (final s in ordered) {
      if (s.parentSetId == null) {
        final group = <WorkoutSet>[s];
        groups.add(group);
        groupByParentId[s.id] = group;
      } else {
        final parent = groupByParentId[s.parentSetId];
        if (parent != null) {
          parent.add(s);
        } else {
          // Orphan drop set (shouldn't happen, but don't lose data).
          groups.add([s]);
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Text(
              index.toString().padLeft(2, '0'),
              style: AppTypography.body.copyWith(
                color: AppColors.primaryRed,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.25,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: AppTypography.body.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          height: 1.2,
                        ),
                      ),
                    ),
                    if (muscle != null && muscle.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        muscle.toUpperCase(),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: [
                    for (final group in groups)
                      _SetPill(group: group, measurement: measurement),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 3,
          height: 3,
          decoration: const BoxDecoration(
            color: AppColors.primaryRed,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'LOGGED WITH BUFFAI',
          style: AppTypography.caption.copyWith(
            color: AppColors.textTertiary,
            fontSize: 9,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 3,
          height: 3,
          decoration: const BoxDecoration(
            color: AppColors.primaryRed,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

/// A working set plus any drop sets that followed it, drawn as a small
/// red-bordered pill. For a plain working set it's just the single
/// metric. For a drop-set series it shows the chain inline separated
/// by a down-arrow — `60×8 ↓ 40×5 ↓ 25×3`.
class _SetPill extends StatelessWidget {
  final List<WorkoutSet> group;
  final MeasurementType measurement;

  const _SetPill({required this.group, required this.measurement});

  @override
  Widget build(BuildContext context) {
    final textStyle = AppTypography.body.copyWith(
      fontSize: 12,
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w600,
      height: 1.2,
    );
    final arrowStyle = textStyle.copyWith(
      color: AppColors.primaryRed,
      fontWeight: FontWeight.w700,
    );

    final children = <Widget>[];
    for (int i = 0; i < group.length; i++) {
      if (i > 0) {
        children.add(const SizedBox(width: 4));
        children.add(Text('↓', style: arrowStyle));
        children.add(const SizedBox(width: 4));
      }
      children.add(Text(_compactSet(group[i], measurement), style: textStyle));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primarySoft.withOpacity(0.35),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.primaryRed.withOpacity(0.55),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: children,
      ),
    );
  }
}

String _compactSet(WorkoutSet s, MeasurementType t) {
  String base;
  switch (t) {
    case MeasurementType.weightReps:
      base = '${_num(s.weight)}×${s.reps}';
      break;
    case MeasurementType.repsBodyweight:
      final added = s.addedWeight ?? 0;
      base = added > 0 ? '${s.reps}+${_num(added)}kg' : '${s.reps}';
      break;
    case MeasurementType.time:
      base = formatDurationLabel(s.durationSec ?? 0);
      break;
    case MeasurementType.weightTime:
      final w = s.weight > 0 ? '${_num(s.weight)}kg · ' : '';
      base = '$w${formatDurationLabel(s.durationSec ?? 0)}';
      break;
    case MeasurementType.distanceTime:
      base =
          '${_dist(s.distanceM ?? 0)} · ${formatDurationLabel(s.durationSec ?? 0)}';
      break;
  }
  if (s.isHalfReps) base = '$base½';
  return base;
}

String _num(double v) =>
    v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1);

String _dist(double m) => m >= 1000
    ? '${(m / 1000).toStringAsFixed(m % 1000 == 0 ? 0 : 1)}km'
    : '${m.toInt()}m';
