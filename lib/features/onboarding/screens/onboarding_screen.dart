import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../profile/providers/profile_provider.dart';
import '../../profile/widgets/profile_form.dart';
import '../providers/onboarding_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  /// Called when the user taps "Get started" on the last page.
  final VoidCallback onDone;

  const OnboardingScreen({super.key, required this.onDone});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  final _profileForm = ProfileFormController();
  int _page = 0;

  static const _slides = <_Slide>[
    _Slide(
      icon: Icons.fitness_center_rounded,
      title: 'Log sets in seconds',
      body:
          'Tap, type, done. No rest-timer pop-ups, no social feed, no upsells '
          '— just a clean screen for logging the work.',
    ),
    _Slide(
      icon: Icons.bolt_rounded,
      title: 'Built for any lift',
      body:
          'Weight × reps, bodyweight, timed holds, and distance work all '
          'render correctly. Drop sets and half-reps get their own indicators.',
    ),
    _Slide(
      icon: Icons.emoji_events_rounded,
      title: 'See the numbers that matter',
      body:
          'Personal records surface automatically. Calculators for BMR, '
          'macros, 1RM, and plate loading live one tap away in Settings.',
    ),
  ];

  // Total pages = marketing slides + profile form page.
  int get _totalPages => _slides.length + 1;
  bool get _isProfilePage => _page == _slides.length;
  bool get _isLast => _page == _totalPages - 1;

  @override
  void dispose() {
    _controller.dispose();
    _profileForm.dispose();
    super.dispose();
  }

  /// Saves the profile (if anything was entered), marks onboarding done
  /// and hands off to the shell.
  Future<void> _finish({required bool saveProfile}) async {
    if (saveProfile) {
      final profile = _profileForm.read();
      if (!profile.isEmpty) {
        await ref.read(userProfileProvider.notifier).replace(profile);
      }
    }
    await markOnboardingComplete();
    if (mounted) widget.onDone();
  }

  void _next() {
    if (_isLast) {
      _finish(saveProfile: true);
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            // Skip
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 12, 0),
                child: TextButton(
                  // Skip always abandons any entered profile data.
                  onPressed: () => _finish(saveProfile: false),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                  child: Text('Skip', style: AppTypography.body),
                ),
              ),
            ),

            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  ..._slides.map((p) => _SlideView(slide: p)),
                  _ProfilePage(controller: _profileForm),
                ],
              ),
            ),

            // Dot indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_totalPages, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primaryRed
                        : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            // CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: AppColors.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _isProfilePage ? 'Save & finish' : 'Next',
                    style: AppTypography.buttonText,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide {
  final IconData icon;
  final String title;
  final String body;
  const _Slide({
    required this.icon,
    required this.title,
    required this.body,
  });
}

class _SlideView extends StatelessWidget {
  final _Slide slide;
  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primaryRed, AppColors.primaryDeep],
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryRed.withOpacity(0.35),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(slide.icon, size: 56, color: Colors.white),
          ),
          const SizedBox(height: 40),
          Text(
            slide.title,
            style: AppTypography.sectionHeader.copyWith(fontSize: 26),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            slide.body,
            style: AppTypography.body.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Optional profile capture — no field is required. Whatever the user
/// types here pre-fills every calculator that needs those numbers.
class _ProfilePage extends StatelessWidget {
  final ProfileFormController controller;
  const _ProfilePage({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.person_rounded,
                size: 36, color: AppColors.primaryRed),
          ),
          const SizedBox(height: 20),
          Text(
            'A few basics (optional)',
            style: AppTypography.sectionHeader.copyWith(fontSize: 22),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ll pre-fill these in the calculators so you don\'t have to '
            'type them again. Skip anything you\'d rather not share — '
            'everything lives on this device only.',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ProfileForm(controller: controller),
        ],
      ),
    );
  }
}
