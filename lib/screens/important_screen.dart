import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/common_header.dart';
import '../blocs/task/task_bloc.dart';
import '../blocs/task/task_event.dart';
import '../blocs/task/task_state.dart';
import '../models/task.dart';
import 'task_list_section.dart';

class ImportantScreen extends StatelessWidget {
  const ImportantScreen({super.key});

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
    );
  }

  Widget _buildContent(BuildContext context, TaskState state) {
    if (state is TasksLoading) {
      return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE74C3C))));
    } else if (state is TasksLoaded) {
      final importantTasks = state.tasks.where((t) => t.isImportant).toList();
      final activeTasks = importantTasks.where((t) => !t.isCompleted).toList()
        ..sort((a, b) => (a.pageOrder['important'] ?? a.order).compareTo(b.pageOrder['important'] ?? b.order));
      final completedTasks = importantTasks.where((t) => t.isCompleted).toList()
        ..sort((a, b) => (a.pageOrder['important'] ?? a.order).compareTo(b.pageOrder['important'] ?? b.order));

      return importantTasks.isEmpty
          ? const ImportantEmptyContent()
          : CustomScrollView(
        slivers: [
          const CommonHeader(
            title: 'Important',
            subtitle: 'Your starred tasks',
            icon: Icons.star_rounded,
            gradientColors: [Color(0xFFE74C3C), Color(0xFFFF6F61)],
            titleColor: Color(0xFFE74C3C),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.of(context).size.height - 200,
              child: Column(
                children: [
                  if (activeTasks.isNotEmpty)
                    TaskListSection(
                      tasks: activeTasks,
                      title: 'Active Important',
                      icon: Icons.star_border_rounded,
                      color: const Color(0xFFE74C3C),
                      pageId: 'important',
                    ),
                  if (completedTasks.isNotEmpty)
                    TaskListSection(
                      tasks: completedTasks,
                      title: 'Completed Important',
                      icon: Icons.check_circle_rounded,
                      color: const Color(0xFF2ECC71),
                      pageId: 'important',
                    ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      );
    } else if (state is TasksEmpty) {
      return const ImportantEmptyContent();
    } else if (state is TaskError) {
      return Center(child: Text('Error: ${state.message}', style: GoogleFonts.poppins(fontSize: 18, color: const Color(0xFFE74C3C), fontWeight: FontWeight.w500)));
    }
    return const SizedBox.shrink();
  }
}

class ImportantEmptyContent extends StatelessWidget {
  const ImportantEmptyContent({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const CommonHeader(
          title: 'Important',
          subtitle: 'Your starred tasks',
          icon: Icons.star_rounded,
          gradientColors: [Color(0xFFE74C3C), Color(0xFFFF6F61)],
          titleColor: Color(0xFFE74C3C),
        ),
        SliverFillRemaining(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [Color(0xFF9B59B6), Color(0xFF3498DB)]),
                  boxShadow: [BoxShadow(color: const Color(0xFFE74C3C).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: const Icon(Icons.star_border_rounded, size: 80, color: Colors.white),
              ),
              const SizedBox(height: 24),
              Text('No important tasks yet!', style: GoogleFonts.poppins(fontSize: 20, color: const Color(0xFFE91E63), fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Mark tasks as important to see them here!',
                  style: GoogleFonts.poppins(fontSize: 16, color: const Color(0xFF6C5CE7), fontStyle: FontStyle.italic),
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