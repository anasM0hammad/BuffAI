import 'measurement_type.dart';
import 'muscle_groups.dart';

class DefaultExercise {
  final String name;
  final MuscleGroup muscleGroup;
  final MeasurementType measurementType;

  const DefaultExercise(
    this.name,
    this.muscleGroup, [
    this.measurementType = MeasurementType.weightReps,
  ]);
}

/// Curated default library. Organised by muscle group; measurement type
/// reflects how serious lifters log each movement. Users can add their own
/// customs on top, and these defaults are seeded on first run (and any
/// missing entries backfilled on upgrade).
const List<DefaultExercise> defaultExercises = [
  // ── Chest ─────────────────────────────────────────────────────────
  DefaultExercise('Barbell Bench Press', MuscleGroup.chest),
  DefaultExercise('Incline Barbell Bench Press', MuscleGroup.chest),
  DefaultExercise('Decline Bench Press', MuscleGroup.chest),
  DefaultExercise('Dumbbell Bench Press', MuscleGroup.chest),
  DefaultExercise('Incline Dumbbell Press', MuscleGroup.chest),
  DefaultExercise('Dumbbell Fly', MuscleGroup.chest),
  DefaultExercise('Cable Crossover', MuscleGroup.chest),
  DefaultExercise('Pec Deck', MuscleGroup.chest),
  DefaultExercise('Machine Chest Press', MuscleGroup.chest),
  DefaultExercise(
      'Dips (Chest)', MuscleGroup.chest, MeasurementType.repsBodyweight),
  DefaultExercise(
      'Push-up', MuscleGroup.chest, MeasurementType.repsBodyweight),

  // ── Back ──────────────────────────────────────────────────────────
  DefaultExercise('Deadlift', MuscleGroup.back),
  DefaultExercise(
      'Pull-up', MuscleGroup.back, MeasurementType.repsBodyweight),
  DefaultExercise(
      'Chin-up', MuscleGroup.back, MeasurementType.repsBodyweight),
  DefaultExercise('Lat Pulldown', MuscleGroup.back),
  DefaultExercise('Barbell Row', MuscleGroup.back),
  DefaultExercise('Pendlay Row', MuscleGroup.back),
  DefaultExercise('Dumbbell Row', MuscleGroup.back),
  DefaultExercise('Seated Cable Row', MuscleGroup.back),
  DefaultExercise('Chest-Supported Row', MuscleGroup.back),
  DefaultExercise('T-Bar Row', MuscleGroup.back),
  DefaultExercise('Face Pull', MuscleGroup.back),
  DefaultExercise('Straight-Arm Pulldown', MuscleGroup.back),

  // ── Legs ──────────────────────────────────────────────────────────
  DefaultExercise('Back Squat', MuscleGroup.legs),
  DefaultExercise('Front Squat', MuscleGroup.legs),
  DefaultExercise('Romanian Deadlift', MuscleGroup.legs),
  DefaultExercise('Leg Press', MuscleGroup.legs),
  DefaultExercise('Bulgarian Split Squat', MuscleGroup.legs),
  DefaultExercise('Walking Lunge', MuscleGroup.legs),
  DefaultExercise('Leg Extension', MuscleGroup.legs),
  DefaultExercise('Lying Leg Curl', MuscleGroup.legs),
  DefaultExercise('Seated Leg Curl', MuscleGroup.legs),
  DefaultExercise('Hip Thrust', MuscleGroup.legs),
  DefaultExercise('Standing Calf Raise', MuscleGroup.legs),
  DefaultExercise('Seated Calf Raise', MuscleGroup.legs),

  // ── Shoulders ─────────────────────────────────────────────────────
  DefaultExercise('Overhead Press (Barbell)', MuscleGroup.shoulders),
  DefaultExercise('Seated Dumbbell Shoulder Press', MuscleGroup.shoulders),
  DefaultExercise('Push Press', MuscleGroup.shoulders),
  DefaultExercise('Arnold Press', MuscleGroup.shoulders),
  DefaultExercise('Dumbbell Lateral Raise', MuscleGroup.shoulders),
  DefaultExercise('Cable Lateral Raise', MuscleGroup.shoulders),
  DefaultExercise('Rear-Delt Fly (Dumbbell)', MuscleGroup.shoulders),
  DefaultExercise('Reverse Pec Deck', MuscleGroup.shoulders),
  DefaultExercise('Barbell Upright Row', MuscleGroup.shoulders),
  DefaultExercise('Machine Shoulder Press', MuscleGroup.shoulders),

  // ── Biceps ────────────────────────────────────────────────────────
  DefaultExercise('Barbell Curl', MuscleGroup.biceps),
  DefaultExercise('EZ-Bar Curl', MuscleGroup.biceps),
  DefaultExercise('Dumbbell Curl', MuscleGroup.biceps),
  DefaultExercise('Hammer Curl', MuscleGroup.biceps),
  DefaultExercise('Incline Dumbbell Curl', MuscleGroup.biceps),
  DefaultExercise('Preacher Curl', MuscleGroup.biceps),
  DefaultExercise('Cable Curl', MuscleGroup.biceps),
  DefaultExercise('Concentration Curl', MuscleGroup.biceps),

  // ── Triceps ───────────────────────────────────────────────────────
  DefaultExercise('Close-Grip Bench Press', MuscleGroup.triceps),
  DefaultExercise(
      'Dips (Triceps)', MuscleGroup.triceps, MeasurementType.repsBodyweight),
  DefaultExercise('Triceps Pushdown (Cable)', MuscleGroup.triceps),
  DefaultExercise('Rope Pushdown', MuscleGroup.triceps),
  DefaultExercise('Overhead Cable Triceps Extension', MuscleGroup.triceps),
  DefaultExercise('Skull Crusher (EZ-Bar)', MuscleGroup.triceps),
  DefaultExercise('Dumbbell Overhead Extension', MuscleGroup.triceps),
  DefaultExercise('Triceps Kickback', MuscleGroup.triceps),
  DefaultExercise('JM Press', MuscleGroup.triceps),

  // ── Abs / Core ────────────────────────────────────────────────────
  DefaultExercise('Plank', MuscleGroup.abs, MeasurementType.time),
  DefaultExercise('Side Plank', MuscleGroup.abs, MeasurementType.time),
  DefaultExercise('Hollow Hold', MuscleGroup.abs, MeasurementType.time),
  DefaultExercise('Hanging Leg Raise', MuscleGroup.abs,
      MeasurementType.repsBodyweight),
  DefaultExercise('Hanging Knee Raise', MuscleGroup.abs,
      MeasurementType.repsBodyweight),
  DefaultExercise('Ab Wheel Rollout', MuscleGroup.abs,
      MeasurementType.repsBodyweight),
  DefaultExercise('Decline Sit-up', MuscleGroup.abs,
      MeasurementType.repsBodyweight),
  DefaultExercise('Dead Bug', MuscleGroup.abs, MeasurementType.repsBodyweight),
  DefaultExercise('Cable Crunch', MuscleGroup.abs),
  DefaultExercise('Weighted Russian Twist', MuscleGroup.abs),

  // ── Other (carries, cardio, conditioning) ─────────────────────────
  DefaultExercise(
      "Farmer's Walk", MuscleGroup.other, MeasurementType.weightTime),
  DefaultExercise(
      'Suitcase Carry', MuscleGroup.other, MeasurementType.weightTime),
  DefaultExercise('Sled Push', MuscleGroup.other, MeasurementType.weightTime),
  DefaultExercise('Sled Drag', MuscleGroup.other, MeasurementType.weightTime),
  DefaultExercise('Dead Hang', MuscleGroup.other, MeasurementType.time),
  DefaultExercise(
      'Weighted Dead Hang', MuscleGroup.other, MeasurementType.weightTime),
  DefaultExercise(
      'Running', MuscleGroup.other, MeasurementType.distanceTime),
  DefaultExercise(
      'Treadmill', MuscleGroup.other, MeasurementType.distanceTime),
  DefaultExercise(
      'Rowing (Erg)', MuscleGroup.other, MeasurementType.distanceTime),
  DefaultExercise(
      'Assault Bike', MuscleGroup.other, MeasurementType.distanceTime),
  DefaultExercise('Cycling', MuscleGroup.other, MeasurementType.distanceTime),
  DefaultExercise('Jump Rope', MuscleGroup.other, MeasurementType.time),
  DefaultExercise('Stair Climber', MuscleGroup.other, MeasurementType.time),
];
