import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/models/Task.dart';
import '../../../core/widgets/task_card.dart';
import '../bloc/task_bloc.dart';
import '../bloc/task_event.dart';

class TaskListSection extends StatelessWidget {
  final List<Task> tasks;
  final String title;
  final IconData icon;
  final Color color;
  final String pageId;

  const TaskListSection({
    super.key,
    required this.tasks,
    required this.title,
    required this.icon,
    required this.color,
    required this.pageId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  softWrap: true,
                ),
              ),
            ],
          ),
        ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(),
          itemCount: tasks.length,
          itemBuilder: (context, index) => ReorderableDragStartListener(
            key: ValueKey(tasks[index].id),
            index: index,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TaskCard(
                task: tasks[index],
                showImportantToggle: pageId != 'important',
              ),
            ),
          ),
          onReorder: (oldIndex, newIndex) {
            if (newIndex > oldIndex) newIndex--;
            context.read<TaskBloc>().add(ReorderTasksOnPage(tasks, oldIndex, newIndex, pageId));
          },
          proxyDecorator: (child, index, animation) => Material(
            elevation: 8.0,
            borderRadius: BorderRadius.circular(16),
            shadowColor: Colors.grey.withOpacity(0.5),
            child: child,
          ),
        ),
      ],
    );
  }
}