import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/measurement_type.dart';
import '../../../core/constants/muscle_groups.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/database/app_database.dart';
import '../../../data/providers/exercises_provider.dart';

class ManageExercisesScreen extends ConsumerWidget {
  const ManageExercisesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercisesAsync = ref.watch(allExercisesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Manage Exercises', style: AppTypography.cardTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: exercisesAsync.when(
        data: (exercises) {
          final grouped = <String, List<Exercise>>{};
          for (final e in exercises) {
            grouped.putIfAbsent(e.muscleGroup, () => []).add(e);
          }
          final groups = grouped.keys.toList()..sort();

          return ListView(
            padding: const EdgeInsets.only(bottom: 80),
            children: groups.expand((group) {
              final items = grouped[group]!;
              return [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    group[0].toUpperCase() + group.substring(1),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                ...items.map((exercise) => _ExerciseTile(exercise: exercise)),
              ];
            }).toList(),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryRed),
        ),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryRed,
        onPressed: () => _showExerciseDialog(context, ref),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

/// Shared dialog for creating or editing a custom exercise.
Future<void> _showExerciseDialog(
  BuildContext context,
  WidgetRef ref, {
  Exercise? existing,
}) async {
  final nameController = TextEditingController(text: existing?.name ?? '');
  MuscleGroup group = existing != null
      ? MuscleGroup.fromString(existing.muscleGroup)
      : MuscleGroup.other;
  MeasurementType measurement = existing != null
      ? MeasurementType.fromString(existing.measurementType)
      : MeasurementType.weightReps;
  final isEditing = existing != null;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text(
          isEditing ? 'Edit Exercise' : 'New Exercise',
          style: AppTypography.cardTitle,
        ),
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
                  hintStyle: AppTypography.body
                      .copyWith(color: AppColors.textTertiary),
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
                items: MuscleGroup.values
                    .map((g) => DropdownMenuItem(
                          value: g,
                          child: Text(g.displayName),
                        ))
                    .toList(),
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
                items: MeasurementType.values
                    .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text(m.displayName),
                        ))
                    .toList(),
                onChanged: (v) => setDialogState(() =>
                    measurement = v ?? MeasurementType.weightReps),
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
              if (isEditing) {
                final updateExercise = ref.read(updateExerciseProvider);
                await updateExercise(
                  id: existing.id,
                  name: name,
                  muscleGroup: group.name,
                  measurementType: measurement.dbValue,
                  isCustom: existing.isCustom,
                  createdAt: existing.createdAt,
                );
              } else {
                final addExercise = ref.read(addExerciseProvider);
                await addExercise(
                  name: name,
                  muscleGroup: group.name,
                  measurementType: measurement.dbValue,
                );
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(
              isEditing ? 'Save' : 'Add',
              style:
                  AppTypography.body.copyWith(color: AppColors.primaryRed),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ExerciseTile extends ConsumerWidget {
  final Exercise exercise;

  const _ExerciseTile({required this.exercise});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = MeasurementType.fromString(exercise.measurementType);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        title: Row(
          children: [
            Flexible(
              child: Text(
                exercise.name,
                style: AppTypography.body,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (exercise.isCustom) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Custom',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primaryRed,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            type.displayName,
            style: AppTypography.caption
                .copyWith(color: AppColors.textTertiary, fontSize: 11),
          ),
        ),
        trailing: exercise.isCustom
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        color: AppColors.textSecondary, size: 20),
                    tooltip: 'Edit',
                    onPressed: () => _showExerciseDialog(
                      context,
                      ref,
                      existing: exercise,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: AppColors.textSecondary, size: 20),
                    tooltip: 'Delete',
                    onPressed: () => _confirmDelete(context, ref),
                  ),
                ],
              )
            : null,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text('Delete exercise?', style: AppTypography.cardTitle),
        content: Text(
          'This removes "${exercise.name}" and every set you\'ve ever logged for it. This cannot be undone.',
          style:
              AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: AppTypography.body
                    .copyWith(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style:
                  AppTypography.body.copyWith(color: AppColors.primaryRed),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final deleteExercise = ref.read(deleteExerciseProvider);
    await deleteExercise(exercise.id);
  }
}
