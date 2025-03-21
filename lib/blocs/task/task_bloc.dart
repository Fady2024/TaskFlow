import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../models/task.dart';
import '../../services/task_service.dart';
import 'task_event.dart';
import 'task_state.dart';

class TaskBloc extends Bloc<TaskEvent, TaskState> {
  final TaskService _taskService;
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  List<Task> _tasks = [];
  Timer? _overdueCheckTimer;
  Timer? _midnightResetTimer;
  Map<String, bool> _notificationCache = {};

  TaskBloc(this._taskService) : super(TasksLoading()) {
    on<LoadTasks>(_onLoadTasks);
    on<AddTask>(_onAddTask);
    on<UpdateTask>(_onUpdateTask);
    on<DeleteTask>(_onDeleteTask);
    on<ToggleFavorite>(_onToggleFavorite);
    on<ToggleImportant>(_onToggleImportant);
    on<ToggleMyDay>(_onToggleMyDay);
    on<ToggleComplete>(_onToggleComplete);
    on<ReorderTasks>(_onReorderTasks);
    on<ReorderTasksOnPage>(_onReorderTasksOnPage);
    _initialize();
  }

  Future<void> _initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);
    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('Notification received with payload: ${response.payload}');
      },
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'task_channel',
      'Task Notifications',
      description: 'Notifications for task reminders',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification_sound'),
      enableVibration: true,
      showBadge: true,
    );

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(channel);
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
      print('Notification channel created and permissions requested in TaskBloc');
    }

    await _taskService.fixCompletedTasksDueDates();

    _overdueCheckTimer = Timer.periodic(const Duration(seconds: 10), (_) => _checkOverdueTasks());
    _setupMidnightReset();
    add(LoadTasks());
  }

  void _setupMidnightReset() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1, 0, 0);
    final durationUntilMidnight = midnight.difference(now);

    _midnightResetTimer = Timer(durationUntilMidnight, () {
      _resetMyDayTasks();
      _midnightResetTimer = Timer.periodic(const Duration(days: 1), (_) => _resetMyDayTasks());
    });
  }

  Future<void> _resetMyDayTasks() async {
    print('Resetting My Day tasks at midnight');
    bool tasksUpdated = false;
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day, 0, 0);

    for (var task in _tasks.where((t) => t.isInMyDay() && !t.isCompleted)) {
      final updatedTask = task.copyWith(addedDate: DateTime(2000));
      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        _tasks[index] = updatedTask;
        await _taskService.saveTask(updatedTask, updatedTask.listId);
        tasksUpdated = true;
      }
    }

    for (var task in _tasks.where((t) => !t.isCompleted && !t.isInMyDay())) {
      if (task.dueDate != null && task.dueDate!.isBefore(midnight.add(const Duration(days: 1)))) {
        final updatedTask = task.copyWith(addedDate: now);
        final index = _tasks.indexWhere((t) => t.id == task.id);
        if (index != -1) {
          _tasks[index] = updatedTask;
          await _taskService.saveTask(updatedTask, updatedTask.listId);
          tasksUpdated = true;
        }
      }
    }

    if (tasksUpdated) emit(TasksLoaded(List.from(_tasks)));
  }

  @override
  Future<void> close() {
    _overdueCheckTimer?.cancel();
    _midnightResetTimer?.cancel();
    return super.close();
  }

  Future<void> _checkOverdueTasks() async {
    final now = tz.TZDateTime.now(tz.local);
    print('Checking overdue tasks at $now');
    bool tasksUpdated = false;

    for (var task in _tasks.where((t) => !t.isCompleted && t.dueDate != null)) {
      final dueDateTz = tz.TZDateTime.from(task.dueDate!, tz.local);
      if (dueDateTz.isBefore(now)) {
        print('Task "${task.title}" is overdue. Due: $dueDateTz, Current: $now. Clearing due date.');
        await _cancelNotification(task.id);
        await _notificationsPlugin.show(
          task.id.hashCode,
          'Task Overdue',
          'Your task "${task.title}" is overdue! Due date has been removed.',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'task_channel',
              'Task Notifications',
              channelDescription: 'Notifications for task reminders',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
              sound: RawResourceAndroidNotificationSound('notification_sound'),
              enableVibration: true,
            ),
          ),
        );
        final updatedTask = task.copyWith(dueDate: null);
        final index = _tasks.indexWhere((t) => t.id == task.id);
        if (index != -1) {
          _tasks[index] = updatedTask;
          emit(TasksLoaded(List.from(_tasks)));
          await _taskService.saveTask(updatedTask, updatedTask.listId);
          tasksUpdated = true;
          print('Task "${task.title}" dueDate cleared and saved: ${updatedTask.dueDate}');
        }
      }
    }
    if (tasksUpdated && state is! TasksLoaded) emit(TasksLoaded(List.from(_tasks)));
  }

  Future<void> _scheduleNotification(Task task) async {
    if (task.dueDate == null || task.isCompleted) {
      print('Skipping notification for task "${task.title}": dueDate=${task.dueDate}, isCompleted=${task.isCompleted}');
      return;
    }

    final tzDateTime = tz.TZDateTime.from(task.dueDate!, tz.local);
    final now = tz.TZDateTime.now(tz.local);

    if (_notificationCache[task.id] == true) {
      print('Notification already scheduled for task "${task.title}"');
      return;
    }

    if (tzDateTime.isBefore(now)) {
      print('Task "${task.title}" is overdue. Clearing due date and notifying.');
      await _notificationsPlugin.show(
        task.id.hashCode,
        'Task Overdue',
        'Your task "${task.title}" is overdue! Due date has been removed.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'task_channel',
            'Task Notifications',
            channelDescription: 'Notifications for task reminders',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            sound: RawResourceAndroidNotificationSound('notification_sound'),
            enableVibration: true,
          ),
        ),
      );
      final updatedTask = task.copyWith(dueDate: null);
      await _taskService.saveTask(updatedTask, task.listId);
      add(UpdateTask(updatedTask));
    } else {
      print('Scheduling notification for task "${task.title}" at $tzDateTime');
      await _notificationsPlugin.zonedSchedule(
        task.id.hashCode,
        'Task Due',
        'Your task "${task.title}" is due now!',
        tzDateTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'task_channel',
            'Task Notifications',
            channelDescription: 'Notifications for task reminders',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            sound: RawResourceAndroidNotificationSound('notification_sound'),
            enableVibration: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      _notificationCache[task.id] = true;
    }
  }

  Future<void> _cancelNotification(String taskId) async {
    await _notificationsPlugin.cancel(taskId.hashCode);
    _notificationCache.remove(taskId);
    print('Cancelled notification for task ID: $taskId');
  }

  Future<void> _onLoadTasks(LoadTasks event, Emitter<TaskState> emit) async {
    try {
      emit(TasksLoading());
      final activeTasks = await _taskService.loadTasks();
      final completedTasks = await _taskService.loadCompletedTasks();

      final taskMap = <String, Task>{};
      for (var task in [...activeTasks, ...completedTasks]) {
        taskMap[task.id] = task;
      }
      _tasks = taskMap.values.toList()..sort((a, b) => a.order.compareTo(b.order));

      for (var task in _tasks.where((t) => t.dueDate != null && !t.isCompleted)) {
        await _scheduleNotification(task);
      }

      if (_tasks.isEmpty) {
        emit(TasksEmpty());
      } else {
        emit(TasksLoaded(List.from(_tasks)));
      }
    } catch (e) {
      print('Task loading error: $e');
      emit(TaskError('Failed to load tasks: $e'));
    }
  }

  Future<void> _onAddTask(AddTask event, Emitter<TaskState> emit) async {
    try {
      if (_tasks.any((t) => t.id == event.task.id)) {
        await _onUpdateTask(UpdateTask(event.task), emit);
        return;
      }
      final newTask = event.task.copyWith(order: _tasks.length, listId: event.task.listId);
      _tasks.add(newTask);
      emit(TasksLoaded(List.from(_tasks)));
      await _taskService.saveTask(newTask, newTask.listId);
      if (newTask.dueDate != null && !newTask.isCompleted) {
        await _scheduleNotification(newTask);
      }
      print('Added task: ${newTask.title} to listId: ${newTask.listId}, order: ${newTask.order}, pageOrder: ${newTask.pageOrder}');
    } catch (e) {
      print('Add task error: $e');
      emit(TaskError('Failed to add task: $e'));
      await _onLoadTasks(LoadTasks(), emit);
    }
  }

  Future<void> _onUpdateTask(UpdateTask event, Emitter<TaskState> emit) async {
    try {
      final index = _tasks.indexWhere((t) => t.id == event.task.id);
      if (index != -1) {
        _tasks[index] = event.task;
        emit(TasksLoaded(List.from(_tasks)));
        if (event.task.isCompleted) {
          await _taskService.saveCompletedTask(event.task);
        } else {
          await _taskService.saveTask(event.task, event.task.listId);
        }
        if (_tasks[index].dueDate != event.task.dueDate || event.task.dueDate == null) {
          await _cancelNotification(event.task.id);
        }
        if (event.task.dueDate != null && !event.task.isCompleted) {
          await _scheduleNotification(event.task);
        }
        print('Updated task: ${event.task.title} (listId: ${event.task.listId}, completed: ${event.task.isCompleted}, dueDate: ${event.task.dueDate}, pageOrder: ${event.task.pageOrder})');
      } else {
        await _onAddTask(AddTask(event.task), emit);
      }
    } catch (e) {
      print('Update task error: $e');
      emit(TaskError('Failed to update task: $e'));
      await _onLoadTasks(LoadTasks(), emit);
    }
  }

  Future<void> _onDeleteTask(DeleteTask event, Emitter<TaskState> emit) async {
    try {
      final taskToDelete = _tasks.firstWhere((t) => t.id == event.taskId, orElse: () => throw Exception('Task not found'));
      _tasks.removeWhere((t) => t.id == event.taskId);
      for (int i = 0; i < _tasks.length; i++) {
        _tasks[i] = _tasks[i].copyWith(order: i);
      }
      if (_tasks.isEmpty) {
        emit(TasksEmpty());
      } else {
        emit(TasksLoaded(List.from(_tasks)));
      }
      if (taskToDelete.isCompleted) {
        await _taskService.deleteCompletedTask(event.taskId);
      } else {
        await _taskService.deleteTask(event.taskId, taskToDelete.listId);
      }
      await _saveTaskOrders();
      await _cancelNotification(event.taskId);
      print('Deleted task: ${event.taskId} from listId: ${taskToDelete.listId}, isCompleted: ${taskToDelete.isCompleted}');
    } catch (e) {
      print('Delete task error: $e');
      emit(TaskError('Failed to delete task: $e'));
      await _onLoadTasks(LoadTasks(), emit);
    }
  }

  Future<void> _onToggleFavorite(ToggleFavorite event, Emitter<TaskState> emit) async {
    try {
      final index = _tasks.indexWhere((t) => t.id == event.task.id);
      if (index != -1) {
        _tasks[index] = event.task.copyWith(isFavorite: !event.task.isFavorite);
        emit(TasksLoaded(List.from(_tasks)));
        if (_tasks[index].isCompleted) {
          await _taskService.saveCompletedTask(_tasks[index]);
        } else {
          await _taskService.saveTask(_tasks[index], _tasks[index].listId);
        }
        print('Toggled favorite for task: ${event.task.title}');
      }
    } catch (e) {
      print('Toggle favorite error: $e');
      emit(TaskError('Failed to toggle favorite: $e'));
      await _onLoadTasks(LoadTasks(), emit);
    }
  }

  Future<void> _onToggleImportant(ToggleImportant event, Emitter<TaskState> emit) async {
    try {
      final index = _tasks.indexWhere((t) => t.id == event.task.id);
      if (index != -1) {
        _tasks[index] = event.task.copyWith(isImportant: !event.task.isImportant);
        emit(TasksLoaded(List.from(_tasks)));
        if (_tasks[index].isCompleted) {
          await _taskService.saveCompletedTask(_tasks[index]);
        } else {
          await _taskService.saveTask(_tasks[index], _tasks[index].listId);
        }
        print('Toggled important for task: ${event.task.title}');
      }
    } catch (e) {
      print('Toggle important error: $e');
      emit(TaskError('Failed to toggle important: $e'));
      await _onLoadTasks(LoadTasks(), emit);
    }
  }

  Future<void> _onToggleMyDay(ToggleMyDay event, Emitter<TaskState> emit) async {
    try {
      final index = _tasks.indexWhere((t) => t.id == event.task.id);
      if (index != -1) {
        final now = DateTime.now();
        final newAddedDate = event.task.isInMyDay()
            ? DateTime(2000)
            : DateTime(now.year, now.month, now.day, now.hour, now.minute);
        final updatedTask = event.task.copyWith(addedDate: newAddedDate);
        _tasks[index] = updatedTask;
        emit(TasksLoaded(List.from(_tasks)));
        if (updatedTask.isCompleted) {
          await _taskService.saveCompletedTask(updatedTask);
        } else {
          await _taskService.saveTask(updatedTask, updatedTask.listId);
        }
        print('Toggled My Day for task: ${updatedTask.title} (addedDate: ${updatedTask.addedDate})');
      }
    } catch (e) {
      print('Toggle My Day error: $e');
      emit(TaskError('Failed to toggle My Day: $e'));
      await _onLoadTasks(LoadTasks(), emit);
    }
  }

  Future<void> _onToggleComplete(ToggleComplete event, Emitter<TaskState> emit) async {
    try {
      final index = _tasks.indexWhere((t) => t.id == event.task.id);
      if (index == -1) return;

      final currentTask = _tasks[index];
      if (currentTask.isCompleted == event.task.isCompleted) return;

      final updatedTask = currentTask.copyWith(
        isCompleted: !currentTask.isCompleted,
        dueDate: null,
      );

      print('Before updating task "${updatedTask.title}": isCompleted: ${updatedTask.isCompleted}, dueDate: ${updatedTask.dueDate}');

      _tasks[index] = updatedTask;
      emit(TasksLoaded(List.from(_tasks)));

      if (updatedTask.isCompleted) {
        await _cancelNotification(updatedTask.id);
        final completedTask = updatedTask.copyWith(dueDate: null);
        await _taskService.saveCompletedTask(completedTask);
        await _taskService.deleteTask(updatedTask.id, updatedTask.listId);
        print('Task "${completedTask.title}" marked as completed, dueDate cleared: ${completedTask.dueDate}');
      } else {
        final activeTask = updatedTask.copyWith(dueDate: null);
        await _taskService.saveTask(activeTask, activeTask.listId);
        await _taskService.deleteCompletedTask(activeTask.id);
        print('Task "${activeTask.title}" unmarked as completed, dueDate reset to: ${activeTask.dueDate}');
      }

      print('Toggled complete for task: ${updatedTask.title} (completed: ${updatedTask.isCompleted}, dueDate: ${updatedTask.dueDate})');
    } catch (e) {
      print('Toggle complete error: $e');
      emit(TaskError('Failed to toggle complete: $e'));
      await _onLoadTasks(LoadTasks(), emit);
    }
  }

  Future<void> _onReorderTasks(ReorderTasks event, Emitter<TaskState> emit) async {
    try {
      final task = _tasks.removeAt(event.oldIndex);
      _tasks.insert(event.newIndex, task);
      for (int i = 0; i < _tasks.length; i++) {
        _tasks[i] = _tasks[i].copyWith(order: i);
      }
      emit(TasksLoaded(List.from(_tasks)));
      await _saveTaskOrders();
      print('Reordered tasks globally: ${event.oldIndex} to ${event.newIndex}');
    } catch (e) {
      print('Reorder tasks error: $e');
      emit(TaskError('Failed to reorder tasks: $e'));
      await _onLoadTasks(LoadTasks(), emit);
    }
  }

  Future<void> _onReorderTasksOnPage(ReorderTasksOnPage event, Emitter<TaskState> emit) async {
    try {
      final filteredTasks = event.tasks.toList();
      final task = filteredTasks.removeAt(event.oldIndex);
      filteredTasks.insert(event.newIndex, task);
      for (int i = 0; i < filteredTasks.length; i++) {
        final updatedPageOrder = Map<String, int>.from(filteredTasks[i].pageOrder);
        updatedPageOrder[event.pageId] = i;
        filteredTasks[i] = filteredTasks[i].copyWith(pageOrder: updatedPageOrder);
        final index = _tasks.indexWhere((t) => t.id == filteredTasks[i].id);
        if (index != -1) {
          _tasks[index] = filteredTasks[i];
        }
      }
      emit(TasksLoaded(List.from(_tasks)));
      await _saveTaskOrders();
      print('Reordered tasks on page ${event.pageId}: ${event.oldIndex} to ${event.newIndex}');
    } catch (e) {
      print('Reorder tasks on page error: $e');
      emit(TaskError('Failed to reorder tasks on page: $e'));
      await _onLoadTasks(LoadTasks(), emit);
    }
  }

  Future<void> _saveTaskOrders() async {
    try {
      await _taskService.batchUpdateTaskOrders(_tasks);
      print('Task orders saved to database');
    } catch (e) {
      print('Error saving task orders: $e');
    }
  }
}