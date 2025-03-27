import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:audioplayers/audioplayers.dart';
import 'pomodoro_event.dart';
import 'pomodoro_state.dart';

class PomodoroBloc extends Bloc<PomodoroEvent, PomodoroState> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _timer;

  PomodoroBloc() : super(PomodoroInitial(25)) {
    on<StartPomodoro>(_onStartPomodoro);
    on<PausePomodoro>(_onPausePomodoro);
    on<ResetPomodoro>(_onResetPomodoro);
    on<TickPomodoro>(_onTickPomodoro);
    on<SetPomodoroDuration>(_onSetPomodoroDuration);
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _audioPlayer.dispose();
    return super.close();
  }

  void _onStartPomodoro(StartPomodoro event, Emitter<PomodoroState> emit) {
    if (!state.isRunning) {
      _timer?.cancel();
      emit(PomodoroRunning(event.seconds, state.initialMinutes, true));
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (state.secondsRemaining > 0) {
          add(TickPomodoro(state.secondsRemaining - 1));
        } else {
          _timer?.cancel();
          _playSound();
          emit(PomodoroFinished(state.initialMinutes));
        }
      });
    }
  }

  void _onPausePomodoro(PausePomodoro event, Emitter<PomodoroState> emit) {
    _timer?.cancel();
    emit(PomodoroRunning(state.secondsRemaining, state.initialMinutes, false));
  }

  void _onResetPomodoro(ResetPomodoro event, Emitter<PomodoroState> emit) {
    _timer?.cancel();
    emit(PomodoroInitial(state.initialMinutes));
  }

  void _onTickPomodoro(TickPomodoro event, Emitter<PomodoroState> emit) {
    emit(PomodoroRunning(event.secondsRemaining, state.initialMinutes, true));
  }

  void _onSetPomodoroDuration(SetPomodoroDuration event, Emitter<PomodoroState> emit) {
    _timer?.cancel();
    emit(PomodoroInitial(event.minutes));
  }

  Future<void> _playSound() async {
    await _audioPlayer.play(AssetSource('sounds/pomodoro_end.mp3'));
  }
}