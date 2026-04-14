import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/measurement_type.dart';
import '../../../core/constants/muscle_groups.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/database/app_database.dart';
import '../../../data/providers/exercises_provider.dart';
import '../widgets/exercise_list_item.dart';
import '../widgets/muscle_group_tabs.dart';

class ExercisePickerSheet extends ConsumerStatefulWidget {
  const ExercisePickerSheet({super.key});

  @override
  ConsumerState<ExercisePickerSheet> createState() =>
      _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends ConsumerState<ExercisePickerSheet> {
  final _searchController = TextEditingController();
  MuscleGroup? _selectedGroup;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Exercise> _filterExercises(List<Exercise> exercises) {
    var filtered = exercises;

    if (_selectedGroup != null) {
      filtered = filtered
          .where((e) => e.muscleGroup == _selectedGroup!.name)
          .toList();
    }

    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      filtered =
          filtered.where((e) => e.name.toLowerCase().contains(q)).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(allExercisesProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  'Pick an Exercise',
                  style: AppTypography.sectionHeader,
                ),
              ),

              // Search bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  height: 44,
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: AppTypography.body,
                    cursorColor: AppColors.primaryRed,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Search exercises...',
                      hintStyle: AppTypography.body.copyWith(
                        color: AppColors.textTertiary,
                      ),
                      prefixIcon: const Icon(Icons.search,
                          color: AppColors.textTertiary, size: 20),
                      filled: true,
                      fillColor: AppColors.surfaceElevated,
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

              // Muscle group tabs
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: MuscleGroupTabs(
                  selected: _selectedGroup,
                  onSelected: (g) => setState(() => _selectedGroup = g),
                ),
              ),

              const Divider(height: 1, color: AppColors.divider),

              // Exercise list
              Expanded(
                child: exercisesAsync.when(
                  data: (exercises) {
                    final filtered = _filterExercises(exercises);
                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          'No exercises found',
                          style: AppTypography.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      controller: scrollController,
                      itemCount: filtered.length + 1,
                      separatorBuilder: (_, __) => const Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: AppColors.divider,
                      ),
                      itemBuilder: (context, index) {
                        if (index == filtered.length) {
                          return _buildCreateNew();
                        }
                        final exercise = filtered[index];
                        return ExerciseListItem(
                          exercise: exercise,
                          onTap: () => Navigator.pop(context, exercise.id),
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryRed,
                    ),
                  ),
                  error: (err, _) => Center(
                    child: Text('Error: $err'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCreateNew() {
    return InkWell(
      onTap: () => _showCreateExerciseDialog(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.add_circle_outline,
                color: AppColors.primaryRed, size: 20),
            const SizedBox(width: 12),
            Text(
              'Create new exercise',
              style: AppTypography.body.copyWith(color: AppColors.primaryRed),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateExerciseDialog() {
    final nameController = TextEditingController();
    MuscleGroup group = MuscleGroup.other;
    MeasurementType measurement = MeasurementType.weightReps;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          title: Text('New Exercise', style: AppTypography.cardTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  style: AppTypography.body,
                  cursorColor: AppColors.primaryRed,
                  decoration: InputDecoration(
                    hintText: 'Exercise name',
                    hintStyle: AppTypography.body.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<MuscleGroup>(
                  value: group,
                  dropdownColor: AppColors.surfaceElevated,
                  style: AppTypography.body,
                  decoration: InputDecoration(
                    labelText: 'Muscle group',
                    labelStyle: AppTypography.caption,
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: MuscleGroup.values.map((g) {
                    return DropdownMenuItem(
                      value: g,
                      child: Text(g.displayName),
                    );
                  }).toList(),
                  onChanged: (v) =>
                      setDialogState(() => group = v ?? MuscleGroup.other),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<MeasurementType>(
                  value: measurement,
                  dropdownColor: AppColors.surfaceElevated,
                  style: AppTypography.body,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Measured by',
                    labelStyle: AppTypography.caption,
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: MeasurementType.values.map((m) {
                    return DropdownMenuItem(
                      value: m,
                      child: Text(m.displayName),
                    );
                  }).toList(),
                  onChanged: (v) => setDialogState(
                      () => measurement = v ?? MeasurementType.weightReps),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: AppTypography.body
                      .copyWith(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                final addExercise = ref.read(addExerciseProvider);
                final id = await addExercise(
                  name: name,
                  muscleGroup: group.name,
                  measurementType: measurement.dbValue,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) Navigator.pop(context, id);
              },
              child: Text('Add',
                  style: AppTypography.body
                      .copyWith(color: AppColors.primaryRed)),
            ),
          ],
        ),
      ),
    );
  }
}
