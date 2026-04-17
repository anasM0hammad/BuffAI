import 'package:intl/intl.dart';

import '../constants/measurement_type.dart';
import '../../data/database/app_database.dart';

String formatWeight(double weight, {bool useLbs = false}) {
  if (useLbs) {
    final lbs = weight * 2.20462;
    return lbs == lbs.roundToDouble()
        ? '${lbs.toInt()} lbs'
        : '${lbs.toStringAsFixed(1)} lbs';
  }
  return weight == weight.roundToDouble()
      ? '${weight.toInt()} kg'
      : '${weight.toStringAsFixed(1)} kg';
}

String formatWeightValue(double weight, {bool useLbs = false}) {
  if (useLbs) {
    final lbs = weight * 2.20462;
    return lbs == lbs.roundToDouble()
        ? '${lbs.toInt()}'
        : lbs.toStringAsFixed(1);
  }
  return weight == weight.roundToDouble()
      ? '${weight.toInt()}'
      : weight.toStringAsFixed(1);
}

String formatDate(DateTime date) {
  return DateFormat('EEE, MMM d').format(date);
}

String formatFullDate(DateTime date) {
  return DateFormat('EEEE, MMMM d, yyyy').format(date);
}

String formatTimerSeconds(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

String formatSetSummary(double weight, int reps, {bool useLbs = false}) {
  return '${formatWeight(weight, useLbs: useLbs)} x $reps';
}

/// Formats a duration in seconds as `M:SS` (or `H:MM:SS` when ≥ 1h).
/// Use for compact / input-field contexts where the abbreviated form
/// is unambiguous in context (e.g. the duration input on a log-set
/// sheet, timer-style readouts).
String formatDuration(int totalSeconds) {
  if (totalSeconds < 0) totalSeconds = 0;
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Human-readable duration label — e.g. `2min 02sec`, `45sec`,
/// `1hr 05min`. Use wherever a logged time is shown to the user to
/// avoid the `2:02` / `0:02` ambiguity of the colon-separated form.
String formatDurationLabel(int totalSeconds) {
  if (totalSeconds < 0) totalSeconds = 0;
  if (totalSeconds == 0) return '0sec';
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  final parts = <String>[];
  if (h > 0) parts.add('${h}hr');
  if (m > 0) {
    parts.add(h > 0 ? '${m.toString().padLeft(2, '0')}min' : '${m}min');
  }
  if (s > 0) {
    parts.add(
      (h > 0 || m > 0) ? '${s.toString().padLeft(2, '0')}sec' : '${s}sec',
    );
  }
  return parts.join(' ');
}

/// Parses an `M:SS`, `H:MM:SS`, or raw seconds string into total seconds.
/// Returns null if the input cannot be parsed.
int? parseDurationInput(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;
  if (!trimmed.contains(':')) {
    return int.tryParse(trimmed);
  }
  final parts = trimmed.split(':');
  if (parts.length < 2 || parts.length > 3) return null;
  final nums = parts.map((p) => int.tryParse(p)).toList();
  if (nums.any((n) => n == null || n < 0)) return null;
  if (parts.length == 2) {
    return nums[0]! * 60 + nums[1]!;
  }
  return nums[0]! * 3600 + nums[1]! * 60 + nums[2]!;
}

/// Formats a distance in meters. Uses km with 2 decimals when ≥ 1000 m,
/// otherwise whole meters.
String formatDistance(double meters) {
  if (meters >= 1000) {
    final km = meters / 1000;
    final str =
        km == km.roundToDouble() ? '${km.toInt()}' : km.toStringAsFixed(2);
    return '$str km';
  }
  return '${meters.toStringAsFixed(0)} m';
}

/// Returns a human-readable one-liner for a set, chosen based on the
/// exercise's [MeasurementType]. Use for history / PR summaries.
String formatSetMetrics(WorkoutSet set, MeasurementType type,
    {bool useLbs = false}) {
  switch (type) {
    case MeasurementType.weightReps:
      return formatSetSummary(set.weight, set.reps, useLbs: useLbs);
    case MeasurementType.repsBodyweight:
      final added = set.addedWeight ?? 0;
      if (added > 0) {
        return '${set.reps} × ${formatWeight(added, useLbs: useLbs)} added';
      }
      return '${set.reps} reps';
    case MeasurementType.time:
      return formatDurationLabel(set.durationSec ?? 0);
    case MeasurementType.weightTime:
      final weight = set.weight == 0 ? '' : '${formatWeight(set.weight, useLbs: useLbs)} · ';
      return '$weight${formatDurationLabel(set.durationSec ?? 0)}';
    case MeasurementType.distanceTime:
      final dist = formatDistance(set.distanceM ?? 0);
      final dur = formatDurationLabel(set.durationSec ?? 0);
      return '$dist · $dur';
  }
}

bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

DateTime startOfDay(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

DateTime endOfDay(DateTime date) {
  return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
}
