import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/providers/onboarding_provider.dart';
import 'features/onboarding/screens/onboarding_screen.dart';
import 'features/shell/main_shell.dart';

class BuffAIApp extends StatelessWidget {
  const BuffAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Buff AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const _AppGate(),
    );
  }
}

/// Decides whether to show onboarding (first launch) or the main shell.
class _AppGate extends ConsumerStatefulWidget {
  const _AppGate();

  @override
  ConsumerState<_AppGate> createState() => _AppGateState();
}

class _AppGateState extends ConsumerState<_AppGate> {
  /// Set to `true` by onboarding completion to skip straight to the shell
  /// without re-reading shared prefs.
  bool _manuallyDismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_manuallyDismissed) return const MainShell();

    final async = ref.watch(onboardingCompletedProvider);
    return async.when(
      data: (done) => done
          ? const MainShell()
          : OnboardingScreen(
              onDone: () => setState(() => _manuallyDismissed = true),
            ),
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: SizedBox.expand(),
      ),
      // If prefs fail to load, just show the app (fail open).
      error: (_, __) => const MainShell(),
    );
  }
}
