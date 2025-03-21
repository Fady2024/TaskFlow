import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../blocs/task/task_bloc.dart';
import '../blocs/task/task_event.dart';
import '../models/task.dart';
import '../screens/task_edit_screen.dart';

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
      background: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [theme.colorScheme.primary.withOpacity(0.8), theme.colorScheme.primary]),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 16),
        child: Icon(Icons.check_circle, color: Colors.white),
      ),
      secondaryBackground: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Colors.redAccent, Colors.red]),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
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
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [theme.colorScheme.surface.withOpacity(0.8), theme.colorScheme.surface],
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
                            color: theme.textTheme.bodySmall?.color,
                            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          task.isCompleted ? 'Completed' : task.getFormattedDueDate(),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: isOverdue ? Colors.redAccent : theme.textTheme.bodySmall?.color,
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
    );
  }
}