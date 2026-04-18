import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/food_types.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/providers/foods_provider.dart';

/// Sheet for creating a new user-custom food. On success the sheet pops
/// with the newly inserted food id, which the picker uses to open a
/// portion sheet immediately so the user can log their first entry.
class CustomFoodSheet extends ConsumerStatefulWidget {
  final String? initialName;
  const CustomFoodSheet({super.key, this.initialName});

  @override
  ConsumerState<CustomFoodSheet> createState() => _CustomFoodSheetState();
}

class _CustomFoodSheetState extends ConsumerState<CustomFoodSheet> {
  late final TextEditingController _nameController;
  final _amountController = TextEditingController();
  final _kcalController = TextEditingController();
  final _proteinController = TextEditingController();

  FoodCategory _category = FoodCategory.protein;
  FoodUnit _unit = FoodUnit.g;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.initialName ?? '');
    _amountController.addListener(() => setState(() {}));
    _kcalController.addListener(() => setState(() {}));
    _proteinController.addListener(() => setState(() {}));
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _kcalController.dispose();
    _proteinController.dispose();
    super.dispose();
  }

  /// Sensible default amount per unit — 100 g / 100 ml / 1 piece / 1 serving.
  String _defaultAmountFor(FoodUnit unit) {
    switch (unit) {
      case FoodUnit.g:
      case FoodUnit.ml:
        return '100';
      case FoodUnit.piece:
      case FoodUnit.serving:
        return '1';
    }
  }

  bool get _canSave {
    if (_nameController.text.trim().isEmpty) return false;
    final amount = double.tryParse(_amountController.text.trim());
    final kcal = int.tryParse(_kcalController.text.trim());
    final protein = double.tryParse(_proteinController.text.trim());
    if (amount == null || amount <= 0) return false;
    if (kcal == null || kcal < 0) return false;
    if (protein == null || protein < 0) return false;
    return true;
  }

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    setState(() => _saving = true);

    final add = ref.read(addCustomFoodProvider);
    final newId = await add(
      name: _nameController.text.trim(),
      category: _category.name,
      baseAmount: double.parse(_amountController.text.trim()),
      baseUnit: _unit.name,
      kcal: int.parse(_kcalController.text.trim()),
      proteinG: double.parse(_proteinController.text.trim()),
    );

    if (mounted) Navigator.pop(context, newId);
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final maxH = MediaQuery.of(context).size.height * 0.92;

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
                Text('Add food', style: AppTypography.sectionHeader),
                const SizedBox(height: 4),
                Text(
                  'Enter the calories and protein for one portion. You can log any multiple of this later.',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textTertiary),
                ),
                const SizedBox(height: 20),

                const _FieldLabel('Name'),
                const SizedBox(height: 8),
                _TextBox(
                  controller: _nameController,
                  autofocus: widget.initialName == null ||
                      widget.initialName!.trim().isEmpty,
                  hint: 'e.g. Chicken breast',
                ),
                const SizedBox(height: 18),

                const _FieldLabel('Category'),
                const SizedBox(height: 8),
                _DropdownBox(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<FoodCategory>(
                      value: _category,
                      isExpanded: true,
                      dropdownColor: AppColors.surfaceElevated,
                      icon: const Icon(Icons.expand_more,
                          color: AppColors.textSecondary),
                      style: AppTypography.body
                          .copyWith(fontWeight: FontWeight.w600),
                      items: FoodCategory.values
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c.label),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() =>
                          _category = v ?? FoodCategory.protein),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _FieldLabel('Portion'),
                          const SizedBox(height: 8),
                          _TextBox(
                            controller: _amountController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            formatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[\d.]')),
                            ],
                            hint: _defaultAmountFor(_unit),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _FieldLabel('Unit'),
                          const SizedBox(height: 8),
                          _DropdownBox(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<FoodUnit>(
                                value: _unit,
                                isExpanded: true,
                                dropdownColor: AppColors.surfaceElevated,
                                icon: const Icon(Icons.expand_more,
                                    color: AppColors.textSecondary),
                                style: AppTypography.body
                                    .copyWith(fontWeight: FontWeight.w600),
                                items: FoodUnit.values
                                    .map((u) => DropdownMenuItem(
                                          value: u,
                                          child: Text(u.longLabel),
                                        ))
                                    .toList(),
                                onChanged: (v) {
                                  if (v == null) return;
                                  final oldDefault = _defaultAmountFor(_unit);
                                  final currentText =
                                      _amountController.text.trim();
                                  setState(() => _unit = v);
                                  // If the user hadn't typed anything
                                  // custom, adjust the field to match the
                                  // new unit's sensible default.
                                  if (currentText.isEmpty ||
                                      currentText == oldDefault) {
                                    _amountController.text =
                                        _defaultAmountFor(v);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _FieldLabel('Calories'),
                          const SizedBox(height: 8),
                          _TextBox(
                            controller: _kcalController,
                            keyboardType: TextInputType.number,
                            formatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            hint: '0',
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
                          const _FieldLabel('Protein'),
                          const SizedBox(height: 8),
                          _TextBox(
                            controller: _proteinController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            formatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[\d.]')),
                            ],
                            hint: '0',
                            suffix: 'g',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

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
                                  'Save food',
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

class _TextBox extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool autofocus;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? formatters;
  final String? suffix;

  const _TextBox({
    required this.controller,
    required this.hint,
    this.autofocus = false,
    this.keyboardType,
    this.formatters,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      style:
          AppTypography.body.copyWith(fontWeight: FontWeight.w600, fontSize: 16),
      cursorColor: AppColors.primaryRed,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            AppTypography.body.copyWith(color: AppColors.textTertiary),
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
