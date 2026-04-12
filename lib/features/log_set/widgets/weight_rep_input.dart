import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class WeightRepInput extends StatelessWidget {
  final TextEditingController weightController;
  final TextEditingController repsController;
  final String weightUnit;

  const WeightRepInput({
    super.key,
    required this.weightController,
    required this.repsController,
    this.weightUnit = 'kg',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildField(weightController, weightUnit, 'Weight')),
        const SizedBox(width: 16),
        Expanded(child: _buildField(repsController, 'reps', 'Reps')),
      ],
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String suffix,
    String label,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        Container(
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
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
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
