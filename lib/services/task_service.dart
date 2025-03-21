import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/task.dart';
import 'dart:convert';

class TaskService {
  Database? _database;

  Future<void> initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'taskflow.db');

    _database = await openDatabase(
      path,
      version: 5,
      onCreate: (db, version) async {
        print('Creating new database at $path');
        await db.execute('''
          CREATE TABLE tasks (
            id TEXT PRIMARY KEY,
            title TEXT,
            category TEXT,
            dueDate TEXT,
            isCompleted INTEGER,
            hasNotified INTEGER,
            isFavorite INTEGER,
            isImportant INTEGER,
            addedDate TEXT,
            listId TEXT,
            snoozeDuration INTEGER,
            repeatOption TEXT,
            [order] INTEGER DEFAULT 0,
            pageOrder TEXT DEFAULT '{}'
          )
        ''');
        await db.execute('''
          CREATE TABLE completed_tasks (
            id TEXT PRIMARY KEY,
            title TEXT,
            category TEXT,
            dueDate TEXT,
            isCompleted INTEGER,
            hasNotified INTEGER,
            isFavorite INTEGER,
            isImportant INTEGER,
            addedDate TEXT,
            listId TEXT,
            snoozeDuration INTEGER,
            repeatOption TEXT,
            [order] INTEGER DEFAULT 0,
            pageOrder TEXT DEFAULT '{}'
          )
        ''');
        await db.execute('''
          CREATE TABLE lists (
            id TEXT PRIMARY KEY,
            name TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE tasks ADD COLUMN repeatOption TEXT');
          await db.execute('ALTER TABLE completed_tasks ADD COLUMN repeatOption TEXT');
          print('Database upgraded: Added repeatOption column');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE tasks ADD COLUMN snoozeDuration INTEGER');
          await db.execute('ALTER TABLE completed_tasks ADD COLUMN snoozeDuration INTEGER');
          print('Database upgraded: Added snoozeDuration column');
        }
        if (oldVersion < 4) {
          await db.execute('ALTER TABLE tasks ADD COLUMN [order] INTEGER DEFAULT 0');
          await db.execute('ALTER TABLE completed_tasks ADD COLUMN [order] INTEGER DEFAULT 0');
          print('Database upgraded: Added [order] column');
        }
        if (oldVersion < 5) {
          await db.execute('ALTER TABLE tasks ADD COLUMN pageOrder TEXT DEFAULT "{}"');
          await db.execute('ALTER TABLE completed_tasks ADD COLUMN pageOrder TEXT DEFAULT "{}"');
          print('Database upgraded: Added pageOrder column');
        }
      },
      onOpen: (db) async {
        final taskCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM tasks')) ?? 0;
        final completedCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM completed_tasks')) ?? 0;
        final listCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM lists')) ?? 0;
        print('Database opened at $path: $taskCount tasks, $completedCount completed tasks, $listCount lists');
      },
    );
  }

  Future<void> fixCompletedTasksDueDates() async {
    if (_database == null) {
      print('Database not initialized, initializing now');
      await initDatabase();
    }
    try {
      final db = _database!;
      await db.transaction((txn) async {
        final updatedRows = await txn.rawUpdate('UPDATE completed_tasks SET dueDate = NULL');
        print('Cleared due dates for $updatedRows completed tasks');
      });
    } catch (e) {
      print('Error clearing due dates for completed tasks: $e');
    }
  }

  Future<List<Task>> loadTasks([String? listId]) async {
    if (_database == null) {
      print('Database not initialized, initializing now');
      await initDatabase();
    }
    try {
      final db = _database!;
      List<Map<String, dynamic>> taskMaps;

      if (listId != null) {
        taskMaps = await db.query('tasks', where: 'listId = ?', whereArgs: [listId]);
      } else {
        taskMaps = await db.query('tasks');
      }

      final tasks = taskMaps.map((map) {
        final pageOrderJson = map['pageOrder'] as String? ?? '{}';
        final pageOrder = Map<String, int>.from(jsonDecode(pageOrderJson));
        return Task.fromJson({...map, 'pageOrder': pageOrder});
      }).toList();
      print('Loaded ${tasks.length} tasks: ${tasks.map((t) => '${t.title} (dueDate: ${t.dueDate}, listId: ${t.listId}, order: ${t.order}, pageOrder: ${t.pageOrder})').join(', ')}');
      return tasks;
    } catch (e) {
      print('Error loading tasks: $e');
      return [];
    }
  }

  Future<List<Task>> loadCompletedTasks() async {
    if (_database == null) {
      print('Database not initialized, initializing now');
      await initDatabase();
    }
    try {
      final db = _database!;
      final taskMaps = await db.query('completed_tasks');
      final tasks = taskMaps.map((map) {
        final pageOrderJson = map['pageOrder'] as String? ?? '{}';
        final pageOrder = Map<String, int>.from(jsonDecode(pageOrderJson));
        var task = Task.fromJson({...map, 'pageOrder': pageOrder});
        if (task.dueDate != null) {
          print('Found completed task "${task.title}" with non-null dueDate: ${task.dueDate}. Clearing it.');
          task = task.copyWith(dueDate: null);
          db.update(
            'completed_tasks',
            {'dueDate': null},
            where: 'id = ?',
            whereArgs: [task.id],
          );
        }
        return task;
      }).toList();
      print('Loaded ${tasks.length} completed tasks: ${tasks.map((t) => '${t.title} (dueDate: ${t.dueDate}, listId: ${t.listId}, order: ${t.order}, pageOrder: ${t.pageOrder})').join(', ')}');
      return tasks;
    } catch (e) {
      print('Error loading completed tasks: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> loadTaskLists() async {
    if (_database == null) {
      print('Database not initialized, initializing now');
      await initDatabase();
    }
    try {
      final db = _database!;
      final listMaps = await db.query('lists');
      final lists = listMaps.map((map) => {'id': map['id'], 'name': map['name'] ?? 'Unnamed List'}).toList();
      print('Loaded ${lists.length} task lists: $lists');
      return lists;
    } catch (e) {
      print('Error loading task lists: $e');
      return [];
    }
  }

  Future<void> saveTask(Task task, [String? listId]) async {
    if (_database == null) {
      print('Database not initialized, initializing now');
      await initDatabase();
    }
    try {
      final db = _database!;
      final updatedTask = task.copyWith(listId: listId ?? task.listId);
      await db.transaction((txn) async {
        final result = await txn.insert(
          'tasks',
          {
            ...updatedTask.toJson(),
            'dueDate': updatedTask.dueDate?.toIso8601String(),
            'pageOrder': jsonEncode(updatedTask.pageOrder),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        print('Saved task: ${updatedTask.title} with dueDate: ${updatedTask.dueDate}, listId: ${updatedTask.listId}, order: ${updatedTask.order}, pageOrder: ${updatedTask.pageOrder}, result: $result');
      });
    } catch (e) {
      print('Error saving task: $e');
      rethrow;
    }
  }

  Future<void> saveCompletedTask(Task task) async {
    if (_database == null) {
      print('Database not initialized, initializing now');
      await initDatabase();
    }
    try {
      final db = _database!;
      final taskToSave = task.copyWith(dueDate: null);
      await db.transaction((txn) async {
        final result = await txn.insert(
          'completed_tasks',
          {
            ...taskToSave.toJson(),
            'dueDate': null,
            'pageOrder': jsonEncode(taskToSave.pageOrder),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        if (taskToSave.listId != null) {
          await txn.delete('tasks', where: 'id = ? AND listId = ?', whereArgs: [taskToSave.id, taskToSave.listId]);
        } else {
          await txn.delete('tasks', where: 'id = ?', whereArgs: [taskToSave.id]);
        }
        print('Saved completed task: ${taskToSave.title}, dueDate: ${taskToSave.dueDate}, pageOrder: ${taskToSave.pageOrder}, result: $result');
      });
    } catch (e) {
      print('Error saving completed task: $e');
      rethrow;
    }
  }

  Future<void> deleteTask(String taskId, [String? listId]) async {
    if (_database == null) {
      print('Database not initialized, initializing now');
      await initDatabase();
    }
    try {
      final db = _database!;
      await db.transaction((txn) async {
        if (listId != null) {
          await txn.delete('tasks', where: 'id = ? AND listId = ?', whereArgs: [taskId, listId]);
        } else {
          await txn.delete('tasks', where: 'id = ?', whereArgs: [taskId]);
        }
      });
      print('Deleted task: $taskId from listId: $listId');
    } catch (e) {
      print('Error deleting task: $e');
      rethrow;
    }
  }

  Future<void> deleteCompletedTask(String taskId) async {
    if (_database == null) {
      print('Database not initialized, initializing now');
      await initDatabase();
    }
    try {
      final db = _database!;
      await db.transaction((txn) async {
        await txn.delete('completed_tasks', where: 'id = ?', whereArgs: [taskId]);
      });
      print('Deleted completed task: $taskId');
    } catch (e) {
      print('Error deleting completed task: $e');
      rethrow;
    }
  }

  Future<String> createTaskList(String name) async {
    if (_database == null) {
      print('Database not initialized, initializing now');
      await initDatabase();
    }
    try {
      final db = _database!;
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      await db.transaction((txn) async {
        await txn.insert('lists', {'id': id, 'name': name});
      });
      print('Created task list: $name with id: $id');
      return id;
    } catch (e) {
      print('Error creating task list: $e');
      return '';
    }
  }

  Future<void> deleteTaskList(String listId) async {
    if (_database == null) {
      print('Database not initialized, initializing now');
      await initDatabase();
    }
    try {
      final db = _database!;
      await db.transaction((txn) async {
        await txn.delete('tasks', where: 'listId = ?', whereArgs: [listId]);
        await txn.delete('completed_tasks', where: 'listId = ?', whereArgs: [listId]);
        await txn.delete('lists', where: 'id = ?', whereArgs: [listId]);
      });
      print('Deleted task list: $listId and all associated tasks');
    } catch (e) {
      print('Error deleting task list: $e');
      rethrow;
    }
  }

  Future<int> getTaskCount(String listId) async {
    if (_database == null) {
      print('Database not initialized, initializing now');
      await initDatabase();
    }
    try {
      final db = _database!;
      final result = await db.query('tasks', where: 'listId = ?', whereArgs: [listId]);
      print('Task count for listId $listId: ${result.length}');
      return result.length;
    } catch (e) {
      print('Error getting task count: $e');
      return 0;
    }
  }

  Future<void> clearAllData() async {
    if (_database == null) {
      print('Database not initialized, initializing now');
      await initDatabase();
    }
    try {
      final db = _database!;
      await db.transaction((txn) async {
        await txn.delete('tasks');
        await txn.delete('completed_tasks');
        await txn.delete('lists');
      });
      print('Cleared all data from database');
    } catch (e) {
      print('Error clearing data: $e');
      rethrow;
    }
  }

  Future<void> batchUpdateTaskOrders(List<Task> tasks) async {
    if (_database == null) {
      print('Database not initialized, initializing now');
      await initDatabase();
    }
    try {
      final db = _database!;
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final task in tasks) {
          if (task.isCompleted) {
            batch.update(
              'completed_tasks',
              {
                '[order]': task.order,
                'pageOrder': jsonEncode(task.pageOrder),
              },
              where: 'id = ?',
              whereArgs: [task.id],
            );
          } else {
            batch.update(
              'tasks',
              {
                '[order]': task.order,
                'pageOrder': jsonEncode(task.pageOrder),
              },
              where: 'id = ?',
              whereArgs: [task.id],
            );
          }
        }
        await batch.commit(noResult: true);
      });
    } catch (e) {
      print('Error batch updating task orders: $e');
      rethrow;
    }
  }
}