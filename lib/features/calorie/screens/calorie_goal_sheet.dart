import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/providers/calorie_goal_provider.dart';

/// Bottom sheet for editing the user's daily kcal + protein goals. Values
/// persist to SharedPreferences the moment Save is tapped.
///
/// Note on history: past food log entries snapshot whichever goal was in
/// effect when they were saved, so raising or lowering the goal here only
/// affects today and future days.
class CalorieGoalSheet extends ConsumerStatefulWidget {
  const CalorieGoalSheet({super.key});

  @override
  ConsumerState<CalorieGoalSheet> createState() => _CalorieGoalSheetState();
}

class _CalorieGoalSheetState extends ConsumerState<CalorieGoalSheet> {
  late final TextEditingController _kcalController;
  late final TextEditingController _proteinController;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final goal = ref.read(calorieGoalProvider);
    _kcalController = TextEditingController(text: '${goal.kcal}');
    _proteinController = TextEditingController(
      text: _formatProtein(goal.proteinG),
    );
    _kcalController.addListener(() => setState(() {}));
    _proteinController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _kcalController.dispose();
    _proteinController.dispose();
    super.dispose();
  }

  static String _formatProtein(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }

  bool get _canSave {
    final kcal = int.tryParse(_kcalController.text.trim());
    final protein = double.tryParse(_proteinController.text.trim());
    if (kcal == null || kcal < 500 || kcal > 10000) return false;
    if (protein == null || protein < 0 || protein > 500) return false;
    return true;
  }

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    setState(() => _saving = true);
    await ref.read(calorieGoalProvider.notifier).set(
          kcal: int.parse(_kcalController.text.trim()),
          proteinG: double.parse(_proteinController.text.trim()),
        );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
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
                Text('Daily goals', style: AppTypography.sectionHeader),
                const SizedBox(height: 4),
                Text(
                  'Set a calorie and protein target for each day. Past '
                  'entries keep the goal they were logged against.',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textTertiary),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _GoalLabel('Calories'),
                          const SizedBox(height: 8),
                          _GoalField(
                            controller: _kcalController,
                            formatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            hint: '2000',
                            suffix: 'kcal',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _GoalLabel('Protein'),
                          const SizedBox(height: 8),
                          _GoalField(
                            controller: _proteinController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            formatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[\d.]')),
                            ],
                            hint: '100',
                            suffix: 'g',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: TextButton(
                          onPressed: _saving
                              ? null
                              : () => Navigator.pop(context),
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
                          onPressed: (_canSave && !_saving) ? _save : null,
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
                                  'Save goals',
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

class _GoalLabel extends StatelessWidget {
  final String text;
  const _GoalLabel(this.text);

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

class _GoalField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? suffix;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? formatters;

  const _GoalField({
    required this.controller,
    required this.hint,
    this.suffix,
    this.keyboardType,
    this.formatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType ?? TextInputType.number,
      inputFormatters: formatters,
      style: AppTypography.body
          .copyWith(fontWeight: FontWeight.w700, fontSize: 18),
      cursorColor: AppColors.primaryRed,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.body.copyWith(color: AppColors.textTertiary),
        filled: true,
        fillColor: AppColors.background,
        suffixText: suffix,
        suffixStyle: AppTypography.caption
            .copyWith(color: AppColors.textTertiary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
