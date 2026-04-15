import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../performance/screens/performance_screen.dart';
import '../settings/screens/settings_screen.dart';
import '../today/screens/today_screen.dart';
import '../water/screens/water_screen.dart';

/// Root shell with a uniform bottom navigation bar. All tabs share the same
/// visual treatment — no special center tab — and the first tab (Workout) is
/// the default landing page.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // 0 = Workout (default), 1 = Water, 2 = Performance, 3 = Settings
  int _index = 0;

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
                TodayScreen(),
                WaterScreen(),
                PerformanceScreen(),
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
    const tabs = <_TabSpec>[
      _TabSpec(
        icon: Icons.fitness_center_outlined,
        selectedIcon: Icons.fitness_center_rounded,
        label: 'Workout',
      ),
      _TabSpec(
        icon: Icons.water_drop_outlined,
        selectedIcon: Icons.water_drop_rounded,
        label: 'Water',
      ),
      _TabSpec(
        icon: Icons.bar_chart_outlined,
        selectedIcon: Icons.bar_chart_rounded,
        label: 'Performance',
      ),
      _TabSpec(
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings_rounded,
        label: 'Settings',
      ),
    ];

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(
            top: BorderSide(color: AppColors.divider, width: 1),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (int i = 0; i < tabs.length; i++)
              _NavTab(
                spec: tabs[i],
                selected: currentIndex == i,
                onTap: () => onTap(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabSpec {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _TabSpec({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

class _NavTab extends StatelessWidget {
  final _TabSpec spec;
  final bool selected;
  final VoidCallback onTap;

  const _NavTab({
    required this.spec,
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
                selected ? spec.selectedIcon : spec.icon,
                color: color,
                size: 22,
              ),
              const SizedBox(height: 2),
              Text(
                spec.label,
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
