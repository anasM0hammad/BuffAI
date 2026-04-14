import 'package:flutter/material.dart';
import '../../../core/constants/measurement_type.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/database/app_database.dart';

class SessionCard extends StatelessWidget {
  final DateTime date;
  final List<WorkoutSet> sets;
  final MeasurementType measurementType;

  const SessionCard({
    super.key,
    required this.date,
    required this.sets,
    required this.measurementType,
  });

  @override
  Widget build(BuildContext context) {
    final ordered = [...sets];
    ordered.sort((a, b) {
      final n = a.setNumber.compareTo(b.setNumber);
      if (n != 0) return n;
      final dropOrder =
          (a.isDropSet ? 1 : 0).compareTo(b.isDropSet ? 1 : 0);
      if (dropOrder != 0) return dropOrder;
      return a.id.compareTo(b.id);
    });

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              formatDate(date),
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ...ordered.map((set) => Padding(
                padding: EdgeInsets.fromLTRB(
                    set.isDropSet ? 36 : 16, 8, 16, 8),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: set.isDropSet
                            ? AppColors.primarySoft
                            : AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: set.isDropSet
                          ? const Icon(Icons.south_rounded,
                              size: 14, color: AppColors.primaryRed)
                          : Text(
                              '${set.setNumber}',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        formatSetMetrics(set, measurementType),
                        style: AppTypography.body
                            .copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (set.isHalfReps)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.primaryRed.withOpacity(0.4),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '½',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.primaryRed,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
