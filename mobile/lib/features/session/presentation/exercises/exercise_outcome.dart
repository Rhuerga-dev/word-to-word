/// Cómo terminó un ejercicio: puntos ganados y, si era una ficha con nota, si salió bien.
class ExerciseOutcome {
  const ExerciseOutcome({this.xp = 0, this.graded = false, this.ok = true});
  final int xp;
  final bool graded, ok;

  static const skipped = ExerciseOutcome();
}
