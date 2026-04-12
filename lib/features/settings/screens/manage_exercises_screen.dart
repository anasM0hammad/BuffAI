import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/muscle_groups.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/database/app_database.dart';
import '../../../data/providers/database_provider.dart';
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
          // Group by muscle group
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
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    MuscleGroup group = MuscleGroup.other;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          title: Text('New Exercise', style: AppTypography.cardTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                style: AppTypography.body,
                cursorColor: AppColors.primaryRed,
                decoration: InputDecoration(
                  hintText: 'Exercise name',
                  hintStyle:
                      AppTypography.body.copyWith(color: AppColors.textTertiary),
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
            ],
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
                await addExercise(name, group.name);
                if (ctx.mounted) Navigator.pop(ctx);
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

class _ExerciseTile extends ConsumerWidget {
  final Exercise exercise;

  const _ExerciseTile({required this.exercise});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        title: Text(exercise.name, style: AppTypography.body),
        trailing: exercise.isCustom
            ? IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: AppColors.textTertiary, size: 20),
                onPressed: () async {
                  final db = ref.read(databaseProvider);
                  await db.deleteExercise(exercise.id);
                },
              )
            : null,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
    );
  }
}
