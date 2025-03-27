import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/task_service.dart';
import '../../../../core/models/Task.dart';
import '../bloc/task_bloc.dart';
import '../bloc/task_event.dart';

class TaskEditScreen extends StatefulWidget {
  final Task? task;
  final String? listId;

  const TaskEditScreen({super.key, this.task, this.listId});

  @override
  State<TaskEditScreen> createState() => _TaskEditScreenState();
}

class _TaskEditScreenState extends State<TaskEditScreen> {
  late TextEditingController _titleController;
  late String _category;
  tz.TZDateTime? _dueDate;
  bool _isInMyDay = true;
  String? _selectedListId;
  List<Map<String, dynamic>> _taskLists = [];
  bool _isLoadingLists = true;
  bool _isSaving = false;

  final List<String> _categories = ['General', 'Work', 'Personal', 'Urgent'];
  final TaskService _taskService = TaskService();
  final SupabaseClient _supabaseClient = Supabase.instance.client;

  final Map<String, Color> categoryColors = {
    'General': const Color(0xFF5D737E),
    'Work': const Color(0xFFFF6F61),
    'Personal': const Color(0xFF8D5522),
    'Urgent': const Color(0xFF8A2BE2),
  };

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _category = widget.task?.category ?? 'General';
    _dueDate = widget.task?.dueDate != null ? tz.TZDateTime.from(widget.task!.dueDate!, tz.local) : null;
    _isInMyDay = widget.task?.isInMyDay() ?? true;
    _selectedListId = widget.task?.listId ?? widget.listId;
    _loadTaskLists();
  }

  Future<void> _loadTaskLists() async {
    _taskLists = await _taskService.loadTaskLists();
    if (_selectedListId != null && !_taskLists.any((list) => list['id'] == _selectedListId)) {
      _selectedListId = null;
    }
    if (mounted) setState(() => _isLoadingLists = false);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _selectDueDate() async {
    final now = tz.TZDateTime.now(tz.local);
    final today = DateTime(now.year, now.month, now.day);

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _dueDate != null && _dueDate!.isAfter(now) ? _dueDate!.toLocal() : now.toLocal(),
      firstDate: today,
      lastDate: DateTime(2030),
      selectableDayPredicate: (DateTime date) {
        return !date.isBefore(today);
      },
    );

    if (pickedDate != null) {
      TimeOfDay initialTime;
      if (_dueDate != null && _dueDate!.isAfter(now)) {
        initialTime = TimeOfDay.fromDateTime(_dueDate!);
      } else {
        initialTime = TimeOfDay.fromDateTime(now);
      }

      final pickedTime = await showTimePicker(
        context: context,
        initialTime: initialTime,
      );

      if (pickedTime != null && mounted) {
        final selectedDateTime = tz.TZDateTime.local(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        if (pickedDate.isAtSameMomentAs(today) && selectedDateTime.isBefore(now)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Please select a time in the future for today.',
                style: GoogleFonts.poppins(),
              ),
            ),
          );
          return;
        }

        setState(() {
          _dueDate = selectedDateTime;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = _supabaseClient.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task == null ? 'New Task' : 'Edit Task', style: GoogleFonts.poppins()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Task Title',
                  labelStyle: GoogleFonts.poppins(color: const Color(0xFF5D737E)),
                  prefixIcon: const Icon(Icons.task_alt, color: Color(0xFF5D737E)),
                  errorText: _titleController.text.isEmpty ? 'Title is required' : null,
                ),
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                value: _category,
                items: _categories
                    .map((cat) => DropdownMenuItem(
                  value: cat,
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: categoryColors[cat],
                          borderRadius: const BorderRadius.all(Radius.circular(4)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(cat, style: GoogleFonts.poppins()),
                    ],
                  ),
                ))
                    .toList(),
                onChanged: (value) => setState(() => _category = value!),
                decoration: InputDecoration(
                  labelText: 'Category',
                  labelStyle: GoogleFonts.poppins(color: const Color(0xFF5D737E)),
                  prefixIcon: const Icon(Icons.category_outlined, color: Color(0xFF5D737E)),
                ),
              ),
              const SizedBox(height: 24),
              if (_isLoadingLists)
                const Center(child: CircularProgressIndicator())
              else
                DropdownButtonFormField<String>(
                  value: _selectedListId,
                  items: [
                    DropdownMenuItem(value: null, child: Text('No List', style: GoogleFonts.poppins())),
                    ..._taskLists.map((list) => DropdownMenuItem(
                      value: list['id'],
                      child: Text(list['name'], style: GoogleFonts.poppins()),
                    )),
                  ],
                  onChanged: (value) => setState(() => _selectedListId = value),
                  decoration: InputDecoration(
                    labelText: 'Task List',
                    labelStyle: GoogleFonts.poppins(color: const Color(0xFF5D737E)),
                    prefixIcon: const Icon(Icons.list_alt_outlined, color: Color(0xFF5D737E)),
                  ),
                ),
              const SizedBox(height: 24),
              Card(
                child: ListTile(
                  title: Text(
                    _dueDate == null
                        ? 'Set Due Date'
                        : 'Due: ${DateFormat('MMM dd, yyyy HH:mm').format(_dueDate!)}',
                    style: GoogleFonts.poppins(),
                  ),
                  trailing: const Icon(Icons.calendar_today_outlined, color: Color(0xFFFF6F61)),
                  onTap: _selectDueDate,
                ),
              ),
              if (_dueDate != null) ...[
                const SizedBox(height: 16),
                ListTile(
                  title: Text('Remove Due Date', style: GoogleFonts.poppins(color: const Color(0xFFFF6F61))),
                  trailing: const Icon(Icons.cancel_outlined, color: Color(0xFF5D737E)),
                  onTap: () => setState(() {
                    _dueDate = null;
                  }),
                ),
              ],
              const SizedBox(height: 16),
              SwitchListTile(
                title: Text('Add to My Day', style: GoogleFonts.poppins()),
                value: _isInMyDay,
                onChanged: (value) => setState(() => _isInMyDay = value),
                activeColor: const Color(0xFFFF6F61),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6F61),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
                onPressed: _isSaving
                    ? null
                    : () async {
                  if (_titleController.text.isEmpty) {
                    setState(() {});
                    return;
                  }
                  if (userId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'You must be logged in to create or edit tasks.',
                          style: GoogleFonts.poppins(),
                        ),
                      ),
                    );
                    return;
                  }

                  setState(() => _isSaving = true);

                  final now = tz.TZDateTime.now(tz.local);
                  final newAddedDate = _isInMyDay ? now : tz.TZDateTime(tz.local, 2000);

                  final task = Task(
                    id: widget.task?.id ?? const Uuid().v4(),
                    title: _titleController.text,
                    category: _category,
                    dueDate: _dueDate,
                    isCompleted: widget.task?.isCompleted ?? false,
                    hasNotified: widget.task?.hasNotified ?? false,
                    isFavorite: widget.task?.isFavorite ?? false,
                    isImportant: widget.task?.isImportant ?? false,
                    addedDate: widget.task?.addedDate ?? newAddedDate,
                    completedDate: widget.task?.completedDate,
                    listId: _selectedListId,
                    snoozeDuration: widget.task?.snoozeDuration,
                    repeatOption: widget.task?.repeatOption,
                    order: widget.task?.order ?? 0,
                    pageOrder: widget.task?.pageOrder ?? {},
                    userId: userId,
                  );

                  if (widget.task == null) {
                    context.read<TaskBloc>().add(AddTask(task));
                  } else {
                    context.read<TaskBloc>().add(UpdateTask(task));
                  }

                  setState(() => _isSaving = false);
                  Navigator.pop(context, task);
                },
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text('Save', style: GoogleFonts.poppins(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}