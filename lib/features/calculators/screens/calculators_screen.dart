import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'body_fat_calculator_screen.dart';
import 'bmi_calculator_screen.dart';
import 'energy_calculator_screen.dart';
import 'heart_rate_calculator_screen.dart';
import 'one_rm_calculator_screen.dart';
import 'water_calculator_screen.dart';

class CalculatorsScreen extends StatelessWidget {
  const CalculatorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Calculators', style: AppTypography.cardTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _SectionLabel(title: 'Nutrition & Hydration'),
          _CalcTile(
            icon: Icons.local_fire_department_rounded,
            title: 'Energy & Macros',
            subtitle: 'BMR, TDEE, calorie target',
            onTap: () => _open(context, const EnergyCalculatorScreen()),
          ),
          _CalcTile(
            icon: Icons.water_drop_rounded,
            title: 'Water Intake',
            subtitle: 'Daily target by weight, activity, weather',
            onTap: () => _open(context, const WaterCalculatorScreen()),
          ),
          _CalcTile(
            icon: Icons.monitor_weight_rounded,
            title: 'BMI',
            subtitle: 'Body mass index',
            onTap: () => _open(context, const BmiCalculatorScreen()),
          ),
          _CalcTile(
            icon: Icons.straighten_rounded,
            title: 'Body Fat %',
            subtitle: 'US Navy method',
            onTap: () => _open(context, const BodyFatCalculatorScreen()),
          ),
          const SizedBox(height: 16),
          _SectionLabel(title: 'Training'),
          _CalcTile(
            icon: Icons.fitness_center_rounded,
            title: 'One Rep Max',
            subtitle: 'Estimate your 1RM from any set',
            onTap: () => _open(context, const OneRmCalculatorScreen()),
          ),
          _CalcTile(
            icon: Icons.favorite_rounded,
            title: 'Target Heart Rate',
            subtitle: 'Karvonen zones from age + resting HR',
            onTap: () => _open(context, const HeartRateCalculatorScreen()),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  const _SectionLabel({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 0, 8),
      child: Text(
        title.toUpperCase(),
        style: AppTypography.caption.copyWith(
          color: AppColors.textTertiary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _CalcTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CalcTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primaryRed, size: 20),
        ),
        title: Text(title, style: AppTypography.body.copyWith(
          fontWeight: FontWeight.w600,
        )),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            subtitle,
            style: AppTypography.caption
                .copyWith(color: AppColors.textTertiary),
          ),
        ),
        trailing: const Icon(Icons.chevron_right,
            color: AppColors.textTertiary, size: 20),
        onTap: onTap,
      ),
    );
  }
}
