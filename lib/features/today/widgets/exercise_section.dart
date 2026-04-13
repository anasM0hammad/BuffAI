import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/database/app_database.dart';
import '../../../data/providers/exercises_provider.dart';
import '../../../data/providers/workout_sets_provider.dart';
import 'set_row.dart';

class ExerciseSection extends ConsumerWidget {
  final int exerciseId;
  final List<WorkoutSet> sets;
  final VoidCallback? onTapHistory;
  final VoidCallback? onTapLog;
  final ValueChanged<WorkoutSet>? onTapSet;

  const ExerciseSection({
    super.key,
    required this.exerciseId,
    required this.sets,
    this.onTapHistory,
    this.onTapLog,
    this.onTapSet,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exerciseAsync = ref.watch(exerciseByIdProvider(exerciseId));
    final lastSessionAsync = ref.watch(lastSessionSetsProvider(exerciseId));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exercise name header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: exerciseAsync.when(
                    data: (exercise) => Text(
                      exercise.name,
                      style: AppTypography.cardTitle,
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => Text(
                      'Unknown Exercise',
                      style: AppTypography.cardTitle,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onTapLog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '+ Set',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primaryRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Last session summary (tappable for history)
          lastSessionAsync.when(
            data: (lastSets) {
              if (lastSets.isEmpty) return const SizedBox.shrink();
              final summary = lastSets
                  .map((s) => formatSetSummary(s.weight, s.reps))
                  .join(', ');
              return GestureDetector(
                onTap: onTapHistory,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'Last session: $summary',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Divider
          const Divider(height: 1, indent: 16, endIndent: 16),

          // Set rows
          ...sets.map(
            (set) => SetRow(
              workoutSet: set,
              onDismissed: () => _deleteSet(ref, context, set),
              onTap: onTapSet == null ? null : () => onTapSet!(set),
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _deleteSet(WidgetRef ref, BuildContext context, WorkoutSet set) {
    final deleteSet = ref.read(deleteSetProvider);
    deleteSet(set.id);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Set deleted',
          style: AppTypography.body.copyWith(color: AppColors.textPrimary),
        ),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Undo',
          textColor: AppColors.primaryRed,
          onPressed: () {
            final logSet = ref.read(logSetProvider);
            logSet(
              exerciseId: set.exerciseId,
              weight: set.weight,
              reps: set.reps,
              setNumber: set.setNumber,
            );
          },
        ),
      ),
    );
  }
}
