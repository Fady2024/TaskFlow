abstract class PomodoroEvent {}

class StartPomodoro extends PomodoroEvent {
  final int seconds;
  StartPomodoro(this.seconds);
}

class PausePomodoro extends PomodoroEvent {}

class ResetPomodoro extends PomodoroEvent {}

class TickPomodoro extends PomodoroEvent {
  final int secondsRemaining;
  TickPomodoro(this.secondsRemaining);
}

class SetPomodoroDuration extends PomodoroEvent {
  final int minutes;
  SetPomodoroDuration(this.minutes);
}