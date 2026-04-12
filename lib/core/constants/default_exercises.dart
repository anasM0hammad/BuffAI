import 'muscle_groups.dart';

class DefaultExercise {
  final String name;
  final MuscleGroup muscleGroup;

  const DefaultExercise(this.name, this.muscleGroup);
}

const List<DefaultExercise> defaultExercises = [
  // Chest
  DefaultExercise('Chest Press (Machine)', MuscleGroup.chest),
  DefaultExercise('Incline Chest Press', MuscleGroup.chest),
  DefaultExercise('Pec Deck / Fly', MuscleGroup.chest),
  DefaultExercise('Cable Crossover', MuscleGroup.chest),

  // Back
  DefaultExercise('Lat Pulldown', MuscleGroup.back),
  DefaultExercise('Seated Cable Row', MuscleGroup.back),
  DefaultExercise('T-Bar Row', MuscleGroup.back),
  DefaultExercise('Deadlift', MuscleGroup.back),

  // Legs
  DefaultExercise('Leg Press', MuscleGroup.legs),
  DefaultExercise('Leg Extension', MuscleGroup.legs),
  DefaultExercise('Leg Curl', MuscleGroup.legs),
  DefaultExercise('Squat', MuscleGroup.legs),
  DefaultExercise('Calf Raise', MuscleGroup.legs),

  // Biceps
  DefaultExercise('Barbell Curl', MuscleGroup.biceps),
  DefaultExercise('Cable Curl', MuscleGroup.biceps),
  DefaultExercise('Hammer Curl', MuscleGroup.biceps),

  // Triceps
  DefaultExercise('Tricep Pushdown', MuscleGroup.triceps),
  DefaultExercise('Overhead Tricep Extension', MuscleGroup.triceps),
  DefaultExercise('Skull Crusher', MuscleGroup.triceps),

  // Shoulders
  DefaultExercise('Shoulder Press (Machine)', MuscleGroup.shoulders),
  DefaultExercise('Lateral Raise', MuscleGroup.shoulders),
  DefaultExercise('Front Raise', MuscleGroup.shoulders),

  // Abs
  DefaultExercise('Crunches', MuscleGroup.abs),
  DefaultExercise('Plank (duration)', MuscleGroup.abs),
  DefaultExercise('Hanging Leg Raise', MuscleGroup.abs),
];
