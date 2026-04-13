import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/database/app_database.dart';
import '../../../data/providers/exercises_provider.dart';
import '../../../data/providers/workout_sets_provider.dart';
import '../../../shared/widgets/buff_button.dart';
import '../widgets/weight_rep_input.dart';

class LogSetSheet extends ConsumerStatefulWidget {
  final int exerciseId;

  /// If provided, the sheet opens in edit mode for this existing set.
  final WorkoutSet? existingSet;

  const LogSetSheet({
    super.key,
    required this.exerciseId,
    this.existingSet,
  });

  bool get isEditing => existingSet != null;

  @override
  ConsumerState<LogSetSheet> createState() => _LogSetSheetState();
}

class _LogSetSheetState extends ConsumerState<LogSetSheet> {
  final _weightController = TextEditingController();
  final _repsController = TextEditingController();
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  void _prefill() {
    if (_initialized) return;
    _initialized = true;

    // Edit mode: fill from the existing set
    if (widget.isEditing) {
      _weightController.text = formatWeightValue(widget.existingSet!.weight);
      _repsController.text = '${widget.existingSet!.reps}';
      return;
    }

    // Log mode: auto-fill from most recent set
    final recentSetAsync = ref.read(mostRecentSetProvider(widget.exerciseId));
    recentSetAsync.whenData((set) {
      if (set != null) {
        _weightController.text = formatWeightValue(set.weight);
        _repsController.text = '${set.reps}';
      }
    });
  }

  void _copyLastSet() {
    final todaySets = ref
            .read(todaySetsForExerciseProvider(widget.exerciseId))
            .valueOrNull ??
        [];
    if (todaySets.isNotEmpty) {
      final last = todaySets.last;
      _weightController.text = formatWeightValue(last.weight);
      _repsController.text = '${last.reps}';
    }
  }

  Future<void> _save() async {
    final weightText = _weightController.text.trim();
    final repsText = _repsController.text.trim();
    final weight = double.tryParse(weightText);
    final reps = int.tryParse(repsText);

    if (weight == null || reps == null || weight < 0 || reps <= 0) return;

    setState(() => _saving = true);

    if (widget.isEditing) {
      final existing = widget.existingSet!;
      final updateSet = ref.read(updateSetProvider);
      await updateSet(
        id: existing.id,
        exerciseId: existing.exerciseId,
        weight: weight,
        reps: reps,
        setNumber: existing.setNumber,
        loggedAt: existing.loggedAt,
      );
    } else {
      final todaySets = ref
              .read(todaySetsForExerciseProvider(widget.exerciseId))
              .valueOrNull ??
          [];
      final setNumber = todaySets.length + 1;

      final logSet = ref.read(logSetProvider);
      await logSet(
        exerciseId: widget.exerciseId,
        weight: weight,
        reps: reps,
        setNumber: setNumber,
      );
    }

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exerciseAsync = ref.watch(exerciseByIdProvider(widget.exerciseId));
    final lastSessionAsync =
        ref.watch(lastSessionSetsProvider(widget.exerciseId));
    final todaySetsAsync =
        ref.watch(todaySetsForExerciseProvider(widget.exerciseId));

    _prefill();

    final viewInsets = MediaQuery.of(context).viewInsets;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textTertiary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Exercise name
                exerciseAsync.when(
                  data: (exercise) => Text(
                    exercise.name,
                    style: AppTypography.sectionHeader,
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 8),

                // Last session summary (hidden in edit mode to reduce clutter)
                if (!widget.isEditing)
                  lastSessionAsync.when(
                    data: (lastSets) {
                      if (lastSets.isEmpty) return const SizedBox.shrink();
                      final summary = lastSets
                          .map((s) => formatSetSummary(s.weight, s.reps))
                          .join('  |  ');
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Last: $summary',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textTertiary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                if (!widget.isEditing) const SizedBox(height: 20),

                // Set number label + copy button (or just label in edit mode)
                widget.isEditing
                    ? Row(
                        children: [
                          Text(
                            'Editing Set ${widget.existingSet!.setNumber}',
                            style: AppTypography.cardTitle.copyWith(
                              color: AppColors.primaryRed,
                            ),
                          ),
                        ],
                      )
                    : todaySetsAsync.when(
                        data: (todaySets) => Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Set ${todaySets.length + 1}',
                              style: AppTypography.cardTitle.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (todaySets.isNotEmpty)
                              GestureDetector(
                                onTap: _copyLastSet,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySoft,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Copy last set',
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.primaryRed,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                const SizedBox(height: 12),

                // Weight + reps inputs
                WeightRepInput(
                  weightController: _weightController,
                  repsController: _repsController,
                ),
                const SizedBox(height: 24),

                // Save / Update button
                BuffButton(
                  label: widget.isEditing ? 'Update Set' : 'Save Set',
                  onPressed: _save,
                  isLoading: _saving,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
