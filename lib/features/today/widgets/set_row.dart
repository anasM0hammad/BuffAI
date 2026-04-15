import 'package:flutter/material.dart';
import '../../../core/constants/measurement_type.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/database/app_database.dart';

class SetRow extends StatelessWidget {
  final WorkoutSet workoutSet;
  final MeasurementType measurementType;
  final VoidCallback? onDismissed;
  final VoidCallback? onTap;

  const SetRow({
    super.key,
    required this.workoutSet,
    required this.measurementType,
    this.onDismissed,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDrop = workoutSet.isDropSet;

    return Dismissible(
      key: ValueKey(workoutSet.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed?.call(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red.shade900,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(isDrop ? 36 : 16, 8, 16, 8),
          child: Row(
            children: [
              // Index badge (main = set number, drop = arrow).
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isDrop
                      ? AppColors.primarySoft
                      : AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: isDrop
                    ? const Icon(
                        Icons.south_rounded,
                        size: 14,
                        color: AppColors.primaryRed,
                      )
                    : Text(
                        '${workoutSet.setNumber}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  formatSetMetrics(workoutSet, measurementType),
                  style: AppTypography.body
                      .copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (workoutSet.isHalfReps) ...[
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Took help',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppColors.primaryRed.withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.front_hand_outlined,
                      size: 13,
                      color: AppColors.primaryRed,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
