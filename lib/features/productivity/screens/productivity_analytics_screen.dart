import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import '../../task/bloc/task_bloc.dart';
import '../../task/bloc/task_state.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../../core/models/Task.dart';
import '../../task/screens/task_edit_screen.dart';

class ProductivityAnalyticsScreen extends StatefulWidget {
  final String type;

  const ProductivityAnalyticsScreen({super.key, required this.type});

  @override
  State<ProductivityAnalyticsScreen> createState() => _ProductivityAnalyticsScreenState();
}

class _ProductivityAnalyticsScreenState extends State<ProductivityAnalyticsScreen> with SingleTickerProviderStateMixin {
  bool _showMessage = true;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(begin: Offset.zero, end: Offset.zero).animate(_controller);

    _controller.forward();

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _showMessage) {
        _controller.reverse().then((_) {
          setState(() {
            _showMessage = false;
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDismiss(DismissDirection direction) {
    setState(() {
      _showMessage = false;
      switch (direction) {
        case DismissDirection.up:
          _slideAnimation = Tween<Offset>(begin: Offset.zero, end: const Offset(0, -1)).animate(_controller);
          break;
        case DismissDirection.down:
          _slideAnimation = Tween<Offset>(begin: Offset.zero, end: const Offset(0, 1)).animate(_controller);
          break;
        case DismissDirection.startToEnd:
          _slideAnimation = Tween<Offset>(begin: Offset.zero, end: const Offset(1, 0)).animate(_controller);
          break;
        case DismissDirection.endToStart:
          _slideAnimation = Tween<Offset>(begin: Offset.zero, end: const Offset(-1, 0)).animate(_controller);
          break;
        default:
          break;
      }
      _controller.reset();
      _controller.forward();
    });
  }

  static const List<String> _encouragingMessages = [
    "You're crushing it! Keep the momentum going!",
    "Amazing progress! The sky's the limit!",
    "Wow, you're unstoppable! Keep shining!",
    "Fantastic work! Your productivity is on fire!",
    "You're a task-master! Keep rocking it!",
    "Incredible effort! Success is yours!",
    "You're making waves! Keep it up!",
  ];

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.themeMode == ThemeMode.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1A2338), const Color(0xFF2E3B5A)]
                : [const Color(0xFFEFF2F7), const Color(0xFFDCE3F0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(25.0),
                child: BlocBuilder<TaskBloc, TaskState>(
                  builder: (context, state) {
                    final tasks = state is TasksLoaded ? state.tasks : <Task>[];
                    if (tasks.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.task_alt,
                              size: 80,
                              color: isDark ? Colors.blueGrey.shade300 : Colors.blueGrey.shade500,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'No tasks yet!',
                              style: GoogleFonts.poppins(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF1E3A8A),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Add some tasks to see your productivity stats.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: isDark ? Colors.blueGrey.shade200 : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const TaskEditScreen()),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? const Color(0xFF3B82F6) : const Color(0xFF60A5FA),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                elevation: 5,
                              ),
                              child: Text(
                                'Add a Task',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final completedTasks = tasks.where((t) => t.isCompleted).length;
                    final totalTasks = tasks.length;
                    final completionRate = totalTasks > 0 ? (completedTasks / totalTasks * 100) : 0.0;

                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: isDark
                                  ? [const Color(0xFF60A5FA), const Color(0xFF34D399)]
                                  : [const Color(0xFF3B82F6), const Color(0xFF10B981)],
                            ).createShader(bounds),
                            child: Text(
                              widget.type == 'completion'
                                  ? 'Task Completion Rate'
                                  : widget.type == 'progress'
                                  ? 'Daily/Weekly Progress'
                                  : 'Productivity Overview',
                              style: GoogleFonts.poppins(
                                fontSize: 34,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: isDark ? Colors.black.withOpacity(0.5) : Colors.grey.withOpacity(0.3),
                                    offset: const Offset(2, 2),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          if (widget.type == 'completion' || widget.type == 'overview')
                            _buildCompletionCard(
                              isDark: isDark,
                              completionRate: completionRate,
                              completedTasks: completedTasks,
                              totalTasks: totalTasks,
                            ),
                          if (widget.type == 'progress' || widget.type == 'overview')
                            _buildProgressCard(
                              isDark: isDark,
                              tasks: tasks,
                            ),
                          const SizedBox(height: 20),
                          if (widget.type == 'progress' || widget.type == 'overview')
                            _buildWeeklyOverviewCard(
                              isDark: isDark,
                              tasks: tasks,
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            if (_showMessage)
              Positioned(
                top: 80,
                left: 25,
                right: 25,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Dismissible(
                      key: const Key('encouraging_message'),
                      onDismissed: _handleDismiss,
                      direction: DismissDirection.horizontal,
                      child: _buildEncouragingMessage(isDark: isDark),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEncouragingMessage({required bool isDark}) {
    final randomMessage = _encouragingMessages[math.Random().nextInt(_encouragingMessages.length)];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF34D399).withOpacity(0.2), const Color(0xFF60A5FA).withOpacity(0.2)]
              : [const Color(0xFF10B981).withOpacity(0.2), const Color(0xFF3B82F6).withOpacity(0.2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.star,
            color: isDark ? const Color(0xFFFFD700) : const Color(0xFFFFA500),
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              randomMessage,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1E3A8A),
                shadows: [
                  Shadow(
                    color: isDark ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
                    offset: const Offset(1, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        ],
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
            child: TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: completionRate / 100),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeInOut,
              builder: (context, value, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(250, 250),
                      painter: CircularProgressPainter(
                        progress: value,
                        backgroundColor: isDark ? Colors.blueGrey.shade700 : Colors.grey.shade200,
                        progressColor: isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6),
                        strokeWidth: 20,
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${(value * 100).toStringAsFixed(1)}%',
                          style: GoogleFonts.poppins(
                            fontSize: 50,
                            fontWeight: FontWeight.bold,                            color: isDark ? Colors.white : const Color(0xFF1E3A8A),
                            shadows: [
                              Shadow(
                                color: isDark ? Colors.black54 : Colors.grey.shade300,
                                blurRadius: 4,
                                offset: const Offset(1, 1),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '$completedTasks/$totalTasks Tasks',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: isDark ? Colors.blueGrey.shade200 : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
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
        .where((task) =>
    task.isCompleted &&
        task.completedDate != null &&
        task.completedDate!.isAfter(todayStart) &&
        task.completedDate!.isBefore(todayEnd))
        .length;

    final currentDayOfWeek = now.weekday;
    final mondayOfThisWeek = now.subtract(Duration(days: currentDayOfWeek - 1));
    final startOfWeek = DateTime(mondayOfThisWeek.year, mondayOfThisWeek.month, mondayOfThisWeek.day);
    final endOfWeek = startOfWeek.add(const Duration(days: 7));
    final weeklyCompletedTasks = tasks
        .where((task) =>
    task.isCompleted &&
        task.completedDate != null &&
        task.completedDate!.isAfter(startOfWeek) &&
        task.completedDate!.isBefore(endOfWeek))
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
              color: isDark ? Colors.white : const Color(0xFF1E3A8A),
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
          .where((task) =>
      task.isCompleted &&
          task.completedDate != null &&
          task.completedDate!.isAfter(dayStart) &&
          task.completedDate!.isBefore(dayEnd))
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
              color: isDark ? Colors.white : const Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
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
              ? [const Color(0xFF1E2A47), const Color(0xFF2D3B5E)]
              : [Colors.white, const Color(0xFFF1F5F9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.4) : Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            title == 'Daily' ? Icons.today : Icons.calendar_today,
            color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1E3A8A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: isDark ? Colors.blueGrey.shade200 : const Color(0xFF64748B),
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
          height: tasks > 0 ? math.max(tasks * 12.0, 15) : 15,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF60A5FA), const Color(0xFF34D399)]
                  : [const Color(0xFF3B82F6), const Color(0xFF10B981)],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black54 : Colors.grey.shade300,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          day,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF1E3A8A),
          ),
        ),
        Text(
          '$tasks',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: isDark ? Colors.blueGrey.shade200 : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required bool isDark, required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.blueGrey.shade900.withOpacity(0.3)
            : Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.5) : Colors.grey.shade300,
            blurRadius: 15,
            offset: const Offset(4, 4),
          ),
          BoxShadow(
            color: isDark ? Colors.blueGrey.shade800.withOpacity(0.2) : Colors.white,
            blurRadius: 15,
            offset: const Offset(-4, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: child,
        ),
      ),
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
      ..shader = LinearGradient(
        colors: [progressColor, progressColor.withOpacity(0.7)],
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
        ..color = Colors.white.withOpacity(0.9)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(endPoint, strokeWidth / 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}