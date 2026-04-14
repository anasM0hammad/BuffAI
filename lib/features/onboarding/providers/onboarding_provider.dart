import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kOnboardedKey = 'onboarded_v1';

/// Resolves whether the user has already seen onboarding. `true` means skip it.
final onboardingCompletedProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kOnboardedKey) ?? false;
});

/// Marks onboarding as complete so we never show it again.
Future<void> markOnboardingComplete() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kOnboardedKey, true);
}
