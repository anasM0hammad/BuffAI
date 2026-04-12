import 'package:intl/intl.dart';

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

bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

DateTime startOfDay(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

DateTime endOfDay(DateTime date) {
  return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
}
