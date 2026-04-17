enum MuscleGroup {
  chest('Chest'),
  back('Back'),
  legs('Legs'),
  biceps('Biceps'),
  triceps('Triceps'),
  shoulders('Shoulders'),
  abs('Abs'),
  cardio('Cardio'),
  other('Other');

  const MuscleGroup(this.displayName);
  final String displayName;

  static MuscleGroup fromString(String value) {
    return MuscleGroup.values.firstWhere(
      (g) => g.name == value,
      orElse: () => MuscleGroup.other,
    );
  }
}
