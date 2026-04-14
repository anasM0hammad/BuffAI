import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/measurement_type.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/database/app_database.dart';
import '../../../data/providers/exercises_provider.dart';
import '../../../data/providers/workout_sets_provider.dart';
import '../../../shared/widgets/buff_button.dart';

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
  // Primary inputs — which are visible is decided by measurement type.
  final _weightController = TextEditingController();
  final _repsController = TextEditingController();
  final _durationController = TextEditingController(); // M:SS
  final _distanceController = TextEditingController(); // km
  final _addedWeightController = TextEditingController(); // reps_bodyweight

  bool _halfReps = false;
  final List<_DropDraft> _drops = [];

  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    _durationController.dispose();
    _distanceController.dispose();
    _addedWeightController.dispose();
    for (final d in _drops) {
      d.dispose();
    }
    super.dispose();
  }

  void _prefill(MeasurementType type) {
    if (_initialized) return;
    _initialized = true;

    if (widget.isEditing) {
      final set = widget.existingSet!;
      _halfReps = set.isHalfReps;
      switch (type) {
        case MeasurementType.weightReps:
          _weightController.text = formatWeightValue(set.weight);
          _repsController.text = '${set.reps}';
          break;
        case MeasurementType.repsBodyweight:
          _repsController.text = '${set.reps}';
          if ((set.addedWeight ?? 0) > 0) {
            _addedWeightController.text = formatWeightValue(set.addedWeight!);
          }
          break;
        case MeasurementType.time:
          _durationController.text = formatDuration(set.durationSec ?? 0);
          break;
        case MeasurementType.weightTime:
          _weightController.text = formatWeightValue(set.weight);
          _durationController.text = formatDuration(set.durationSec ?? 0);
          break;
        case MeasurementType.distanceTime:
          _distanceController.text =
              ((set.distanceM ?? 0) / 1000).toStringAsFixed(2);
          _durationController.text = formatDuration(set.durationSec ?? 0);
          break;
      }
      return;
    }

    // Log mode: auto-fill from most recent set.
    final recentAsync = ref.read(mostRecentSetProvider(widget.exerciseId));
    recentAsync.whenData((set) {
      if (set == null) return;
      switch (type) {
        case MeasurementType.weightReps:
          _weightController.text = formatWeightValue(set.weight);
          _repsController.text = '${set.reps}';
          break;
        case MeasurementType.repsBodyweight:
          _repsController.text = '${set.reps}';
          if ((set.addedWeight ?? 0) > 0) {
            _addedWeightController.text = formatWeightValue(set.addedWeight!);
          }
          break;
        case MeasurementType.time:
          if ((set.durationSec ?? 0) > 0) {
            _durationController.text = formatDuration(set.durationSec!);
          }
          break;
        case MeasurementType.weightTime:
          _weightController.text = formatWeightValue(set.weight);
          if ((set.durationSec ?? 0) > 0) {
            _durationController.text = formatDuration(set.durationSec!);
          }
          break;
        case MeasurementType.distanceTime:
          if ((set.distanceM ?? 0) > 0) {
            _distanceController.text =
                (set.distanceM! / 1000).toStringAsFixed(2);
          }
          if ((set.durationSec ?? 0) > 0) {
            _durationController.text = formatDuration(set.durationSec!);
          }
          break;
      }
    });
  }

  void _copyLastSet(MeasurementType type) {
    final todaySets = ref
            .read(todaySetsForExerciseProvider(widget.exerciseId))
            .valueOrNull ??
        [];
    if (todaySets.isEmpty) return;
    // Use last non-drop set as the "last set" reference.
    final last = todaySets.lastWhere(
      (s) => s.parentSetId == null,
      orElse: () => todaySets.last,
    );
    setState(() {
      _halfReps = last.isHalfReps;
      switch (type) {
        case MeasurementType.weightReps:
          _weightController.text = formatWeightValue(last.weight);
          _repsController.text = '${last.reps}';
          break;
        case MeasurementType.repsBodyweight:
          _repsController.text = '${last.reps}';
          _addedWeightController.text = (last.addedWeight ?? 0) > 0
              ? formatWeightValue(last.addedWeight!)
              : '';
          break;
        case MeasurementType.time:
          _durationController.text = formatDuration(last.durationSec ?? 0);
          break;
        case MeasurementType.weightTime:
          _weightController.text = formatWeightValue(last.weight);
          _durationController.text = formatDuration(last.durationSec ?? 0);
          break;
        case MeasurementType.distanceTime:
          _distanceController.text =
              ((last.distanceM ?? 0) / 1000).toStringAsFixed(2);
          _durationController.text = formatDuration(last.durationSec ?? 0);
          break;
      }
    });
  }

  bool _validate(MeasurementType type) {
    switch (type) {
      case MeasurementType.weightReps:
        final w = double.tryParse(_weightController.text.trim());
        final r = int.tryParse(_repsController.text.trim());
        return w != null && r != null && w >= 0 && r > 0;
      case MeasurementType.repsBodyweight:
        final r = int.tryParse(_repsController.text.trim());
        return r != null && r > 0;
      case MeasurementType.time:
        final d = parseDurationInput(_durationController.text);
        return d != null && d > 0;
      case MeasurementType.weightTime:
        final w = double.tryParse(_weightController.text.trim());
        final d = parseDurationInput(_durationController.text);
        return w != null && w >= 0 && d != null && d > 0;
      case MeasurementType.distanceTime:
        final dist = double.tryParse(_distanceController.text.trim());
        final d = parseDurationInput(_durationController.text);
        final distOk = dist != null && dist > 0;
        final durOk = d != null && d > 0;
        // Accept distance-only or time-only as long as one is present.
        return distOk || durOk;
    }
  }

  Future<void> _save(MeasurementType type) async {
    if (!_validate(type)) return;
    setState(() => _saving = true);

    double weight = 0;
    int reps = 0;
    int? durationSec;
    double? distanceM;
    double? addedWeight;

    switch (type) {
      case MeasurementType.weightReps:
        weight = double.parse(_weightController.text.trim());
        reps = int.parse(_repsController.text.trim());
        break;
      case MeasurementType.repsBodyweight:
        reps = int.parse(_repsController.text.trim());
        final added = double.tryParse(_addedWeightController.text.trim());
        if (added != null && added > 0) addedWeight = added;
        break;
      case MeasurementType.time:
        durationSec = parseDurationInput(_durationController.text);
        break;
      case MeasurementType.weightTime:
        weight = double.parse(_weightController.text.trim());
        durationSec = parseDurationInput(_durationController.text);
        break;
      case MeasurementType.distanceTime:
        final km = double.tryParse(_distanceController.text.trim());
        if (km != null && km > 0) distanceM = km * 1000;
        durationSec = parseDurationInput(_durationController.text);
        break;
    }

    if (widget.isEditing) {
      final existing = widget.existingSet!;
      final updateSet = ref.read(updateSetProvider);
      await updateSet(
        id: existing.id,
        exerciseId: existing.exerciseId,
        weight: weight,
        reps: reps,
        durationSec: durationSec,
        distanceM: distanceM,
        addedWeight: addedWeight,
        parentSetId: existing.parentSetId,
        isDropSet: existing.isDropSet,
        isHalfReps: _halfReps,
        setNumber: existing.setNumber,
        loggedAt: existing.loggedAt,
      );
    } else {
      final todaySets = ref
              .read(todaySetsForExerciseProvider(widget.exerciseId))
              .valueOrNull ??
          [];
      // Count only parent (non-drop) sets for numbering.
      final parentCount =
          todaySets.where((s) => s.parentSetId == null).length;
      final setNumber = parentCount + 1;

      final logSet = ref.read(logSetProvider);
      final parentId = await logSet(
        exerciseId: widget.exerciseId,
        weight: weight,
        reps: reps,
        durationSec: durationSec,
        distanceM: distanceM,
        addedWeight: addedWeight,
        setNumber: setNumber,
        isHalfReps: _halfReps,
      );

      // Save drop rows (same setNumber as parent, linked via parentSetId).
      for (final d in _drops) {
        final dw = double.tryParse(d.weightController.text.trim()) ?? 0;
        final dr = int.tryParse(d.repsController.text.trim()) ?? 0;
        if (dr <= 0) continue;
        await logSet(
          exerciseId: widget.exerciseId,
          weight: type == MeasurementType.repsBodyweight ? 0 : dw,
          reps: dr,
          addedWeight: type == MeasurementType.repsBodyweight && dw > 0
              ? dw
              : null,
          setNumber: setNumber,
          parentSetId: parentId,
          isDropSet: true,
        );
      }
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
          child: exerciseAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primaryRed),
              ),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Error: $e', style: AppTypography.body),
            ),
            data: (exercise) {
              final type = MeasurementType.fromString(exercise.measurementType);
              _prefill(type);

              return SingleChildScrollView(
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
                    const SizedBox(height: 14),

                    // Exercise name + measurement type badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            exercise.name,
                            style: AppTypography.sectionHeader,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _MeasurementBadge(type: type),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Last session summary
                    if (!widget.isEditing)
                      lastSessionAsync.when(
                        data: (lastSets) {
                          if (lastSets.isEmpty) return const SizedBox.shrink();
                          final summary = lastSets
                              .where((s) => s.parentSetId == null)
                              .map((s) => formatSetMetrics(s, type))
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
                    if (!widget.isEditing) const SizedBox(height: 18),

                    // Set label + copy button
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
                            data: (todaySets) {
                              final parentCount = todaySets
                                  .where((s) => s.parentSetId == null)
                                  .length;
                              return Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Set ${parentCount + 1}',
                                    style: AppTypography.cardTitle.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  if (todaySets.isNotEmpty)
                                    GestureDetector(
                                      onTap: () => _copyLastSet(type),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.primarySoft,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Copy last set',
                                          style:
                                              AppTypography.caption.copyWith(
                                            color: AppColors.primaryRed,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                    const SizedBox(height: 12),

                    // Inputs per measurement type
                    _buildInputs(type),

                    // Modifiers row (half reps toggle) — only where applicable.
                    if (type.supportsHalfReps) ...[
                      const SizedBox(height: 14),
                      _HalfRepsToggle(
                        selected: _halfReps,
                        onTap: () =>
                            setState(() => _halfReps = !_halfReps),
                      ),
                    ],

                    // Drop sets — only in log mode, rep-based work.
                    if (!widget.isEditing && type.supportsDropSets) ...[
                      const SizedBox(height: 18),
                      _DropsSection(
                        drops: _drops,
                        showAddedWeight:
                            type == MeasurementType.repsBodyweight,
                        onAdd: () => setState(() => _drops.add(_DropDraft())),
                        onRemove: (i) => setState(() {
                          _drops.removeAt(i).dispose();
                        }),
                        onChanged: () => setState(() {}),
                      ),
                    ],

                    const SizedBox(height: 24),

                    BuffButton(
                      label: widget.isEditing ? 'Update Set' : 'Save Set',
                      onPressed: () => _save(type),
                      isLoading: _saving,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInputs(MeasurementType type) {
    switch (type) {
      case MeasurementType.weightReps:
        return Row(
          children: [
            Expanded(
              child: _NumberField(
                label: 'Weight',
                suffix: 'kg',
                controller: _weightController,
                allowDecimal: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _NumberField(
                label: 'Reps',
                suffix: 'reps',
                controller: _repsController,
                allowDecimal: false,
              ),
            ),
          ],
        );
      case MeasurementType.repsBodyweight:
        return Row(
          children: [
            Expanded(
              child: _NumberField(
                label: 'Reps',
                suffix: 'reps',
                controller: _repsController,
                allowDecimal: false,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _NumberField(
                label: 'Added (opt.)',
                suffix: 'kg',
                controller: _addedWeightController,
                allowDecimal: true,
              ),
            ),
          ],
        );
      case MeasurementType.time:
        return _NumberField(
          label: 'Duration',
          suffix: 'M:SS',
          controller: _durationController,
          allowDecimal: false,
          allowColon: true,
        );
      case MeasurementType.weightTime:
        return Row(
          children: [
            Expanded(
              child: _NumberField(
                label: 'Weight',
                suffix: 'kg',
                controller: _weightController,
                allowDecimal: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _NumberField(
                label: 'Duration',
                suffix: 'M:SS',
                controller: _durationController,
                allowDecimal: false,
                allowColon: true,
              ),
            ),
          ],
        );
      case MeasurementType.distanceTime:
        return Row(
          children: [
            Expanded(
              child: _NumberField(
                label: 'Distance',
                suffix: 'km',
                controller: _distanceController,
                allowDecimal: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _NumberField(
                label: 'Duration',
                suffix: 'M:SS',
                controller: _durationController,
                allowDecimal: false,
                allowColon: true,
              ),
            ),
          ],
        );
    }
  }
}

// ── Draft holder for one drop row ─────────────────────────────────────

class _DropDraft {
  final TextEditingController weightController = TextEditingController();
  final TextEditingController repsController = TextEditingController();

  void dispose() {
    weightController.dispose();
    repsController.dispose();
  }
}

// ── UI bits ───────────────────────────────────────────────────────────

class _MeasurementBadge extends StatelessWidget {
  final MeasurementType type;
  const _MeasurementBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type.displayName,
        style: AppTypography.caption.copyWith(
          color: AppColors.textSecondary,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final String label;
  final String suffix;
  final TextEditingController controller;
  final bool allowDecimal;
  final bool allowColon;

  const _NumberField({
    required this.label,
    required this.suffix,
    required this.controller,
    this.allowDecimal = false,
    this.allowColon = false,
  });

  @override
  Widget build(BuildContext context) {
    final allowed = StringBuffer(r'\d');
    if (allowDecimal) allowed.write('.');
    if (allowColon) allowed.write(':');
    final filter = RegExp('[${allowed.toString()}]');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style:
              AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        Container(
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: allowColon
                      ? TextInputType.text
                      : TextInputType.numberWithOptions(decimal: allowDecimal),
                  inputFormatters: [FilteringTextInputFormatter.allow(filter)],
                  textAlign: TextAlign.center,
                  style: AppTypography.inputNumber,
                  cursorColor: AppColors.primaryRed,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  suffix,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textTertiary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HalfRepsToggle extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  const _HalfRepsToggle({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color:
              selected ? AppColors.primarySoft : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.primaryRed : AppColors.divider,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.adjust,
              size: 14,
              color: selected
                  ? AppColors.primaryRed
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              '½ reps (partial)',
              style: AppTypography.caption.copyWith(
                color: selected
                    ? AppColors.primaryRed
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DropsSection extends StatelessWidget {
  final List<_DropDraft> drops;
  final bool showAddedWeight;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final VoidCallback onChanged;

  const _DropsSection({
    required this.drops,
    required this.showAddedWeight,
    required this.onAdd,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.south_rounded,
                size: 14, color: AppColors.primaryRed),
            const SizedBox(width: 6),
            Text(
              'Drop sets',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(drops.length, (i) {
          final draft = drops[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primaryRed,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MiniField(
                    hint: showAddedWeight ? 'added kg' : 'kg',
                    controller: draft.weightController,
                  ),
                ),
                const SizedBox(width: 8),
                Text('×',
                    style: AppTypography.body
                        .copyWith(color: AppColors.textTertiary)),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniField(
                    hint: 'reps',
                    controller: draft.repsController,
                    integer: true,
                  ),
                ),
                IconButton(
                  onPressed: () => onRemove(i),
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textTertiary, size: 18),
                  splashRadius: 18,
                  tooltip: '',
                ),
              ],
            ),
          );
        }),
        InkWell(
          onTap: onAdd,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.divider, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded,
                    color: AppColors.primaryRed, size: 16),
                const SizedBox(width: 6),
                Text(
                  drops.isEmpty ? 'Add drop' : 'Add another drop',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primaryRed,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniField extends StatelessWidget {
  final String hint;
  final TextEditingController controller;
  final bool integer;
  const _MiniField({
    required this.hint,
    required this.controller,
    this.integer = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: !integer),
        inputFormatters: [
          FilteringTextInputFormatter.allow(
              integer ? RegExp(r'\d') : RegExp(r'[\d.]')),
        ],
        textAlign: TextAlign.center,
        style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
        cursorColor: AppColors.primaryRed,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              AppTypography.caption.copyWith(color: AppColors.textTertiary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
    );
  }
}
