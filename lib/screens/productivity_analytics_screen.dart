import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import '../blocs/task/task_bloc.dart';
import '../blocs/task/task_state.dart';
import '../theme_provider.dart';
import '../models/task.dart';
import 'dart:math' as math;


class ProductivityAnalyticsScreen extends StatelessWidget {
  final String type;

  const ProductivityAnalyticsScreen({super.key, required this.type});

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
            child: BlocBuilder<TaskBloc, TaskState>(
              builder: (context, state) {
                if (state is TasksLoaded) {
                  final tasks = state.tasks;
                  final completedTasks = tasks.where((t) => t.isCompleted).length;
                  final totalTasks = tasks.length;
                  final completionRate = totalTasks > 0 ? (completedTasks / totalTasks * 100) : 0.0;

                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFF6C5CE7), Color(0xFF00B4D8)],
                          ).createShader(bounds),
                          child: Text(
                            type == 'completion'
                                ? 'Task Completion Rate'
                                : type == 'progress'
                                ? 'Daily/Weekly Progress'
                                : 'Productivity Overview',
                            style: GoogleFonts.poppins(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        if (type == 'completion' || type == 'overview')
                          _buildCompletionCard(
                            isDark: isDark,
                            completionRate: completionRate,
                            completedTasks: completedTasks,
                            totalTasks: totalTasks,
                          ),
                        if (type == 'progress' || type == 'overview')
                          _buildProgressCard(
                            isDark: isDark,
                            tasks: tasks,
                          ),
                        const SizedBox(height: 20),
                        if (type == 'progress' || type == 'overview')
                          _buildWeeklyOverviewCard(
                            isDark: isDark,
                            tasks: tasks,
                          ),
                      ],
                    ),
                  );
                }
                return const Center(child: CircularProgressIndicator());
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompletionCard({
    required bool isDark,
    required double completionRate,
    required int completedTasks,
    required int totalTasks,
  }) {
    return _buildCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 300,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(250, 250),
                  painter: CircularProgressPainter(
                    progress: completionRate / 100,
                    backgroundColor: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                    progressColor: const Color(0xFF6C5CE7),
                    strokeWidth: 20,
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${completionRate.toStringAsFixed(1)}%',
                      style: GoogleFonts.poppins(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF2D3436),
                      ),
                    ),
                    Text(
                      '$completedTasks/$totalTasks Tasks',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: isDark ? Colors.grey.shade300 : const Color(0xFF7A869A),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard({
    required bool isDark,
    required List<Task> tasks,
  }) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final dailyCompletedTasks = tasks
        .where((task) {
      if (!task.isCompleted || task.completedDate == null) {
        return false;
      }
      return task.completedDate!.isAfter(todayStart) &&
          task.completedDate!.isBefore(todayEnd);
    })
        .length;

    final currentDayOfWeek = now.weekday;
    final mondayOfThisWeek = now.subtract(Duration(days: currentDayOfWeek - 1));
    final startOfWeek = DateTime(mondayOfThisWeek.year, mondayOfThisWeek.month, mondayOfThisWeek.day);
    final endOfWeek = startOfWeek.add(const Duration(days: 7));
    final weeklyCompletedTasks = tasks
        .where((task) {
      if (!task.isCompleted || task.completedDate == null) {
        return false;
      }
      return task.completedDate!.isAfter(startOfWeek) &&
          task.completedDate!.isBefore(endOfWeek);
    })
        .length;

    return _buildCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Progress Report',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF2D3436),
            ),
          ),
          const SizedBox(height: 20),
          _buildProgressTile(
            isDark: isDark,
            title: 'Daily',
            value: '$dailyCompletedTasks tasks completed today',
          ),
          const SizedBox(height: 15),
          _buildProgressTile(
            isDark: isDark,
            title: 'Weekly',
            value: '$weeklyCompletedTasks tasks completed this week',
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyOverviewCard({
    required bool isDark,
    required List<Task> tasks,
  }) {
    final now = DateTime.now();
    final currentDayOfWeek = now.weekday;
    final mondayOfThisWeek = now.subtract(Duration(days: currentDayOfWeek - 1));
    final startOfWeek = DateTime(mondayOfThisWeek.year, mondayOfThisWeek.month, mondayOfThisWeek.day);

    final List<int> tasksPerDay = List.generate(7, (index) {
      final dayStart = startOfWeek.add(Duration(days: index));
      final dayEnd = dayStart.add(const Duration(days: 1));

      return tasks
          .where((task) {
        if (!task.isCompleted || task.completedDate == null) {
          return false;
        }
        return task.completedDate!.isAfter(dayStart) &&
            task.completedDate!.isBefore(dayEnd);
      })
          .length;
    });

    return _buildCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly Overview',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF2D3436),
            ),
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: _buildDayTile(
                    isDark: isDark,
                    day: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][index],
                    tasks: tasksPerDay[index],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressTile({
    required bool isDark,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF2A3756), const Color(0xFF3B4A6A)]
              : [Colors.white, Colors.grey.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black54 : Colors.grey.shade200,
            blurRadius: 5,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF2D3436),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: isDark ? Colors.grey.shade300 : const Color(0xFF7A869A),
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayTile({
    required bool isDark,
    required String day,
    required int tasks,
  }) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF6C5CE7), Color(0xFF00B4D8)],
            ),
          ),
          child: Center(
            child: Text(
              day[0],
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '$tasks',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: isDark ? Colors.grey.shade300 : const Color(0xFF7A869A),
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required bool isDark, required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A3756) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black54 : Colors.grey.shade200,
            blurRadius: 15,
            offset: const Offset(5, 5),
          ),
          BoxShadow(
            color: isDark ? const Color(0xFF3B4A6A) : Colors.white,
            blurRadius: 15,
            offset: const Offset(-5, -5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color progressColor;
  final double strokeWidth;

  CircularProgressPainter({
    required this.progress,
    required this.backgroundColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - strokeWidth / 2;

    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, backgroundPaint);

    final progressPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF6C5CE7), Color(0xFF00B4D8)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );

    if (progress > 0 && progress < 1) {
      final angle = -math.pi / 2 + sweepAngle;
      final endPoint = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      final dotPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(endPoint, strokeWidth / 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}