/// How a specific exercise's sets should be measured.
///
/// The app supports five "input shapes" covering >99% of lifts a serious
/// trainee will log. The [dbValue] is persisted in the Exercises table.
enum MeasurementType {
  /// Standard loaded strength work: dumbbell press, back squat, bench, etc.
  weightReps('weight_reps', 'Weight × Reps'),

  /// Bodyweight movement counted in reps; optional added weight (weighted
  /// pull-ups, dips with a belt). Default added weight = 0.
  repsBodyweight('reps_bodyweight', 'Reps (bodyweight)'),

  /// Pure isometric / timed hold. Plank, wall sit, hollow hold.
  time('time', 'Time'),

  /// Loaded duration: farmer's walk, weighted dead hang, suitcase carry.
  weightTime('weight_time', 'Weight + Time'),

  /// Cardio / conditioning: running, rowing, erg, bike.
  distanceTime('distance_time', 'Distance + Time');

  const MeasurementType(this.dbValue, this.displayName);

  final String dbValue;
  final String displayName;

  static MeasurementType fromString(String value) {
    return MeasurementType.values.firstWhere(
      (t) => t.dbValue == value,
      orElse: () => MeasurementType.weightReps,
    );
  }

  /// Whether this measurement type supports a drop-set series (reducing
  /// weight / reps mid-rest). Only makes sense for rep-based work.
  bool get supportsDropSets =>
      this == MeasurementType.weightReps ||
      this == MeasurementType.repsBodyweight;

  /// Whether this measurement type meaningfully supports a "half reps"
  /// indicator (partial reps to failure).
  bool get supportsHalfReps =>
      this == MeasurementType.weightReps ||
      this == MeasurementType.repsBodyweight;
}
