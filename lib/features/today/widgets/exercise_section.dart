import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/muscle_groups.dart';
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

    // Today's volume: sum of weight x reps across logged sets.
    final totalVolume = sets.fold<double>(
      0,
      (sum, s) => sum + s.weight * s.reps,
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thin accent stripe at the top for a touch of color.
          Container(
            height: 2,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryRed, AppColors.primaryDeep],
              ),
            ),
          ),

          // Exercise header: name + muscle group chip, actions on the right.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: exerciseAsync.when(
                    data: (exercise) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exercise.name,
                          style: AppTypography.cardTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            _MuscleChip(
                              label: MuscleGroup.fromString(
                                      exercise.muscleGroup)
                                  .displayName,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '${sets.length} set${sets.length == 1 ? '' : 's'}  •  ${formatWeight(totalVolume)}',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    loading: () => const SizedBox(height: 34),
                    error: (_, __) => Text(
                      'Unknown Exercise',
                      style: AppTypography.cardTitle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _AddSetButton(onTap: onTapLog),
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
              return InkWell(
                onTap: onTapHistory,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.history_rounded,
                        size: 14,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Last: $summary',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textTertiary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: AppColors.textTertiary,
                      ),
                    ],
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

    // Capture callables + messenger BEFORE the delete, because this card may
    // be unmounted once its last set is removed (ref/context become stale).
    final snapshot = List<WorkoutSet>.from(sets);
    final deleteTodaySets = ref.read(deleteTodaySetsForExerciseProvider);
    final logSet = ref.read(logSetProvider);
    final messenger = ScaffoldMessenger.of(context);

    await deleteTodaySets(exerciseId);

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
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
    // Capture callables + messenger BEFORE the delete; when the last set is
    // swiped away the card unmounts and ref/context become stale.
    final deleteSet = ref.read(deleteSetProvider);
    final logSet = ref.read(logSetProvider);
    final messenger = ScaffoldMessenger.of(context);

    deleteSet(set.id);

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
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

class _MuscleChip extends StatelessWidget {
  final String label;
  const _MuscleChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 10.5,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _AddSetButton extends StatelessWidget {
  final VoidCallback? onTap;
  const _AddSetButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primaryRed, AppColors.primaryDeep],
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryRed.withOpacity(0.28),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, color: Colors.white, size: 14),
            const SizedBox(width: 2),
            Text(
              'Set',
              style: AppTypography.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
