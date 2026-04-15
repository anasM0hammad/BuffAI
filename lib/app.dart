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
/// After the user completes onboarding we invalidate the provider, which
/// re-reads SharedPreferences and flips this branch to MainShell.
class _AppGate extends ConsumerWidget {
  const _AppGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(onboardingCompletedProvider);
    return async.when(
      data: (done) => done
          ? const MainShell()
          : OnboardingScreen(
              onDone: () => ref.invalidate(onboardingCompletedProvider),
            ),
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: SizedBox.expand(),
      ),
      // If prefs fail to load, fail open into the app.
      error: (_, __) => const MainShell(),
    );
  }
}
