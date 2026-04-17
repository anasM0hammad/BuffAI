import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/database/app_database.dart';
import '../../../data/providers/workout_sets_provider.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../log_set/screens/exercise_picker_sheet.dart';
import '../../log_set/screens/log_set_sheet.dart';
import '../../history/screens/exercise_history_screen.dart';
import '../widgets/exercise_section.dart';
import '../widgets/rest_timer_bar.dart';

/// Provider for rest timer state. Holds remaining seconds or null if not active.
final restTimerActiveProvider = StateProvider<bool>((ref) => false);
final restTimerDurationProvider = StateProvider<int>((ref) => 90);

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  bool _showRestTimer = false;
  int _restTimerRestartKey = 0;

  void _openExercisePicker() async {
    final selectedExerciseId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ExercisePickerSheet(),
    );

    if (selectedExerciseId != null && mounted) {
      _openLogSet(selectedExerciseId);
    }
  }

  void _openLogSet(int exerciseId) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LogSetSheet(exerciseId: exerciseId),
    );

    if (saved == true && mounted) {
      setState(() {
        _showRestTimer = true;
        _restTimerRestartKey++;
      });
    }
  }

  void _openEditSet(WorkoutSet set) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LogSetSheet(
        exerciseId: set.exerciseId,
        existingSet: set,
      ),
    );
  }

  void _openHistory(int exerciseId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExerciseHistoryScreen(exerciseId: exerciseId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final todaySetsAsync = ref.watch(todaySetsProvider);
    final timerDuration = ref.watch(restTimerDurationProvider);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Today', style: AppTypography.sectionHeader),
                  const SizedBox(height: 2),
                  Text(
                    formatDate(DateTime.now()),
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: todaySetsAsync.when(
                data: (sets) {
                  if (sets.isEmpty) {
                    return EmptyState(
                      message:
                          'No sets logged yet.\nHit the button below to get started.',
                    );
                  }

                  // Group sets by exercise. Iteration order over `sets`
                  // is ascending loggedAt, so first-seen order = the order
                  // exercises were first logged today. Sort within each
                  // group by setNumber for display.
                  final grouped = <int, List<WorkoutSet>>{};
                  final exerciseOrder = <int>[];
                  for (final set in sets) {
                    if (!grouped.containsKey(set.exerciseId)) {
                      grouped[set.exerciseId] = [];
                      exerciseOrder.add(set.exerciseId);
                    }
                    grouped[set.exerciseId]!.add(set);
                  }
                  for (final list in grouped.values) {
                    list.sort((a, b) {
                      final n = a.setNumber.compareTo(b.setNumber);
                      if (n != 0) return n;
                      final dropOrder = (a.isDropSet ? 1 : 0)
                          .compareTo(b.isDropSet ? 1 : 0);
                      if (dropOrder != 0) return dropOrder;
                      return a.id.compareTo(b.id);
                    });
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 140),
                    itemCount: exerciseOrder.length,
                    itemBuilder: (context, index) {
                      final exerciseId = exerciseOrder[index];
                      return ExerciseSection(
                        exerciseId: exerciseId,
                        sets: grouped[exerciseId]!,
                        onTapHistory: () => _openHistory(exerciseId),
                        onTapLog: () => _openLogSet(exerciseId),
                        onTapSet: _openEditSet,
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

            // Rest timer
            if (_showRestTimer)
              RestTimerBar(
                key: ValueKey(_restTimerRestartKey),
                durationSeconds: timerDuration,
                onDismiss: () => setState(() => _showRestTimer = false),
              ),

            // Log a Set button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                height: 56,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _openExercisePicker,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: AppColors.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: Text('Log a Set', style: AppTypography.buttonText),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
