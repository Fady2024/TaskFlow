abstract class PomodoroState {
  final int secondsRemaining;
  final int initialMinutes;
  final bool isRunning;

  PomodoroState(this.secondsRemaining, this.initialMinutes, this.isRunning);
}

class PomodoroInitial extends PomodoroState {
  PomodoroInitial(int initialMinutes)
      : super(initialMinutes * 60, initialMinutes, false);
}

class PomodoroRunning extends PomodoroState {
  PomodoroRunning(int secondsRemaining, int initialMinutes, bool isRunning)
      : super(secondsRemaining, initialMinutes, isRunning);
}

class PomodoroFinished extends PomodoroState {
  PomodoroFinished(int initialMinutes)
      : super(initialMinutes * 60, initialMinutes, false);
}