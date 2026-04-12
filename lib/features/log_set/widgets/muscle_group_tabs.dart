import 'package:flutter/material.dart';
import '../../../core/constants/muscle_groups.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class MuscleGroupTabs extends StatelessWidget {
  final MuscleGroup? selected;
  final ValueChanged<MuscleGroup?> onSelected;

  const MuscleGroupTabs({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _Chip(
            label: 'All',
            isActive: selected == null,
            onTap: () => onSelected(null),
          ),
          const SizedBox(width: 8),
          ...MuscleGroup.values.map(
            (group) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _Chip(
                label: group.displayName,
                isActive: selected == group,
                onTap: () => onSelected(group),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryRed : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTypography.tabLabel.copyWith(
            color: isActive ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
