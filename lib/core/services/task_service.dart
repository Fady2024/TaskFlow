import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/Task.dart';

class TaskService {
  Database? _database;
  final SupabaseClient supabaseClient = Supabase.instance.client;

  Future<void> initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'taskflow.db');

    _database = await openDatabase(
      path,
      version: 11,
      onCreate: (db, version) async {
        print('Creating new database at $path');
        await db.execute('''
        CREATE TABLE tasks (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          category TEXT DEFAULT 'General',
          due_date TEXT,
          is_completed INTEGER DEFAULT 0,
          has_notified INTEGER DEFAULT 0, 
          is_favorite INTEGER DEFAULT 0,
          is_important INTEGER DEFAULT 0,
          added_date TEXT NOT NULL,
          completed_date TEXT,
          list_id TEXT,
          snooze_duration INTEGER,
          repeat_option TEXT,
          "order" INTEGER DEFAULT 0,
          page_order TEXT DEFAULT '{}',
          user_id TEXT NOT NULL
        )
      ''');
        await db.execute('''
        CREATE TABLE completed_tasks (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          category TEXT DEFAULT 'General',
          due_date TEXT,
          is_completed INTEGER DEFAULT 1,
          has_notified INTEGER DEFAULT 0,
          is_favorite INTEGER DEFAULT 0,
          is_important INTEGER DEFAULT 0,
          added_date TEXT NOT NULL,
          completed_date TEXT,
          list_id TEXT,
          snooze_duration INTEGER,
          repeat_option TEXT,
          "order" INTEGER DEFAULT 0,
          page_order TEXT DEFAULT '{}',
          user_id TEXT NOT NULL
        )
      ''');
        await db.execute('''
        CREATE TABLE lists (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          user_id TEXT NOT NULL
        )
      ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        print('Upgrading database from version $oldVersion to $newVersion');
        if (oldVersion < 11) {
          await db.execute('DROP TABLE IF EXISTS tasks');
          await db.execute('DROP TABLE IF EXISTS completed_tasks');
          await db.execute('DROP TABLE IF EXISTS lists');
          await db.execute('''
          CREATE TABLE tasks (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            category TEXT DEFAULT 'General',
            due_date TEXT,
            is_completed INTEGER DEFAULT 0,
            has_notified INTEGER DEFAULT 0,
            is_favorite INTEGER DEFAULT 0,
            is_important INTEGER DEFAULT 0,
            added_date TEXT NOT NULL,
            completed_date TEXT,
            list_id TEXT,
            snooze_duration INTEGER,
            repeat_option TEXT,
            "order" INTEGER DEFAULT 0,
            page_order TEXT DEFAULT '{}',
            user_id TEXT NOT NULL
          )
        ''');
          await db.execute('''
          CREATE TABLE completed_tasks (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            category TEXT DEFAULT 'General',
            due_date TEXT,
            is_completed INTEGER DEFAULT 1,
            has_notified INTEGER DEFAULT 0, 
            is_favorite INTEGER DEFAULT 0,
            is_important INTEGER DEFAULT 0,
            added_date TEXT NOT NULL,
            completed_date TEXT,
            list_id TEXT,
            snooze_duration INTEGER,
            repeat_option TEXT,
            "order" INTEGER DEFAULT 0,
            page_order TEXT DEFAULT '{}',
            user_id TEXT NOT NULL
          )
        ''');
          await db.execute('''
          CREATE TABLE lists (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            user_id TEXT NOT NULL
          )
        ''');
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

  Future<bool> _isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<bool> _isGuestUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isGuest') ?? false;
  }

  Future<void> syncWithSupabase() async {
    final isGuest = await _isGuestUser();
    if (isGuest) {
      print('Guest user detected, skipping Supabase sync');
      return;
    }

    final isOnline = await _isOnline();
    if (!isOnline) {
      print('No network connection, skipping Supabase sync');
      return;
    }

    final userId = supabaseClient.auth.currentUser?.id;
    if (userId == null) {
      print('No authenticated user, skipping Supabase sync');
      return;
    }

    print('Starting Supabase sync for user: $userId');

    final localTasks = await loadTasks();
    final remoteTasksResponse = await supabaseClient.from('tasks').select().eq('user_id', userId);
    final remoteTasks = (remoteTasksResponse as List<dynamic>).map((t) => t as Map<String, dynamic>).toList();

    for (var task in localTasks) {
      final remoteTask = remoteTasks.firstWhere((rt) => rt['id'] == task.id, orElse: () => {});
      if (remoteTask.isEmpty) {
        print('Inserting new task to Supabase: ${task.title}');
        await supabaseClient.from('tasks').insert({
          ...task.toJson(),
          'user_id': userId,
        });
      } else {
        final remoteUpdatedAt = DateTime.tryParse(remoteTask['updated_at'] ?? '') ?? DateTime(2000);
        final localUpdatedAt = task.addedDate;
        if (remoteUpdatedAt.isBefore(localUpdatedAt)) {
          print('Updating task in Supabase: ${task.title}');
          await supabaseClient.from('tasks').update(task.toJson()).eq('id', task.id);
        }
      }
    }

    final localCompletedTasks = await loadCompletedTasks();
    final remoteCompletedTasksResponse =
    await supabaseClient.from('completed_tasks').select().eq('user_id', userId);
    final remoteCompletedTasks =
    (remoteCompletedTasksResponse as List<dynamic>).map((t) => t as Map<String, dynamic>).toList();

    for (var task in localCompletedTasks) {
      final remoteTask = remoteCompletedTasks.firstWhere((rt) => rt['id'] == task.id, orElse: () => {});
      if (remoteTask.isEmpty) {
        print('Inserting new completed task to Supabase: ${task.title}');
        await supabaseClient.from('completed_tasks').insert({
          ...task.toJson(),
          'user_id': userId,
        });
      } else {
        final remoteUpdatedAt = DateTime.tryParse(remoteTask['updated_at'] ?? '') ?? DateTime(2000);
        final localUpdatedAt = task.completedDate ?? task.addedDate;
        if (remoteUpdatedAt.isBefore(localUpdatedAt)) {
          print('Updating completed task in Supabase: ${task.title}');
          await supabaseClient.from('completed_tasks').update(task.toJson()).eq('id', task.id);
        }
      }
    }

    final localLists = await loadTaskLists();
    final remoteListsResponse = await supabaseClient.from('lists').select().eq('user_id', userId);
    final remoteLists = (remoteListsResponse as List<dynamic>).map((l) => l as Map<String, dynamic>).toList();

    for (var list in localLists) {
      final remoteList = remoteLists.firstWhere((rl) => rl['id'] == list['id'], orElse: () => {});
      if (remoteList.isEmpty) {
        print('Inserting new list to Supabase: ${list['name']}');
        await supabaseClient.from('lists').insert({
          'id': list['id'],
          'name': list['name'],
          'user_id': userId,
        });
      }
    }

    print('Supabase sync completed');
  }

  Future<void> importFromSupabase() async {
    final isGuest = await _isGuestUser();
    if (isGuest) {
      print('Guest user detected, skipping Supabase import');
      return;
    }

    final isOnline = await _isOnline();
    if (!isOnline) {
      print('No network connection, skipping Supabase import');
      return;
    }

    final userId = supabaseClient.auth.currentUser?.id;
    if (userId == null) {
      print('No authenticated user, skipping Supabase import');
      return;
    }

    await clearAllData();

    final remoteTasksResponse = await supabaseClient.from('tasks').select().eq('user_id', userId);
    final remoteTasks = (remoteTasksResponse as List<dynamic>).map((t) => t as Map<String, dynamic>).toList();
    for (var taskJson in remoteTasks) {
      final task = Task.fromJson(taskJson);
      await saveTask(task, task.listId);
      print('Imported task from Supabase: ${task.title}');
    }

    final remoteCompletedTasksResponse =
    await supabaseClient.from('completed_tasks').select().eq('user_id', userId);
    final remoteCompletedTasks =
    (remoteCompletedTasksResponse as List<dynamic>).map((t) => t as Map<String, dynamic>).toList();
    for (var taskJson in remoteCompletedTasks) {
      final task = Task.fromJson(taskJson);
      await saveCompletedTask(task);
      print('Imported completed task from Supabase: ${task.title}');
    }

    final remoteListsResponse = await supabaseClient.from('lists').select().eq('user_id', userId);
    final remoteLists = (remoteListsResponse as List<dynamic>).map((l) => l as Map<String, dynamic>).toList();
    for (var list in remoteLists) {
      await _database!.insert(
        'lists',
        {
          'id': list['id'],
          'name': list['name'],
          'user_id': userId,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('Imported list from Supabase: ${list['name']}');
    }

    print('Supabase import completed for user: $userId');
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
            'id': updatedTask.id,
            'title': updatedTask.title,
            'category': updatedTask.category,
            'due_date': updatedTask.dueDate?.toIso8601String(),
            'is_completed': updatedTask.isCompleted ? 1 : 0,
            'has_notified': updatedTask.hasNotified ? 1 : 0,
            'is_favorite': updatedTask.isFavorite ? 1 : 0,
            'is_important': updatedTask.isImportant ? 1 : 0,
            'added_date': updatedTask.addedDate.toIso8601String(),
            'completed_date': updatedTask.completedDate?.toIso8601String(),
            'list_id': updatedTask.listId,
            'snooze_duration': updatedTask.snoozeDuration,
            'repeat_option': updatedTask.repeatOption,
            'order': updatedTask.order,
            'page_order': jsonEncode(updatedTask.pageOrder),
            'user_id': updatedTask.userId,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        print('Saved task locally: ${updatedTask.title} with due_date: ${updatedTask.dueDate}, result: $result');
      });
      if (!await _isGuestUser() && await _isOnline()) {
        final userId = supabaseClient.auth.currentUser?.id;
        if (userId != null) {
          await supabaseClient.from('tasks').upsert({
            ...updatedTask.toJson(),
            'user_id': userId,
          });
        }
      }
    } catch (e) {
      print('Error saving task: $e');
      rethrow;
    }
  }

  Future<void> fixCompletedTasksDueDates() async {
    if (_database == null) {
      print('Database not initialized, initializing now');
      await initDatabase();
    }
    try {
      final db = _database!;
      await db.transaction((txn) async {
        final updatedRows = await txn.rawUpdate('UPDATE completed_tasks SET due_date = NULL');
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
        taskMaps = await db.query('tasks', where: 'list_id = ?', whereArgs: [listId]);
      } else {
        taskMaps = await db.query('tasks');
      }

      final tasks = taskMaps.map((map) {
        final pageOrderJson = map['page_order'] as String? ?? '{}';
        final pageOrder = Map<String, int>.from(jsonDecode(pageOrderJson));
        return Task.fromJson({...map, 'page_order': pageOrder});
      }).toList();
      print('Loaded ${tasks.length} tasks: ${tasks.map((t) => '${t.title} (due_date: ${t.dueDate}, list_id: ${t.listId}, order: ${t.order}, page_order: ${t.pageOrder})').join(', ')}');
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
        final pageOrderJson = map['page_order'] as String? ?? '{}';
        final pageOrder = Map<String, int>.from(jsonDecode(pageOrderJson));
        var task = Task.fromJson({...map, 'page_order': pageOrder});
        if (task.dueDate != null) {
          print('Found completed task "${task.title}" with non-null due_date: ${task.dueDate}. Clearing it.');
          task = task.copyWith(dueDate: null);
          db.update(
            'completed_tasks',
            {'due_date': null},
            where: 'id = ?',
            whereArgs: [task.id],
          );
        }
        return task;
      }).toList();
      print('Loaded ${tasks.length} completed tasks: ${tasks.map((t) => '${t.title} (due_date: ${t.dueDate}, list_id: ${t.listId}, order: ${t.order}, page_order: ${t.pageOrder})').join(', ')}');
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
      final lists = listMaps.map((map) => {
        'id': map['id'],
        'name': map['name'] ?? 'Unnamed List',
        'user_id': map['user_id'],
      }).toList();
      print('Loaded ${lists.length} task lists: $lists');
      return lists;
    } catch (e) {
      print('Error loading task lists: $e');
      return [];
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
            'id': taskToSave.id,
            'title': taskToSave.title,
            'category': taskToSave.category,
            'due_date': null,
            'is_completed': taskToSave.isCompleted ? 1 : 0,
            'has_notified': taskToSave.hasNotified ? 1 : 0,
            'is_favorite': taskToSave.isFavorite ? 1 : 0,
            'is_important': taskToSave.isImportant ? 1 : 0,
            'added_date': taskToSave.addedDate.toIso8601String(),
            'completed_date': taskToSave.completedDate?.toIso8601String(),
            'list_id': taskToSave.listId,
            'snooze_duration': taskToSave.snoozeDuration,
            'repeat_option': taskToSave.repeatOption,
            'order': taskToSave.order,
            'page_order': jsonEncode(taskToSave.pageOrder),
            'user_id': taskToSave.userId,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        if (taskToSave.listId != null) {
          await txn.delete('tasks', where: 'id = ? AND list_id = ?', whereArgs: [taskToSave.id, taskToSave.listId]);
        } else {
          await txn.delete('tasks', where: 'id = ?', whereArgs: [taskToSave.id]);
        }
        print('Saved completed task: ${taskToSave.title}, due_date: ${taskToSave.dueDate}, page_order: ${taskToSave.pageOrder}, result: $result');
      });
      if (!await _isGuestUser() && await _isOnline()) {
        final userId = supabaseClient.auth.currentUser?.id;
        if (userId != null) {
          await supabaseClient.from('completed_tasks').upsert({
            ...taskToSave.toJson(),
            'user_id': userId,
          });
        }
      }
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
          await txn.delete('tasks', where: 'id = ? AND list_id = ?', whereArgs: [taskId, listId]);
        } else {
          await txn.delete('tasks', where: 'id = ?', whereArgs: [taskId]);
        }
      });
      print('Deleted task: $taskId from list_id: $listId');
      if (!await _isGuestUser() && await _isOnline()) {
        await supabaseClient.from('tasks').delete().eq('id', taskId);
      }
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
      if (!await _isGuestUser() && await _isOnline()) {
        await supabaseClient.from('completed_tasks').delete().eq('id', taskId);
      }
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
      final userId = supabaseClient.auth.currentUser?.id ?? 'guest';
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      await db.transaction((txn) async {
        await txn.insert(
          'lists',
          {
            'id': id,
            'name': name,
            'user_id': userId,
          },
        );
      });
      print('Created task list: $name with id: $id');
      if (!await _isGuestUser() && await _isOnline()) {
        final userId = supabaseClient.auth.currentUser?.id;
        if (userId != null) {
          await supabaseClient.from('lists').insert({
            'id': id,
            'name': name,
            'user_id': userId,
          });
        }
      }
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
        await txn.delete('tasks', where: 'list_id = ?', whereArgs: [listId]);
        await txn.delete('completed_tasks', where: 'list_id = ?', whereArgs: [listId]);
        await txn.delete('lists', where: 'id = ?', whereArgs: [listId]);
      });
      print('Deleted task list: $listId and all associated tasks');
      if (!await _isGuestUser() && await _isOnline()) {
        await supabaseClient.from('tasks').delete().eq('list_id', listId);
        await supabaseClient.from('completed_tasks').delete().eq('list_id', listId);
        await supabaseClient.from('lists').delete().eq('id', listId);
      }
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
      final result = await db.query('tasks', where: 'list_id = ?', whereArgs: [listId]);
      print('Task count for list_id $listId: ${result.length}');
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
                'page_order': jsonEncode(task.pageOrder),
                'completed_date': task.completedDate?.toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [task.id],
            );
          } else {
            batch.update(
              'tasks',
              {
                '[order]': task.order,
                'page_order': jsonEncode(task.pageOrder),
                'completed_date': task.completedDate?.toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [task.id],
            );
          }
        }
        await batch.commit(noResult: true);
      });
      if (!await _isGuestUser() && await _isOnline()) {
        final userId = supabaseClient.auth.currentUser?.id;
        if (userId != null) {
          for (var task in tasks) {
            if (task.isCompleted) {
              await supabaseClient.from('completed_tasks').upsert({
                ...task.toJson(),
                'user_id': userId,
              });
            } else {
              await supabaseClient.from('tasks').upsert({
                ...task.toJson(),
                'user_id': userId,
              });
            }
          }
        }
      }
    } catch (e) {
      print('Error batch updating task orders: $e');
      rethrow;
    }
  }
}