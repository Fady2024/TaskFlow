import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timezone/timezone.dart' as tz;
import '../blocs/task/task_bloc.dart';
import '../blocs/task/task_event.dart';
import '../blocs/task/task_state.dart';
import '../models/task.dart';
import '../widgets/task_card.dart';
import 'task_edit_screen.dart';
import 'task_list_section.dart';

class TaskListScreen extends StatefulWidget {
  final String listId;
  final String listName;
  final VoidCallback? onDelete;

  const TaskListScreen({
    super.key,
    required this.listId,
    required this.listName,
    this.onDelete,
  });

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  String _sortBy = 'Manual';

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
          builder: (context, state) {
            print('TaskListScreen state: $state');
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
              child: _buildContent(context, state),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => TaskEditScreen(listId: widget.listId)),
          );
          if (result is Task) context.read<TaskBloc>().add(AddTask(result));
        },
        backgroundColor: const Color(0xFF9B59B6),
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Add Task',
      ),
    );
  }

  Widget _buildContent(BuildContext context, TaskState state) {
    print('Building content for listId: ${widget.listId}, state: $state');

    if (state is TasksLoading) {
      return const Center(
        key: ValueKey('loading'),
        child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9B59B6))),
      );
    } else if (state is TasksLoaded) {
      final listTasks = state.tasks.where((t) => t.listId == widget.listId).toList();
      print('Tasks for listId ${widget.listId}: ${listTasks.length} tasks');

      if (listTasks.isEmpty) {
        return TaskListEmptyContent(
          key: ValueKey('empty'),
          listName: widget.listName,
          onDelete: widget.onDelete,
        );
      }

      if (_sortBy != 'Manual') {
        listTasks.sort((a, b) => _sortBy == 'Due Date'
            ? (a.dueDate ?? DateTime(9999)).compareTo(b.dueDate ?? DateTime(9999))
            : a.title.compareTo(b.title));
      }
      final activeTasks = listTasks.where((t) => !t.isCompleted).toList()
        ..sort((a, b) => (a.pageOrder[widget.listId] ?? a.order).compareTo(b.pageOrder[widget.listId] ?? b.order));
      final completedTasks = listTasks.where((t) => t.isCompleted).toList()
        ..sort((a, b) => (a.pageOrder[widget.listId] ?? a.order).compareTo(b.pageOrder[widget.listId] ?? b.order));

      return CustomScrollView(
        key: ValueKey('loaded_${listTasks.length}'),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            sliver: SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [Color(0xFF9B59B6), Color(0xFFE91E63)]),
                        ),
                        child: const Icon(Icons.list_rounded, color: Colors.white, size: 36),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.listName,
                              style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w700, color: const Color(0xFF9B59B6))),
                          DropdownButton<String>(
                            value: _sortBy,
                            items: ['Manual', 'Due Date', 'Alphabetical']
                                .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                                .toList(),
                            onChanged: (value) => setState(() => _sortBy = value!),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (widget.onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Color(0xFFE74C3C)),
                      onPressed: widget.onDelete,
                      tooltip: 'Delete List',
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.of(context).size.height - 200,
              child: _sortBy == 'Manual'
                  ? Column(
                children: [
                  if (activeTasks.isNotEmpty)
                    TaskListSection(
                      tasks: activeTasks,
                      title: 'Active Tasks',
                      icon: Icons.list_alt_outlined,
                      color: const Color(0xFF9B59B6),
                      pageId: widget.listId,
                    ),
                  if (completedTasks.isNotEmpty)
                    TaskListSection(
                      tasks: completedTasks,
                      title: 'Completed Tasks',
                      icon: Icons.check_circle_rounded,
                      color: const Color(0xFF2ECC71),
                      pageId: widget.listId,
                    ),
                ],
              )
                  : ListView.builder(
                itemCount: listTasks.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TaskCard(task: listTasks[index]),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      );
    } else if (state is TasksEmpty) {
      return TaskListEmptyContent(
        key: ValueKey('empty'),
        listName: widget.listName,
        onDelete: widget.onDelete,
      );
    } else if (state is TaskError) {
      return Center(
        key: ValueKey('error'),
        child: Text('Error: ${state.message}',
            style: GoogleFonts.poppins(fontSize: 18, color: const Color(0xFFE74C3C), fontWeight: FontWeight.w500)),
      );
    }
    return Center(
      key: const ValueKey('unknown'),
      child: Text('Loading...', style: GoogleFonts.poppins(fontSize: 18)),
    );
  }
}

class TaskListEmptyContent extends StatelessWidget {
  final String listName;
  final VoidCallback? onDelete;

  const TaskListEmptyContent({super.key, required this.listName, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 0),
          sliver: SliverToBoxAdapter(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [Color(0xFF9B59B6), Color(0xFFE91E63)]),
                      ),
                      child: const Icon(Icons.list_rounded, color: Colors.white, size: 36),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      listName,
                      style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w700, color: const Color(0xFF9B59B6)),
                    ),
                  ],
                ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Color(0xFFE74C3C)),
                    onPressed: onDelete,
                    tooltip: 'Delete List',
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
                  gradient: const LinearGradient(colors: [Color(0xFF9B59B6), Color(0xFFE91E63)]),
                  boxShadow: [BoxShadow(color: const Color(0xFF9B59B6).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: const Icon(Icons.list_alt_outlined, size: 80, color: Colors.white),
              ),
              const SizedBox(height: 24),
              Text('No tasks in $listName yet!',
                  style: GoogleFonts.poppins(fontSize: 20, color: const Color(0xFFE74C3C), fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Add tasks to this list to see them here!',
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