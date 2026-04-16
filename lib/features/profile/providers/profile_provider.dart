import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Self-identified gender used to tailor calculator defaults (BMR sex
/// offset, body-fat formula, etc.). `unspecified` means we don't know
/// and shouldn't auto-fill.
enum Gender { unspecified, male, female }

/// Cached basic measurements the user opted to share. Every field is
/// nullable — the profile is deliberately optional end-to-end.
class UserProfile {
  final double? heightCm;
  final double? weightKg;
  final int? age;
  final DateTime? dob;
  final Gender gender;

  const UserProfile({
    this.heightCm,
    this.weightKg,
    this.age,
    this.dob,
    this.gender = Gender.unspecified,
  });

  static const empty = UserProfile();

  bool get isEmpty =>
      heightCm == null &&
      weightKg == null &&
      age == null &&
      dob == null &&
      gender == Gender.unspecified;

  /// Current age in years. Computed from DOB when available, otherwise
  /// falls back to the manually-entered `age` field. Returns null when
  /// neither is set.
  int? get effectiveAge {
    if (dob != null) {
      final now = DateTime.now();
      var a = now.year - dob!.year;
      final hadBirthdayThisYear = (now.month > dob!.month) ||
          (now.month == dob!.month && now.day >= dob!.day);
      if (!hadBirthdayThisYear) a -= 1;
      return a > 0 ? a : null;
    }
    return age;
  }

  /// Short one-line summary for Settings, e.g. "170 cm · 72 kg · 28 · Male".
  /// Returns null when nothing is filled in.
  String? summary() {
    final parts = <String>[];
    if (heightCm != null) parts.add('${_fmtNum(heightCm!)} cm');
    if (weightKg != null) parts.add('${_fmtNum(weightKg!)} kg');
    final a = effectiveAge;
    if (a != null) parts.add('$a');
    if (gender != Gender.unspecified) {
      parts.add(gender == Gender.male ? 'Male' : 'Female');
    }
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }
}

String _fmtNum(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(1);
}

// ── SharedPreferences keys ──
const _kHeight = 'profile_height_cm';
const _kWeight = 'profile_weight_kg';
const _kAge = 'profile_age';
const _kDob = 'profile_dob_iso';
const _kGender = 'profile_gender';

/// Loads the persisted profile once at app start. Consumed by
/// [userProfileProvider] to seed the StateNotifier.
final _persistedProfileProvider = FutureProvider<UserProfile>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final genderStr = prefs.getString(_kGender);
  final gender = switch (genderStr) {
    'male' => Gender.male,
    'female' => Gender.female,
    _ => Gender.unspecified,
  };
  final dobStr = prefs.getString(_kDob);
  final dob = dobStr == null ? null : DateTime.tryParse(dobStr);
  return UserProfile(
    heightCm: prefs.getDouble(_kHeight),
    weightKg: prefs.getDouble(_kWeight),
    age: prefs.getInt(_kAge),
    dob: dob,
    gender: gender,
  );
});

/// User's basic measurements. Synchronously readable — defaults to the
/// empty profile while the async load is still in flight, then the
/// StateNotifier is reseeded once SharedPreferences returns.
final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfile>((ref) {
  final initial =
      ref.watch(_persistedProfileProvider).value ?? UserProfile.empty;
  return UserProfileNotifier(initial);
});

class UserProfileNotifier extends StateNotifier<UserProfile> {
  UserProfileNotifier(super.state);

  /// Replace the whole profile. Null fields are persisted as cleared.
  Future<void> replace(UserProfile profile) async {
    state = profile;
    final prefs = await SharedPreferences.getInstance();

    if (profile.heightCm == null) {
      await prefs.remove(_kHeight);
    } else {
      await prefs.setDouble(_kHeight, profile.heightCm!);
    }

    if (profile.weightKg == null) {
      await prefs.remove(_kWeight);
    } else {
      await prefs.setDouble(_kWeight, profile.weightKg!);
    }

    if (profile.age == null) {
      await prefs.remove(_kAge);
    } else {
      await prefs.setInt(_kAge, profile.age!);
    }

    if (profile.dob == null) {
      await prefs.remove(_kDob);
    } else {
      await prefs.setString(_kDob, profile.dob!.toIso8601String());
    }

    if (profile.gender == Gender.unspecified) {
      await prefs.remove(_kGender);
    } else {
      await prefs.setString(
          _kGender, profile.gender == Gender.male ? 'male' : 'female');
    }
  }
}
