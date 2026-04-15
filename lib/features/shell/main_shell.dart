import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../performance/screens/performance_screen.dart';
import '../settings/screens/settings_screen.dart';
import '../today/screens/today_screen.dart';

/// Root shell with a custom bottom navigation bar. The middle tab (Today)
/// is visually larger and is the default landing page.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // 0 = Performance, 1 = Today (default), 2 = Settings
  int _index = 1;

  @override
  Widget build(BuildContext context) {
    // We intentionally avoid Scaffold.bottomNavigationBar: on some Android
    // builds (notably MIUI) a phantom MediaQuery.viewInsets.bottom survives
    // the onboarding→shell transition, which causes Scaffold to float the
    // bottom nav half-way up the screen. A plain Column with Expanded gives
    // us deterministic layout: the stack fills the remaining space and the
    // nav hugs the bottom no matter what the insets claim.
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _index,
              children: const [
                PerformanceScreen(),
                TodayScreen(),
                SettingsScreen(),
              ],
            ),
          ),
          _BuffBottomNav(
            currentIndex: _index,
            onTap: (i) {
              if (i == _index) return;
              setState(() => _index = i);
            },
          ),
        ],
      ),
    );
  }
}

class _BuffBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BuffBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(
            top: BorderSide(color: AppColors.divider, width: 1),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _SideTab(
              icon: Icons.bar_chart_rounded,
              label: 'Performance',
              selected: currentIndex == 0,
              onTap: () => onTap(0),
            ),
            _CenterTab(
              selected: currentIndex == 1,
              onTap: () => onTap(1),
            ),
            _SideTab(
              icon: Icons.settings_outlined,
              selectedIcon: Icons.settings_rounded,
              label: 'Settings',
              selected: currentIndex == 2,
              onTap: () => onTap(2),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideTab extends StatelessWidget {
  final IconData icon;
  final IconData? selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SideTab({
    required this.icon,
    this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryRed : AppColors.textSecondary;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? (selectedIcon ?? icon) : icon,
                color: color,
                size: 22,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenterTab extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _CenterTab({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Slightly elevated pill so the center tab reads as the primary action.
    return Expanded(
      flex: 1,
      child: Center(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: 72,
            height: 56,
            decoration: BoxDecoration(
              gradient: selected
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.primaryRed, AppColors.primaryDeep],
                    )
                  : null,
              color: selected ? null : AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(18),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.primaryRed.withOpacity(0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.fitness_center_rounded,
                  size: 22,
                  color:
                      selected ? Colors.white : AppColors.textSecondary,
                ),
                const SizedBox(height: 2),
                Text(
                  'Today',
                  style: AppTypography.caption.copyWith(
                    color:
                        selected ? Colors.white : AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
