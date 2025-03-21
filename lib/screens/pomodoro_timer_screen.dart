import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/pomodoro/pomodoro_bloc.dart';
import '../blocs/pomodoro/pomodoro_event.dart';
import '../blocs/pomodoro/pomodoro_state.dart';
import '../theme_provider.dart';
import 'package:provider/provider.dart';

class PomodoroTimerScreen extends StatefulWidget {
  const PomodoroTimerScreen({super.key});

  @override
  State<PomodoroTimerScreen> createState() => _PomodoroTimerScreenState();
}

class _PomodoroTimerScreenState extends State<PomodoroTimerScreen> {
  late TextEditingController _minutesController;

  @override
  void initState() {
    super.initState();
    final currentState = context.read<PomodoroBloc>().state;
    _minutesController =
        TextEditingController(text: currentState.initialMinutes.toString());
  }

  @override
  void dispose() {
    _minutesController.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.themeMode == ThemeMode.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1F2A44), const Color(0xFF2A3756)]
                : [const Color(0xFFF5F6F5), const Color(0xFFE5E7EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: BlocBuilder<PomodoroBloc, PomodoroState>(
              builder: (context, state) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Pomodoro Timer',
                      style: GoogleFonts.poppins(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        foreground: Paint()
                          ..shader = const LinearGradient(
                            colors: [Color(0xFF6C5CE7), Color(0xFF00B4D8)],
                          ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
                      ),
                    ),
                    const SizedBox(height: 50),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? const Color(0xFF2A3756)
                            : const Color(0xFFF5F6F5),
                        boxShadow: [
                          BoxShadow(
                            color:
                            isDark ? Colors.black54 : Colors.grey.shade300,
                            offset: const Offset(5, 5),
                            blurRadius: 15,
                          ),
                          BoxShadow(
                            color: isDark
                                ? const Color(0xFF3B4A6A)
                                : Colors.white,
                            offset: const Offset(-5, -5),
                            blurRadius: 15,
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            height: 220,
                            width: 220,
                            child: CircularProgressIndicator(
                              value: state.secondsRemaining /
                                  (state.initialMinutes * 60),
                              strokeWidth: 12,
                              backgroundColor: isDark
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade200,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF6C5CE7)),
                            ),
                          ),
                          Text(
                            _formatTime(state.secondsRemaining),
                            style: GoogleFonts.poppins(
                              fontSize: 56,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF2D3436),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 50),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 140,
                          child: TextField(
                            controller: _minutesController,
                            keyboardType: TextInputType.number,
                            enabled: !state.isRunning,
                            decoration: InputDecoration(
                              labelText: 'Set Minutes',
                              labelStyle: GoogleFonts.poppins(
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20)),
                              filled: true,
                              fillColor:
                              isDark ? const Color(0xFF2A3756) : Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 15),
                            ),
                            style: GoogleFonts.poppins(
                                fontSize: 18,
                                color: isDark ? Colors.white : Colors.black),
                          ),
                        ),
                        const SizedBox(width: 20),
                        GestureDetector(
                          onTap: state.isRunning
                              ? null
                              : () {
                            final inputMinutes =
                            int.tryParse(_minutesController.text);
                            if (inputMinutes != null && inputMinutes > 0) {
                              context.read<PomodoroBloc>().add(
                                  SetPomodoroDuration(inputMinutes));
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Please enter a valid number of minutes',
                                        style: GoogleFonts.poppins())),
                              );
                              _minutesController.text =
                                  state.initialMinutes.toString();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 25, vertical: 15),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [Color(0xFF6C5CE7), Color(0xFF00B4D8)]),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5)),
                              ],
                            ),
                            child: Text(
                              'Set',
                              style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 50),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildGradientButton(
                          text: state.isRunning ? 'Pause' : 'Start',
                          onTap: () {
                            if (state.isRunning) {
                              context.read<PomodoroBloc>().add(PausePomodoro());
                            } else {
                              context.read<PomodoroBloc>().add(StartPomodoro(
                                  state.secondsRemaining));
                            }
                          },
                          colors: const [Color(0xFF00B4D8), Color(0xFF6C5CE7)],
                        ),
                        const SizedBox(width: 20),
                        _buildGradientButton(
                          text: 'Reset',
                          onTap: () => context
                              .read<PomodoroBloc>()
                              .add(ResetPomodoro()),
                          colors: const [Color(0xFFE74C3C), Color(0xFFFF6F61)],
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradientButton(
      {required String text,
        required VoidCallback onTap,
        required List<Color> colors}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 5))
          ],
        ),
        child: Text(
          text,
          style: GoogleFonts.poppins(
              fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}