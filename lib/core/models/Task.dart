import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class Task {
  String id;
  String title;
  String category;
  DateTime? dueDate;
  bool isCompleted;
  bool hasNotified;
  bool isFavorite;
  bool isImportant;
  DateTime addedDate;
  DateTime? completedDate;
  String? listId;
  int order;
  int? snoozeDuration;
  String? repeatOption;
  Map<String, int> pageOrder;
  String userId;

  static Map<String, Color> categoryColors = {
    'General': Color(0xFF5D737E),
    'Work': Color(0xFFFF6F61),
    'Personal': Color(0xFF8D5522),
    'Urgent': Color(0xFF8A2BE2),
  };

  Task({
    String? id,
    required this.title,
    this.category = 'General',
    this.dueDate,
    this.isCompleted = false,
    this.hasNotified = false,
    this.isFavorite = false,
    this.isImportant = false,
    required this.addedDate,
    this.completedDate,
    this.listId,
    this.snoozeDuration,
    this.repeatOption,
    this.order = 0,
    Map<String, int>? pageOrder,
    required this.userId,
  })  : id = id ?? const Uuid().v4(),
        pageOrder = pageOrder ?? {};

  Color getCategoryColor() => categoryColors[category] ?? categoryColors['General']!;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category,
    'due_date': dueDate?.toIso8601String(),
    'is_completed': isCompleted ? 1 : 0,
    'has_notified': hasNotified ? 1 : 0,
    'is_favorite': isFavorite ? 1 : 0,
    'is_important': isImportant ? 1 : 0,
    'added_date': addedDate.toIso8601String(),
    'completed_date': completedDate?.toIso8601String(),
    'list_id': listId,
    'order': order,
    'snooze_duration': snoozeDuration,
    'repeat_option': repeatOption,
    'page_order': pageOrder,
    'user_id': userId,
  };

  factory Task.fromJson(Map<String, dynamic> json, {String? inferredListId}) {
    final listIdFromJson = json['list_id'] as String?;
    final effectiveListId = listIdFromJson ?? inferredListId;
    final pageOrderJson = json['page_order'] as Map<String, dynamic>? ?? {};
    final pageOrder = pageOrderJson.map((key, value) => MapEntry(key, int.parse(value.toString())));

    bool parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is int) return value == 1;
      return false;
    }

    return Task(
      id: json['id'] as String? ?? const Uuid().v4(),
      title: json['title'] as String? ?? 'Untitled',
      category: json['category'] as String? ?? 'General',
      dueDate: json['due_date'] != null ? DateTime.tryParse(json['due_date'] as String) : null,
      isCompleted: parseBool(json['is_completed']),
      hasNotified: parseBool(json['has_notified']),
      isFavorite: parseBool(json['is_favorite']),
      isImportant: parseBool(json['is_important']),
      completedDate: json['completed_date'] != null ? DateTime.tryParse(json['completed_date'] as String) : null,
      snoozeDuration: json['snooze_duration'] as int?,
      repeatOption: json['repeat_option'] as String?,
      addedDate: json['added_date'] != null
          ? DateTime.tryParse(json['added_date'] as String) ?? DateTime.now()
          : DateTime.now(),
      listId: effectiveListId,
      order: json['order'] as int? ?? 0,
      pageOrder: pageOrder,
      userId: json['user_id'] as String,
    );
  }

  String getFormattedDueDate() {
    if (dueDate == null) return 'No due date';
    try {
      return DateFormat('MMM dd, yyyy HH:mm').format(dueDate!);
    } catch (e) {
      return 'No due date';
    }
  }

  bool isInMyDay() {
    final now = DateTime.now();
    final midnightToday = DateTime(now.year, now.month, now.day, 0, 0);
    return addedDate.isAfter(midnightToday.subtract(const Duration(days: 1))) &&
        addedDate.isBefore(midnightToday.add(const Duration(days: 1)));
  }

  Task copyWith({
    String? id,
    String? title,
    String? category,
    DateTime? dueDate,
    bool? isCompleted,
    bool? hasNotified,
    bool? isFavorite,
    bool? isImportant,
    DateTime? addedDate,
    DateTime? completedDate,
    String? listId,
    int? snoozeDuration,
    String? repeatOption,
    int? order,
    Map<String, int>? pageOrder,
    String? userId,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      hasNotified: hasNotified ?? this.hasNotified,
      isFavorite: isFavorite ?? this.isFavorite,
      isImportant: isImportant ?? this.isImportant,
      addedDate: addedDate ?? this.addedDate,
      completedDate: completedDate ?? this.completedDate,
      listId: listId ?? this.listId,
      snoozeDuration: snoozeDuration ?? this.snoozeDuration,
      repeatOption: repeatOption ?? this.repeatOption,
      order: order ?? this.order,
      pageOrder: pageOrder ?? Map.from(this.pageOrder),
      userId: userId ?? this.userId,
    );
  }
}