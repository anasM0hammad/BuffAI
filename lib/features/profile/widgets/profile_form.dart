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
  DateTime? dob;
  Gender gender = Gender.unspecified;

  ProfileFormController([UserProfile? initial]) {
    if (initial != null) seed(initial);
  }

  void seed(UserProfile profile) {
    height.text = _fmt(profile.heightCm);
    weight.text = _fmt(profile.weightKg);
    age.text = profile.age?.toString() ?? '';
    dob = profile.dob;
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

    // When DOB is picked we don't persist the manual `age` — DOB is the
    // source of truth and the profile derives age from it at read time.
    return UserProfile(
      heightCm: parseD(height.text),
      weightKg: parseD(weight.text),
      age: dob == null ? parseI(age.text) : null,
      dob: dob,
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
  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = widget.controller.dob ?? DateTime(now.year - 25, 1, 1);
    final first = DateTime(now.year - 110, 1, 1);
    final last = DateTime(now.year, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first)
          ? first
          : (initial.isAfter(last) ? last : initial),
      firstDate: first,
      lastDate: last,
      helpText: 'DATE OF BIRTH',
      fieldLabelText: 'Date of birth',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primaryRed,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
            dialogBackgroundColor: AppColors.background,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null) {
      setState(() {
        widget.controller.dob = picked;
        // DOB wins — clear the manual age so the two don't drift apart.
        widget.controller.age.text = '';
      });
    }
  }

  void _clearDob() {
    setState(() {
      widget.controller.dob = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dob = widget.controller.dob;

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
        const _FieldLabel('Date of birth'),
        const SizedBox(height: 6),
        _DobTile(
          dob: dob,
          onPick: _pickDob,
          onClear: _clearDob,
        ),
        if (dob == null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(
              'Or just type your age below.',
              style: AppTypography.caption
                  .copyWith(color: AppColors.textTertiary),
            ),
          ),
          const SizedBox(height: 10),
          _ProfileField(
            label: 'Age',
            suffix: 'years',
            controller: widget.controller.age,
            allowDecimal: false,
          ),
        ],
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

/// Tappable tile showing the picked DOB (with derived age) or a prompt
/// to pick one. A clear button appears once a date is set.
class _DobTile extends StatelessWidget {
  final DateTime? dob;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _DobTile({
    required this.dob,
    required this.onPick,
    required this.onClear,
  });

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  int _ageFrom(DateTime d) {
    final now = DateTime.now();
    var a = now.year - d.year;
    final hadBirthday = (now.month > d.month) ||
        (now.month == d.month && now.day >= d.day);
    if (!hadBirthday) a -= 1;
    return a;
  }

  @override
  Widget build(BuildContext context) {
    final hasDob = dob != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.divider, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.cake_outlined,
                  size: 18, color: AppColors.textTertiary),
              const SizedBox(width: 10),
              Expanded(
                child: hasDob
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDate(dob!),
                            style: AppTypography.body
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_ageFrom(dob!)} years old',
                            style: AppTypography.caption
                                .copyWith(color: AppColors.textTertiary),
                          ),
                        ],
                      )
                    : Text(
                        'Pick your birth date',
                        style: AppTypography.body.copyWith(
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
              if (hasDob)
                IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: AppColors.textTertiary,
                  splashRadius: 20,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                )
              else
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
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
