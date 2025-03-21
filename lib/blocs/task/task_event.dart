import 'package:equatable/equatable.dart';
import '../../models/task.dart';

abstract class TaskEvent extends Equatable {
  const TaskEvent();
  @override
  List<Object?> get props => [];
}

class LoadTasks extends TaskEvent {}
class AddTask extends TaskEvent {
  final Task task;
  const AddTask(this.task);
  @override
  List<Object?> get props => [task];
}
class UpdateTask extends TaskEvent {
  final Task task;
  const UpdateTask(this.task);
  @override
  List<Object?> get props => [task];
}
class DeleteTask extends TaskEvent {
  final String taskId;
  const DeleteTask(this.taskId);
  @override
  List<Object?> get props => [taskId];
}
class ToggleFavorite extends TaskEvent {
  final Task task;
  const ToggleFavorite(this.task);
  @override
  List<Object?> get props => [task];
}
class ToggleImportant extends TaskEvent {
  final Task task;
  const ToggleImportant(this.task);
  @override
  List<Object?> get props => [task];
}
class ToggleMyDay extends TaskEvent {
  final Task task;
  const ToggleMyDay(this.task);
  @override
  List<Object?> get props => [task];
}
class ToggleComplete extends TaskEvent {
  final Task task;
  const ToggleComplete(this.task);
  @override
  List<Object?> get props => [task];
}
class ReorderTasks extends TaskEvent {
  final int oldIndex;
  final int newIndex;

  const ReorderTasks(this.oldIndex, this.newIndex);

  @override
  List<Object?> get props => [oldIndex, newIndex];
}

class ReorderTasksOnPage extends TaskEvent {
  final List<Task> tasks;
  final int oldIndex;
  final int newIndex;
  final String pageId;

  const ReorderTasksOnPage(this.tasks, this.oldIndex, this.newIndex, this.pageId);

  @override
  List<Object?> get props => [tasks, oldIndex, newIndex, pageId];
}