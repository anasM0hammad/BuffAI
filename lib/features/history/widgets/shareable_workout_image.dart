import 'package:flutter/material.dart';

import '../../../core/constants/measurement_type.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/database/app_database.dart';
import '../../../data/providers/history_provider.dart';

/// Off-screen widget rendered to PNG for the "share workout" feature.
///
/// Designed for a fixed logical width (typically 360 dp) with unbounded
/// height so the image captures every exercise no matter how long the
/// session was. Mirrors the app's dark theme so shared images look
/// identical to the in-app UI.
class ShareableWorkoutImage extends StatelessWidget {
  final WorkoutDay day;
  final Map<int, Exercise> exerciseById;

  /// Fixed logical width of the rendered card. 360 dp matches common
  /// mobile widths and keeps the capture readable on chat previews.
  static const double width = 360;

  const ShareableWorkoutImage({
    super.key,
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
      width: width,
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Branding(),
          const SizedBox(height: 16),
          _DayHeader(
            day: day.day,
            exerciseCount: exerciseCount,
            totalSets: totalSets,
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < order.length; i++) ...[
            _ExerciseBlock(
              exercise: exerciseById[order[i]],
              sets: grouped[order[i]]!,
            ),
            if (i != order.length - 1) const SizedBox(height: 8),
          ],
          const SizedBox(height: 16),
          const _Footer(),
        ],
      ),
    );
  }
}

class _Branding extends StatelessWidget {
  const _Branding();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/images/logo.png',
            width: 36,
            height: 36,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 10),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BuffAI',
              style: AppTypography.sectionHeader.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'WORKOUT LOG',
              style: AppTypography.caption.copyWith(
                color: AppColors.primaryRed,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  final DateTime day;
  final int exerciseCount;
  final int totalSets;

  const _DayHeader({
    required this.day,
    required this.exerciseCount,
    required this.totalSets,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${day.day}',
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryRed,
                    fontSize: 16,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  _monthAbbr(day.month),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primaryRed,
                    fontSize: 9,
                    letterSpacing: 0.4,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatDate(day),
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$exerciseCount ${exerciseCount == 1 ? 'exercise' : 'exercises'} · '
                  '$totalSets ${totalSets == 1 ? 'set' : 'sets'}',
                  style: AppTypography.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
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

  const _ExerciseBlock({
    required this.exercise,
    required this.sets,
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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        height: 1.2,
                      ),
                    ),
                    if (muscle != null && muscle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        muscle,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final set in ordered)
            Padding(
              padding: EdgeInsets.fromLTRB(
                set.isDropSet ? 18 : 0,
                2,
                0,
                2,
              ),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: set.isDropSet
                          ? AppColors.primarySoft
                          : AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: set.isDropSet
                        ? const Icon(
                            Icons.south_rounded,
                            size: 11,
                            color: AppColors.primaryRed,
                          )
                        : Text(
                            '${set.setNumber}',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      formatSetMetrics(set, measurement),
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (set.isHalfReps)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppColors.primaryRed.withOpacity(0.45),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '½',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primaryRed,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                        ),
                      ),
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
          width: 4,
          height: 4,
          decoration: const BoxDecoration(
            color: AppColors.primaryRed,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'Logged with BuffAI',
          style: AppTypography.caption.copyWith(
            color: AppColors.textTertiary,
            fontSize: 10,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
