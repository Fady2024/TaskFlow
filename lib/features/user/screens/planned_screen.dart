import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/models/Task.dart';
import '../../../core/widgets/common_header.dart';
import '../../task/bloc/task_bloc.dart';
import '../../task/bloc/task_event.dart';
import '../../task/bloc/task_state.dart';
import '../../task/widgets/task_list_section.dart';

class PlannedScreen extends StatelessWidget {
  const PlannedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
    );
  }

  Widget _buildContent(BuildContext context, TaskState state) {
    if (state is TasksLoading) {
      return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3498DB))));
    } else if (state is TasksLoaded) {
      final plannedTasks = state.tasks.where((t) => t.dueDate != null).toList();
      final activeTasks = plannedTasks.where((t) => !t.isCompleted).toList()
        ..sort((a, b) => (a.pageOrder['planned'] ?? a.order).compareTo(b.pageOrder['planned'] ?? b.order));
      final completedTasks = plannedTasks.where((t) => t.isCompleted).toList()
        ..sort((a, b) => (a.pageOrder['planned'] ?? a.order).compareTo(b.pageOrder['planned'] ?? b.order));

      return plannedTasks.isEmpty
          ? const PlannedEmptyContent()
          : CustomScrollView(
        slivers: [
          const CommonHeader(
            title: 'Planned',
            subtitle: 'Tasks with due dates',
            icon: Icons.calendar_today_rounded,
            gradientColors: [Color(0xFF3498DB), Color(0xFF6C5CE7)],
            titleColor: Color(0xFF3498DB),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.of(context).size.height - 200,
              child: Column(
                children: [
                  if (activeTasks.isNotEmpty)
                    TaskListSection(
                      tasks: activeTasks,
                      title: 'Active Planned',
                      icon: Icons.calendar_today_outlined,
                      color: const Color(0xFF3498DB),
                      pageId: 'planned',
                    ),
                  if (completedTasks.isNotEmpty)
                    TaskListSection(
                      tasks: completedTasks,
                      title: 'Completed Planned',
                      icon: Icons.check_circle_rounded,
                      color: const Color(0xFF2ECC71),
                      pageId: 'planned',
                    ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      );
    } else if (state is TasksEmpty) {
      return const PlannedEmptyContent();
    } else if (state is TaskError) {
      return Center(child: Text('Error: ${state.message}', style: GoogleFonts.poppins(fontSize: 18, color: const Color(0xFFE74C3C), fontWeight: FontWeight.w500)));
    }
    return const SizedBox.shrink();
  }
}

class PlannedEmptyContent extends StatelessWidget {
  const PlannedEmptyContent({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const CommonHeader(
          title: 'Planned',
          subtitle: 'Tasks with due dates',
          icon: Icons.calendar_today_rounded,
          gradientColors: [Color(0xFF3498DB), Color(0xFF6C5CE7)],
          titleColor: Color(0xFF3498DB),
        ),
        SliverFillRemaining(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [Color(0xFFE91E63), Color(0xFFFF6F61)]),
                  boxShadow: [BoxShadow(color: const Color(0xFF3498DB).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: const Icon(Icons.calendar_today_outlined, size: 80, color: Colors.white),
              ),
              const SizedBox(height: 24),
              Text('No planned tasks yet!', style: GoogleFonts.poppins(fontSize: 20, color: const Color(0xFFE74C3C), fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Add due dates to your tasks to see them here!',
                  style: GoogleFonts.poppins(fontSize: 16, color: const Color(0xFF9B59B6), fontStyle: FontStyle.italic),
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