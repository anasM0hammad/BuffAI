import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/measurement_type.dart';
import '../../../core/constants/muscle_groups.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/database/app_database.dart';
import '../../../data/providers/exercises_provider.dart';
import '../../../data/providers/workout_sets_provider.dart';
import '../../../shared/widgets/empty_state.dart';

class PerformanceScreen extends ConsumerStatefulWidget {
  const PerformanceScreen({super.key});

  @override
  ConsumerState<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends ConsumerState<PerformanceScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(allExercisesProvider);
    final prsAsync = ref.watch(personalRecordsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('Performance', style: AppTypography.sectionHeader),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'Your personal records',
                style: AppTypography.caption,
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 44,
                child: TextField(
                  controller: _searchController,
                  style: AppTypography.body,
                  cursorColor: AppColors.primaryRed,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search exercises...',
                    hintStyle: AppTypography.body
                        .copyWith(color: AppColors.textTertiary),
                    prefixIcon: const Icon(Icons.search,
                        color: AppColors.textTertiary, size: 20),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close,
                                color: AppColors.textTertiary, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: _buildBody(exercisesAsync, prsAsync),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    AsyncValue<List<Exercise>> exercisesAsync,
    AsyncValue<Map<int, WorkoutSet>> prsAsync,
  ) {
    if (exercisesAsync.isLoading || prsAsync.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryRed),
      );
    }
    final exercises = exercisesAsync.value ?? const [];
    final prs = prsAsync.value ?? const <int, WorkoutSet>{};

    final withPr =
        exercises.where((e) => prs.containsKey(e.id)).toList(growable: false);

    if (withPr.isEmpty) {
      return const EmptyState(
        message:
            'No PRs yet.\nLog a few sets and your bests will show up here.',
      );
    }

    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? withPr
        : withPr
            .where((e) =>
                e.name.toLowerCase().contains(q) ||
                e.muscleGroup.toLowerCase().contains(q))
            .toList();

    if (filtered.isEmpty) {
      return EmptyState(message: 'No exercises match "$_query".');
    }

    // Sort: newer PRs first (more relevant), with weight-based bests bubbling
    // up within the same day.
    filtered.sort((a, b) {
      final pa = prs[a.id]!;
      final pb = prs[b.id]!;
      return pb.loggedAt.compareTo(pa.loggedAt);
    });

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final exercise = filtered[index];
        final pr = prs[exercise.id]!;
        final type = MeasurementType.fromString(exercise.measurementType);
        return _PrCard(exercise: exercise, record: pr, type: type);
      },
    );
  }
}

class _PrCard extends StatelessWidget {
  final Exercise exercise;
  final WorkoutSet record;
  final MeasurementType type;

  const _PrCard({
    required this.exercise,
    required this.record,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final group = MuscleGroup.fromString(exercise.muscleGroup);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: AppTypography.cardTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      group.displayName,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textTertiary),
                    ),
                    Text(
                      '  •  ',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textTertiary),
                    ),
                    Flexible(
                      child: Text(
                        formatDate(record.loggedAt),
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textTertiary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.emoji_events_rounded,
                        size: 12, color: AppColors.primaryRed),
                    const SizedBox(width: 4),
                    Text(
                      'PR',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primaryRed,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  formatSetMetrics(record, type),
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w700,
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
