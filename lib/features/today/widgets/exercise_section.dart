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
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  tooltip: '',
                  color: AppColors.surfaceElevated,
                  padding: EdgeInsets.zero,
                  splashRadius: 18,
                  onSelected: (value) {
                    if (value == 'delete_today') {
                      _confirmDeleteTodaySets(ref, context);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem<String>(
                      value: 'delete_today',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.delete_outline,
                            color: AppColors.primaryRed,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Delete today's sets",
                            style: AppTypography.body.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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

  Future<void> _confirmDeleteTodaySets(
      WidgetRef ref, BuildContext context) async {
    if (sets.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text(
          "Delete today's sets?",
          style: AppTypography.cardTitle,
        ),
        content: Text(
          'This removes all ${sets.length} set${sets.length == 1 ? '' : 's'} logged for this exercise today.',
          style: AppTypography.body
              .copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Cancel',
              style:
                  AppTypography.body.copyWith(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Delete',
              style:
                  AppTypography.body.copyWith(color: AppColors.primaryRed),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final snapshot = List<WorkoutSet>.from(sets);
    final deleteTodaySets = ref.read(deleteTodaySetsForExerciseProvider);
    await deleteTodaySets(exerciseId);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Today's sets deleted",
          style: AppTypography.body.copyWith(color: AppColors.textPrimary),
        ),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Undo',
          textColor: AppColors.primaryRed,
          onPressed: () {
            final logSet = ref.read(logSetProvider);
            for (final set in snapshot) {
              logSet(
                exerciseId: set.exerciseId,
                weight: set.weight,
                reps: set.reps,
                setNumber: set.setNumber,
              );
            }
          },
        ),
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
