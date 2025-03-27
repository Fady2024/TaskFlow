import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../features/task/bloc/task_bloc.dart';
import '../../features/task/bloc/task_event.dart';
import '../models/Task.dart';
import '../../features/task/screens/task_edit_screen.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback? onToggleMyDay;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleComplete;
  final bool showImportantToggle;
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  TaskCard({
    super.key,
    required this.task,
    this.onToggleMyDay,
    this.onDelete,
    this.onToggleComplete,
    this.showImportantToggle = true,
  });

  Future<void> _scheduleNotification(Task task, BuildContext context) async {
    if (task.dueDate == null || task.isCompleted) return;
    final tzDateTime = tz.TZDateTime.from(task.dueDate!, tz.local);
    final now = tz.TZDateTime.now(tz.local);
    if (tzDateTime.isBefore(now)) {
      await _notificationsPlugin.show(
        task.id.hashCode,
        'Task Overdue',
        'Your task "${task.title}" is overdue!',
        const NotificationDetails(android: _androidDetails),
      );
      final updatedTask = task.copyWith(dueDate: null, hasNotified: true);
      context.read<TaskBloc>().add(UpdateTask(updatedTask));
    } else {
      await _notificationsPlugin.zonedSchedule(
        task.id.hashCode,
        'Task Due',
        'Your task "${task.title}" is due now!',
        tzDateTime,
        const NotificationDetails(android: _androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  Future<void> _cancelNotification(Task task) async {
    await _notificationsPlugin.cancel(task.id.hashCode);
  }

  void _toggleComplete(BuildContext context) {
    final updatedTask = task.copyWith(
      isCompleted: !task.isCompleted,
      dueDate: !task.isCompleted ? null : task.dueDate,
    );
    context.read<TaskBloc>().add(ToggleComplete(updatedTask));
    if (updatedTask.isCompleted) _cancelNotification(updatedTask);
    else if (updatedTask.dueDate != null) _scheduleNotification(updatedTask, context);
  }

  void _deleteTask(BuildContext context) {
    if (onDelete != null) {
      onDelete!();
    } else {
      context.read<TaskBloc>().add(DeleteTask(task.id));
    }
    _cancelNotification(task);
  }

  static const _androidDetails = AndroidNotificationDetails(
    'task_channel',
    'Task Notifications',
    channelDescription: 'Notifications for task reminders',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('notification_sound'),
    enableVibration: true,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = tz.TZDateTime.now(tz.local);
    final isOverdue = task.dueDate != null && tz.TZDateTime.from(task.dueDate!, tz.local).isBefore(now) && !task.isCompleted;

    return Dismissible(
      key: ValueKey('${task.id}_${task.isCompleted}'),
      behavior: HitTestBehavior.opaque,
      direction: DismissDirection.horizontal,
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.4,
        DismissDirection.endToStart: 0.4,
      },
      background: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: task.isCompleted
                ? [Colors.grey.withOpacity(0.7), Colors.grey.withOpacity(0.9)]
                : [theme.colorScheme.primary.withOpacity(0.7), theme.colorScheme.primary.withOpacity(0.9)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: task.isCompleted ? Colors.grey.withOpacity(0.3) : theme.colorScheme.primary.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.only(left: 20),
        child: Row(
          children: [
            Icon(
              task.isCompleted ? Icons.undo : Icons.check_circle,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(width: 10),
            Text(
              task.isCompleted ? 'Undo' : 'Mark Done',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.2),
                    offset: const Offset(1, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.redAccent, Colors.red],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.only(right: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Delete',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.2),
                    offset: const Offset(1, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.delete, color: Colors.white, size: 28),
          ],
        ),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        transform: Matrix4.identity()..scale(task.isCompleted ? 0.98 : 1.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.surface.withOpacity(task.isCompleted ? 0.6 : 0.8),
                  theme.colorScheme.surface.withOpacity(task.isCompleted ? 0.8 : 1.0),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: isOverdue ? Border.all(color: Colors.redAccent, width: 2) : null,
            ),
            child: InkWell(
              onTap: () async {
                final updatedTask = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => TaskEditScreen(task: task)),
                );
                if (updatedTask != null) {
                  context.read<TaskBloc>().add(UpdateTask(updatedTask));
                  await _cancelNotification(task);
                  await _scheduleNotification(updatedTask, context);
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                child: Row(
                  children: [
                    Checkbox(
                      value: task.isCompleted,
                      onChanged: (value) => (onToggleComplete ?? () => _toggleComplete(context))(),
                      activeColor: theme.colorScheme.onSurface.withOpacity(0.6),
                      checkColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: task.isCompleted
                                  ? theme.textTheme.bodySmall?.color?.withOpacity(0.6)
                                  : theme.textTheme.bodySmall?.color,
                              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            task.isCompleted ? 'Completed' : task.getFormattedDueDate(),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: isOverdue
                                  ? Colors.redAccent
                                  : theme.textTheme.bodySmall?.color?.withOpacity(task.isCompleted ? 0.6 : 1.0),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        task.isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: theme.colorScheme.secondary,
                      ),
                      onPressed: () => context.read<TaskBloc>().add(ToggleFavorite(task)),
                    ),
                    if (showImportantToggle)
                      IconButton(
                        icon: Icon(
                          task.isImportant ? Icons.star : Icons.star_border,
                          color: const Color(0xFFFFD700),
                        ),
                        onPressed: () => context.read<TaskBloc>().add(ToggleImportant(task)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      onDismissed: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          (onToggleComplete ?? () => _toggleComplete(context))();
        } else if (direction == DismissDirection.endToStart) {
          _deleteTask(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Task "${task.title}" deleted'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () => context.read<TaskBloc>().add(AddTask(task)),
              ),
            ),
          );
        }
      },
    );
  }
}