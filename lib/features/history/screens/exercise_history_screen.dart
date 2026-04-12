import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/database/app_database.dart';
import '../../../data/providers/exercises_provider.dart';
import '../../../data/providers/workout_sets_provider.dart';
import '../../../shared/widgets/empty_state.dart';
import '../widgets/session_card.dart';

class ExerciseHistoryScreen extends ConsumerStatefulWidget {
  final int exerciseId;

  const ExerciseHistoryScreen({super.key, required this.exerciseId});

  @override
  ConsumerState<ExerciseHistoryScreen> createState() =>
      _ExerciseHistoryScreenState();
}

class _ExerciseHistoryScreenState extends ConsumerState<ExerciseHistoryScreen> {
  bool _showAll = false;

  /// Groups sets by calendar date.
  Map<DateTime, List<WorkoutSet>> _groupByDate(List<WorkoutSet> sets) {
    final map = <DateTime, List<WorkoutSet>>{};
    for (final s in sets) {
      final date = startOfDay(s.loggedAt);
      map.putIfAbsent(date, () => []).add(s);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final exerciseAsync = ref.watch(exerciseByIdProvider(widget.exerciseId));
    final setsAsync = ref.watch(allSetsForExerciseProvider(widget.exerciseId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: exerciseAsync.when(
          data: (e) => Text(e.name, style: AppTypography.cardTitle),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const Text('History'),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: setsAsync.when(
        data: (allSets) {
          if (allSets.isEmpty) {
            return const EmptyState(
              message: 'No history for this exercise yet.',
            );
          }

          final grouped = _groupByDate(allSets);
          final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

          final displayDates = _showAll ? dates : dates.take(3).toList();

          return ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 32),
            children: [
              ...displayDates.map((date) => SessionCard(
                    date: date,
                    sets: grouped[date]!,
                  )),
              if (!_showAll && dates.length > 3)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextButton(
                    onPressed: () => setState(() => _showAll = true),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryRed,
                    ),
                    child: Text(
                      'Show all (${dates.length} sessions)',
                      style: AppTypography.body
                          .copyWith(color: AppColors.primaryRed),
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryRed),
        ),
        error: (err, _) => EmptyState(message: 'Error: $err'),
      ),
    );
  }
}
