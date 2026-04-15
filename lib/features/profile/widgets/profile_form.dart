import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../providers/profile_provider.dart';

/// Reusable profile form used by both onboarding and Settings. Every
/// field is optional; empty values are persisted as cleared. The caller
/// reads the filled-in `UserProfile` via [controller].
class ProfileForm extends StatefulWidget {
  final ProfileFormController controller;

  const ProfileForm({super.key, required this.controller});

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class ProfileFormController {
  final TextEditingController height = TextEditingController();
  final TextEditingController weight = TextEditingController();
  final TextEditingController age = TextEditingController();
  Gender gender = Gender.unspecified;

  ProfileFormController([UserProfile? initial]) {
    if (initial != null) seed(initial);
  }

  void seed(UserProfile profile) {
    height.text = _fmt(profile.heightCm);
    weight.text = _fmt(profile.weightKg);
    age.text = profile.age?.toString() ?? '';
    gender = profile.gender;
  }

  UserProfile read() {
    double? parseD(String s) {
      final v = double.tryParse(s.trim());
      if (v == null || v <= 0) return null;
      return v;
    }

    int? parseI(String s) {
      final v = int.tryParse(s.trim());
      if (v == null || v <= 0) return null;
      return v;
    }

    return UserProfile(
      heightCm: parseD(height.text),
      weightKg: parseD(weight.text),
      age: parseI(age.text),
      gender: gender,
    );
  }

  void dispose() {
    height.dispose();
    weight.dispose();
    age.dispose();
  }

  String _fmt(double? v) {
    if (v == null) return '';
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }
}

class _ProfileFormState extends State<ProfileForm> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _ProfileField(
                label: 'Height',
                suffix: 'cm',
                controller: widget.controller.height,
                allowDecimal: false,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ProfileField(
                label: 'Weight',
                suffix: 'kg',
                controller: widget.controller.weight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _ProfileField(
          label: 'Age',
          suffix: 'years',
          controller: widget.controller.age,
          allowDecimal: false,
        ),
        const SizedBox(height: 14),
        const _FieldLabel('Gender'),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.divider, width: 1),
          ),
          child: Row(
            children: [
              _GenderOption(
                label: 'Male',
                icon: Icons.male_rounded,
                selected: widget.controller.gender == Gender.male,
                onTap: () => setState(
                    () => widget.controller.gender = Gender.male),
              ),
              _GenderOption(
                label: 'Female',
                icon: Icons.female_rounded,
                selected: widget.controller.gender == Gender.female,
                onTap: () => setState(
                    () => widget.controller.gender = Gender.female),
              ),
              _GenderOption(
                label: 'Skip',
                icon: Icons.block,
                selected: widget.controller.gender == Gender.unspecified,
                onTap: () => setState(
                    () => widget.controller.gender = Gender.unspecified),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileField extends StatelessWidget {
  final String label;
  final String suffix;
  final TextEditingController controller;
  final bool allowDecimal;

  const _ProfileField({
    required this.label,
    required this.suffix,
    required this.controller,
    this.allowDecimal = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.divider, width: 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.numberWithOptions(
                      decimal: allowDecimal),
                  style: AppTypography.body
                      .copyWith(fontWeight: FontWeight.w600),
                  cursorColor: AppColors.primaryRed,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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

class _GenderOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _GenderOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryRed : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: selected ? Colors.white : AppColors.textSecondary,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
