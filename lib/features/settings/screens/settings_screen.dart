import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/providers/database_provider.dart';
import '../../calculators/screens/calculators_screen.dart';
import '../../history/screens/history_tab_screen.dart';
import '../../profile/providers/profile_provider.dart';
import '../../today/screens/today_screen.dart';
import '../widgets/edit_profile_sheet.dart';
import 'manage_exercises_screen.dart';
import 'manage_foods_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerDuration = ref.watch(restTimerDurationProvider);
    final profile = ref.watch(userProfileProvider);
    final profileSummary = profile.summary();

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        automaticallyImplyLeading: false,
        title: Text('Settings', style: AppTypography.sectionHeader),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Your Measurements
          _SectionHeader(title: 'Your Measurements'),
          _SettingsTile(
            title: profileSummary == null
                ? 'Add your details'
                : 'Your measurements',
            subtitle: profileSummary ??
                'Height, weight, age & gender auto-fill into calculators',
            icon: Icons.person_rounded,
            onTap: () => showEditProfileSheet(context),
          ),

          const SizedBox(height: 16),

          // Rest Timer Duration
          _SectionHeader(title: 'Rest Timer'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Default duration',
                  style: AppTypography.body
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [60, 90, 120, 180].map((seconds) {
                    final isActive = timerDuration == seconds;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => ref
                            .read(restTimerDurationProvider.notifier)
                            .state = seconds,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.primaryRed
                                : AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${seconds}s',
                            style: AppTypography.tabLabel.copyWith(
                              color: isActive
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Manage Exercises
          _SectionHeader(title: 'Library'),
          _SettingsTile(
            title: 'Manage Exercises',
            subtitle: 'Add, edit, or remove exercises',
            icon: Icons.fitness_center_rounded,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ManageExercisesScreen(),
              ),
            ),
          ),
          _SettingsTile(
            title: 'Manage Foods',
            subtitle: 'Add, edit, or remove foods',
            icon: Icons.restaurant_menu_rounded,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ManageFoodsScreen(),
              ),
            ),
          ),

          const SizedBox(height: 16),

          _SectionHeader(title: 'Tools'),
          _SettingsTile(
            title: 'Calculators',
            subtitle: 'Energy, water, BMI, body fat, 1RM, heart rate',
            icon: Icons.calculate_rounded,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CalculatorsScreen(),
              ),
            ),
          ),
          _SettingsTile(
            title: 'History',
            subtitle: 'Hydration and workout history, last 30 days',
            icon: Icons.history_rounded,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const HistoryTabScreen(),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Data management — destructive, kept visually distinct.
          _SectionHeader(title: 'Data'),
          _SettingsTile(
            title: 'Reset data',
            subtitle:
                'Delete all workout and water logs. Profile is kept.',
            icon: Icons.delete_forever_rounded,
            destructive: true,
            onTap: () => _confirmReset(context, ref),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _ResetConfirmDialog(),
    );
    if (confirmed != true) return;
    final db = ref.read(databaseProvider);
    await db.resetAllLoggedData();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceElevated,
        content: Text(
          'All logged data cleared.',
          style: AppTypography.body,
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// Modal that requires explicit confirmation before wiping data.
class _ResetConfirmDialog extends StatelessWidget {
  const _ResetConfirmDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.primaryRed,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Reset all data?',
              style: AppTypography.cardTitle,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This will permanently delete:',
            style: AppTypography.body
                .copyWith(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 10),
          const _ResetBullet('Every logged workout set'),
          const _ResetBullet('Every water-intake entry'),
          const _ResetBullet('Any custom exercises you created'),
          const SizedBox(height: 12),
          Text(
            'Your profile, preferences and the built-in exercise library '
            'are kept. This cannot be undone.',
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
              height: 1.45,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: Text(
            'Cancel',
            style:
                AppTypography.body.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryRed,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            'Delete',
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _ResetBullet extends StatelessWidget {
  final String text;
  const _ResetBullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 7, right: 8),
            child: Icon(
              Icons.fiber_manual_record,
              size: 5,
              color: AppColors.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: AppTypography.body.copyWith(
                color: AppColors.textPrimary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: AppTypography.caption.copyWith(
          color: AppColors.textTertiary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  /// Renders the title + icon in the brand red. Used for destructive
  /// actions like "Reset data".
  final bool destructive;

  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = destructive ? AppColors.primaryRed : AppColors.textSecondary;
    final titleStyle = destructive
        ? AppTypography.body.copyWith(
            color: AppColors.primaryRed,
            fontWeight: FontWeight.w600,
          )
        : AppTypography.body;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: destructive
              ? Border.all(
                  color: AppColors.primaryRed.withOpacity(0.25),
                  width: 1,
                )
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: titleStyle),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}
