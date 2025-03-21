import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../widgets/sidebar.dart';
import '../theme_provider.dart';
import 'my_day_screen.dart';
import 'important_screen.dart';
import 'planned_screen.dart';
import 'favorite_screen.dart';
import 'tasks_screen.dart';
import 'task_list_screen.dart';
import 'productivity_analytics_screen.dart';
import 'pomodoro_timer_screen.dart';
import '../services/task_service.dart';
import '../blocs/task/task_bloc.dart';
import '../blocs/task/task_event.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  late TaskService _taskService;
  late AnimationController _controller;
  late Animation<double> _drawerAnimation;
  late Animation<double> _fabAnimation;
  int _selectedIndex = 0;
  List<Map<String, dynamic>> _customLists = [];
  int _notificationCount = 0;
  bool _isDrawerExpanded = false;
  bool _isDrawerPinned = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _taskService = TaskService();
    _initializeTaskService();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _drawerAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _fabAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.forward();
    _loadCustomLists();
    _fetchNotificationCount();
    context.read<TaskBloc>().add(LoadTasks());
  }

  Future<void> _initializeTaskService() async {
    await _taskService.initDatabase();
    print('TaskService database initialized in MainScreen');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadCustomLists() async {
    await _initializeTaskService();
    final lists = await _taskService.loadTaskLists();
    setState(() {
      _customLists = lists;
      print('Loaded custom lists: $_customLists');
    });
  }

  Future<void> _fetchNotificationCount() async {
    final tasks = await _taskService.loadTasks();
    setState(() {
      _notificationCount = tasks
          .where((task) => task.dueDate != null && task.dueDate!.isBefore(DateTime.now()) && !task.hasNotified)
          .length;
      print('Notification count: $_notificationCount');
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      if (!_isDrawerPinned) _controller.forward(from: 0);
    });
  }

  Future<void> _addNewList() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _buildNewListDialog(),
    );
    if (name != null && name.isNotEmpty) {
      try {
        await _initializeTaskService();
        final listId = await _taskService.createTaskList(name);
        if (listId.isNotEmpty) {
          final newList = {'id': listId, 'name': name};
          setState(() {
            _customLists.add(newList);
            _selectedIndex = 8 + _customLists.length - 1;
            _controller.forward(from: 0);
            print('Added new list: $newList, updated customLists: $_customLists');
          });
          if (!_isDrawerPinned) Navigator.pop(context);
        } else {
          throw Exception('Failed to create list: Empty listId returned');
        }
      } catch (e) {
        print('Error adding new list: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating list: $e', style: GoogleFonts.poppins())),
        );
      }
    }
  }

  Future<void> _deleteList(String listId, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete List', style: GoogleFonts.poppins()),
        content: Text('Are you sure you want to delete this list and all its tasks?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        final tasks = await _taskService.loadTasks(listId);
        for (var task in tasks) {
          context.read<TaskBloc>().add(DeleteTask(task.id));
        }
        final completedTasks = await _taskService.loadCompletedTasks();
        for (var task in completedTasks.where((t) => t.listId == listId)) {
          context.read<TaskBloc>().add(DeleteTask(task.id));
        }
        await _taskService.deleteTaskList(listId);
        setState(() {
          _customLists.removeAt(index - 8);
          _selectedIndex = 0;
          print('Deleted list $listId, updated customLists: $_customLists, selectedIndex: $_selectedIndex');
        });
      } catch (e) {
        print('Error deleting list: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting list: $e', style: GoogleFonts.poppins())),
        );
      }
    }
  }

  void _toggleDrawerSize() {
    if (!_isDrawerPinned) {
      setState(() {
        _isDrawerExpanded = !_isDrawerExpanded;
        _controller.forward(from: 0);
      });
    }
  }

  void _togglePin() {
    setState(() {
      if (_isDrawerExpanded && !_isDrawerPinned) {
        _isDrawerPinned = true;
        _isDrawerExpanded = false;
      } else if (!_isDrawerExpanded && !_isDrawerPinned) {
        _isDrawerPinned = true;
      } else if (_isDrawerPinned) {
        _isDrawerPinned = false;
      }
      _controller.forward(from: 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const MyDayScreen(),
      const ImportantScreen(),
      const PlannedScreen(),
      const FavoriteScreen(),
      const TasksScreen(),
      const ProductivityAnalyticsScreen(type: 'overview'),
      const PomodoroTimerScreen(),
      const ProductivityAnalyticsScreen(type: 'completion'),
      const ProductivityAnalyticsScreen(type: 'progress'),
      ..._customLists.map((list) => TaskListScreen(
        listId: list['id'] as String,
        listName: list['name'] as String,
        onDelete: () => _deleteList(list['id'] as String, 9 + _customLists.indexOf(list)),
      )),
    ];

    return Scaffold(
      key: _scaffoldKey,
      appBar: _buildAppBar(),
      drawer: _isDrawerPinned
          ? null
          : Drawer(
        width: _isDrawerExpanded ? 280 : 80,
        elevation: 8,
        child: SafeArea(
          child: Sidebar(
            selectedIndex: _selectedIndex,
            onItemTapped: _onItemTapped,
            customLists: _customLists,
            onAddNewList: _addNewList,
            onDeleteList: _deleteList,
            isDrawerExpanded: _isDrawerExpanded,
            isDrawerPinned: _isDrawerPinned,
            onTogglePin: _togglePin,
            onToggleExpansion: _toggleDrawerSize,
          ),
        ),
      ),
      body: SafeArea(
        child: Row(
          children: [
            if (_isDrawerPinned)
              SizeTransition(
                sizeFactor: _drawerAnimation,
                axis: Axis.horizontal,
                child: Sidebar(
                  selectedIndex: _selectedIndex,
                  onItemTapped: _onItemTapped,
                  customLists: _customLists,
                  onAddNewList: _addNewList,
                  onDeleteList: _deleteList,
                  isDrawerExpanded: _isDrawerExpanded,
                  isDrawerPinned: _isDrawerPinned,
                  onTogglePin: _togglePin,
                  onToggleExpansion: _toggleDrawerSize,
                ),
              ),
            Expanded(
              child: FadeTransition(
                opacity: _drawerAnimation,
                child: screens[_selectedIndex],
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text('TaskFlow',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [Shadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)])),
      backgroundColor: const Color(0xFF6C5CE7),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.3),
      actions: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Colors.white),
              onPressed: () => setState(() => _notificationCount = 0),
            ),
            if (_notificationCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: CircleAvatar(
                  radius: 8,
                  backgroundColor: const Color(0xFFFF6F61),
                  child: Text('$_notificationCount', style: GoogleFonts.poppins(fontSize: 10, color: Colors.white)),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildNewListDialog() {
    final controller = TextEditingController();
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text('New List',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF6C5CE7))),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: 'Enter list name',
          hintStyle: GoogleFonts.poppins(color: theme.hintColor),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: theme.inputDecorationTheme.fillColor,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: GoogleFonts.poppins(color: theme.textTheme.bodyMedium?.color)),
        ),
        TextButton(
          onPressed: () {
            if (controller.text.isNotEmpty) {
              Navigator.pop(context, controller.text);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('List name cannot be empty', style: GoogleFonts.poppins())),
              );
            }
          },
          child: Text('Add', style: GoogleFonts.poppins(color: const Color(0xFF6C5CE7))),
        ),
      ],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: theme.cardColor,
    );
  }
}