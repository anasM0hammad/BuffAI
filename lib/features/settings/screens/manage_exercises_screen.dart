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

/// Bottom sheet for creating or editing a custom exercise. Uses a tall
/// modal so the inputs and dropdowns have room to breathe instead of
/// getting cramped inside an AlertDialog.
Future<void> _showExerciseDialog(
  BuildContext context,
  WidgetRef ref, {
  Exercise? existing,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ExerciseFormSheet(existing: existing),
  );
}

class _ExerciseFormSheet extends ConsumerStatefulWidget {
  final Exercise? existing;
  const _ExerciseFormSheet({this.existing});

  @override
  ConsumerState<_ExerciseFormSheet> createState() => _ExerciseFormSheetState();
}

class _ExerciseFormSheetState extends ConsumerState<_ExerciseFormSheet> {
  late final TextEditingController _nameController;
  late MuscleGroup _group;
  late MeasurementType _measurement;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.existing?.name ?? '');
    _group = widget.existing != null
        ? MuscleGroup.fromString(widget.existing!.muscleGroup)
        : MuscleGroup.other;
    _measurement = widget.existing != null
        ? MeasurementType.fromString(widget.existing!.measurementType)
        : MeasurementType.weightReps;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);

    if (_isEditing) {
      final updateExercise = ref.read(updateExerciseProvider);
      await updateExercise(
        id: widget.existing!.id,
        name: name,
        muscleGroup: _group.name,
        measurementType: _measurement.dbValue,
        isCustom: widget.existing!.isCustom,
        createdAt: widget.existing!.createdAt,
      );
    } else {
      final addExercise = ref.read(addExerciseProvider);
      await addExercise(
        name: name,
        muscleGroup: _group.name,
        measurementType: _measurement.dbValue,
      );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final maxH = MediaQuery.of(context).size.height * 0.9;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxH),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                const SizedBox(height: 18),
                Text(
                  _isEditing ? 'Edit Exercise' : 'New Exercise',
                  style: AppTypography.sectionHeader,
                ),
                const SizedBox(height: 20),

                _FieldLabel('Name'),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  autofocus: !_isEditing,
                  style: AppTypography.body
                      .copyWith(fontWeight: FontWeight.w600, fontSize: 16),
                  cursorColor: AppColors.primaryRed,
                  decoration: InputDecoration(
                    hintText: 'e.g. Bulgarian Split Squat',
                    hintStyle: AppTypography.body
                        .copyWith(color: AppColors.textTertiary),
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                _FieldLabel('Muscle group'),
                const SizedBox(height: 8),
                _DropdownBox(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<MuscleGroup>(
                      value: _group,
                      isExpanded: true,
                      dropdownColor: AppColors.surfaceElevated,
                      icon: const Icon(Icons.expand_more,
                          color: AppColors.textSecondary),
                      style: AppTypography.body
                          .copyWith(fontWeight: FontWeight.w600),
                      items: MuscleGroup.values
                          .map((g) => DropdownMenuItem(
                                value: g,
                                child: Text(g.displayName),
                              ))
                          .toList(),
                      onChanged: (v) => setState(
                          () => _group = v ?? MuscleGroup.other),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                _FieldLabel('Measured by'),
                const SizedBox(height: 8),
                _DropdownBox(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<MeasurementType>(
                      value: _measurement,
                      isExpanded: true,
                      dropdownColor: AppColors.surfaceElevated,
                      icon: const Icon(Icons.expand_more,
                          color: AppColors.textSecondary),
                      style: AppTypography.body
                          .copyWith(fontWeight: FontWeight.w600),
                      items: MeasurementType.values
                          .map((m) => DropdownMenuItem(
                                value: m,
                                child: Text(m.displayName),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() =>
                          _measurement = v ?? MeasurementType.weightReps),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            backgroundColor: AppColors.surfaceElevated,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: AppTypography.body.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryRed,
                            disabledBackgroundColor:
                                AppColors.primaryRed.withOpacity(0.5),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _isEditing ? 'Save changes' : 'Add exercise',
                                  style: AppTypography.body.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.caption.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _DropdownBox extends StatelessWidget {
  final Widget child;
  const _DropdownBox({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
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
                    onPressed: () => _showExerciseDialog(
                      context,
                      ref,
                      existing: exercise,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: AppColors.textSecondary, size: 20),
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
