import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/models/Task.dart';
import '../bloc/task_bloc.dart';
import '../bloc/task_event.dart';
import '../bloc/task_state.dart';
import '../widgets/task_list_section.dart';
import 'task_edit_screen.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: BlocListener<TaskBloc, TaskState>(
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newTask = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TaskEditScreen()),
          );
          if (newTask != null && newTask is Task) {
            context.read<TaskBloc>().add(AddTask(newTask));
          }
        },
        backgroundColor: const Color(0xFF3498DB),
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Add Task',
      ),
    );
  }

  Widget _buildContent(BuildContext context, TaskState state) {
    if (state is TasksLoading) {
      return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3498DB))));
    } else if (state is TasksLoaded) {
      final allTasks = state.tasks;
      final activeTasks = allTasks.where((t) => !t.isCompleted).toList()
        ..sort((a, b) => (a.pageOrder['all_tasks'] ?? a.order).compareTo(b.pageOrder['all_tasks'] ?? b.order));
      final completedTasks = allTasks.where((t) => t.isCompleted).toList()
        ..sort((a, b) => (a.pageOrder['all_tasks'] ?? a.order).compareTo(b.pageOrder['all_tasks'] ?? b.order));

      return CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [Color(0xFF3498DB), Color(0xFF2980B9)]),
                    ),
                    child: const Icon(Icons.task_rounded, color: Colors.white, size: 36),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'All Tasks',
                      style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w700, color: const Color(0xFF3498DB)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (activeTasks.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              sliver: SliverToBoxAdapter(
                child: TaskListSection(
                  tasks: activeTasks,
                  title: 'Active Tasks',
                  icon: Icons.list_alt_outlined,
                  color: const Color(0xFF3498DB),
                  pageId: 'all_tasks',
                ),
              ),
            ),
          if (completedTasks.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              sliver: SliverToBoxAdapter(
                child: TaskListSection(
                  tasks: completedTasks,
                  title: 'Completed Tasks',
                  icon: Icons.check_circle_rounded,
                  color: const Color(0xFF2ECC71),
                  pageId: 'all_tasks',
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      );
    } else if (state is TasksEmpty) {
      return CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [Color(0xFF3498DB), Color(0xFF2980B9)]),
                    ),
                    child: const Icon(Icons.task_rounded, color: Colors.white, size: 36),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'All Tasks',
                      style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w700, color: const Color(0xFF3498DB)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverFillRemaining(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [Color(0xFF3498DB), Color(0xFF2980B9)]),
                    boxShadow: [BoxShadow(color: const Color(0xFF3498DB).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: const Icon(Icons.task_alt_rounded, size: 80, color: Colors.white),
                ),
                const SizedBox(height: 24),
                Text('No tasks yet!', style: GoogleFonts.poppins(fontSize: 20, color: const Color(0xFFE74C3C), fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Add tasks to keep track of everything!',
                    style: GoogleFonts.poppins(fontSize: 16, color: const Color(0xFF3498DB), fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else if (state is TaskError) {
      return Center(child: Text('Error: ${state.message}', style: GoogleFonts.poppins(fontSize: 18, color: const Color(0xFFE74C3C), fontWeight: FontWeight.w500)));
    }
    return const SizedBox.shrink();
  }
}