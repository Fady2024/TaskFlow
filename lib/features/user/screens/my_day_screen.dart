import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../../../core/models/Task.dart';
import '../../../core/services/task_service.dart';
import '../../../core/widgets/common_header.dart';
import '../../task/bloc/task_bloc.dart';
import '../../task/bloc/task_event.dart';
import '../../task/bloc/task_state.dart';
import '../../task/screens/task_edit_screen.dart';
import '../../task/widgets/task_list_section.dart';

class MyDayScreen extends StatefulWidget {
  const MyDayScreen({super.key});

  @override
  State<MyDayScreen> createState() => _MyDayScreenState();
}

class _MyDayScreenState extends State<MyDayScreen> {
  final TaskService _taskService = TaskService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () async => context.read<TaskBloc>().add(LoadTasks()),
        child: BlocListener<TaskBloc, TaskState>(
          listener: (context, state) {
            if (state is TaskError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message, style: GoogleFonts.poppins(color: Colors.white)),
                  backgroundColor: const Color(0xFFE74C3C),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            }
          },
          child: BlocBuilder<TaskBloc, TaskState>(
            builder: (context, state) => AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
              child: _buildContent(context, state),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newTask = await Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const TaskEditScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                const begin = Offset(1.0, 0.0);
                const end = Offset.zero;
                const curve = Curves.easeInOut;
                var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                return SlideTransition(
                  position: animation.drive(tween),
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 300),
            ),
          );
          if (newTask != null && newTask is Task) {
            context.read<TaskBloc>().add(AddTask(newTask));
          }
        },
        backgroundColor: const Color(0xFFFF6F61),
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Add Task',
      ),
    );
  }

  Widget _buildContent(BuildContext context, TaskState state) {
    if (state is TasksLoading) {
      return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3498DB))));
    } else if (state is TasksLoaded) {
      final myDayTasks = state.tasks.where((t) => t.isInMyDay()).toList();
      final activeTasks = myDayTasks.where((t) => !t.isCompleted).toList()
        ..sort((a, b) => (a.pageOrder['my_day'] ?? a.order).compareTo(b.pageOrder['my_day'] ?? b.order));
      final completedTasks = myDayTasks.where((t) => t.isCompleted).toList()
        ..sort((a, b) => (a.pageOrder['my_day'] ?? a.order).compareTo(b.pageOrder['my_day'] ?? b.order));

      return myDayTasks.isEmpty
          ? const MyDayEmptyContent(key: ValueKey('empty'))
          : CustomScrollView(
        slivers: [
          const CommonHeader(
            title: 'My Day',
            subtitle: 'Tasks for today',
            icon: Icons.wb_sunny_rounded,
            gradientColors: [Color(0xFF3498DB), Color(0xFFFF6F61)],
            titleColor: Color(0xFF6C5CE7),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.of(context).size.height - 200,
              child: Column(
                children: [
                  if (activeTasks.isNotEmpty)
                    TaskListSection(
                      tasks: activeTasks,
                      title: 'Active Today',
                      icon: Icons.wb_sunny_outlined,
                      color: const Color(0xFF3498DB),
                      pageId: 'my_day',
                    ),
                  if (completedTasks.isNotEmpty)
                    TaskListSection(
                      tasks: completedTasks,
                      title: 'Completed Today',
                      icon: Icons.check_circle_rounded,
                      color: const Color(0xFF2ECC71),
                      pageId: 'my_day',
                    ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      );
    } else if (state is TasksEmpty) {
      return const MyDayEmptyContent(key: ValueKey('empty'));
    } else if (state is TaskError) {
      return Center(child: Text('Error: ${state.message}', style: GoogleFonts.poppins(fontSize: 18, color: const Color(0xFFE74C3C), fontWeight: FontWeight.w500)));
    }
    return const SizedBox.shrink();
  }
}

class MyDayEmptyContent extends StatelessWidget {
  const MyDayEmptyContent({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const CommonHeader(
          title: 'My Day',
          subtitle: 'Tasks for today',
          icon: Icons.wb_sunny_rounded,
          gradientColors: [Color(0xFF3498DB), Color(0xFFFF6F61)],
          titleColor: Color(0xFF6C5CE7),
        ),
        SliverFillRemaining(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [Color(0xFFE91E63), Color(0xFF3498DB)]),
                  boxShadow: [BoxShadow(color: const Color(0xFFFF6F61).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: const Icon(Icons.wb_sunny_rounded, size: 80, color: Colors.white),
              ),
              const SizedBox(height: 24),
              Text('Your day is clear!', style: GoogleFonts.poppins(fontSize: 20, color: const Color(0xFF6C5CE7), fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Add tasks to make the most of your day!',
                  style: GoogleFonts.poppins(fontSize: 16, color: const Color(0xFFFF6F61), fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}