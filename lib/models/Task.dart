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
  String? listId;
  int order;
  Map<String, int> pageOrder;

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
    this.listId,
    this.order = 0,
    Map<String, int>? pageOrder,
  })  : id = id ?? const Uuid().v4(),
        pageOrder = pageOrder ?? {};

  Color getCategoryColor() => categoryColors[category] ?? categoryColors['General']!;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category,
    'dueDate': dueDate?.toIso8601String(),
    'isCompleted': isCompleted ? 1 : 0,
    'hasNotified': hasNotified ? 1 : 0,
    'isFavorite': isFavorite ? 1 : 0,
    'isImportant': isImportant ? 1 : 0,
    'addedDate': addedDate.toIso8601String(),
    'listId': listId,
    'order': order,
    'pageOrder': pageOrder.map((key, value) => MapEntry(key, value.toString())),
    'repeatOption': null,
  };

  factory Task.fromJson(Map<String, dynamic> json, {String? inferredListId}) {
    final listIdFromJson = json['listId'] as String?;
    final effectiveListId = listIdFromJson ?? inferredListId;
    final pageOrderJson = json['pageOrder'] as Map<String, dynamic>? ?? {};
    final pageOrder = pageOrderJson.map((key, value) => MapEntry(key, int.parse(value.toString())));

    return Task(
      id: json['id'] as String? ?? const Uuid().v4(),
      title: json['title'] as String? ?? 'Untitled',
      category: json['category'] as String? ?? 'General',
      dueDate: json['dueDate'] != null ? DateTime.tryParse(json['dueDate'] as String) : null,
      isCompleted: (json['isCompleted'] as int? ?? 0) == 1,
      hasNotified: (json['hasNotified'] as int? ?? 0) == 1,
      isFavorite: (json['isFavorite'] as int? ?? 0) == 1,
      isImportant: (json['isImportant'] as int? ?? 0) == 1,
      addedDate: json['addedDate'] != null
          ? DateTime.tryParse(json['addedDate'] as String) ?? DateTime.now()
          : DateTime.now(),
      listId: effectiveListId,
      order: json['order'] as int? ?? 0,
      pageOrder: pageOrder,
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
    String? listId,
    int? order,
    Map<String, int>? pageOrder,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      dueDate: dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      hasNotified: hasNotified ?? this.hasNotified,
      isFavorite: isFavorite ?? this.isFavorite,
      isImportant: isImportant ?? this.isImportant,
      addedDate: addedDate ?? this.addedDate,
      listId: listId ?? this.listId,
      order: order ?? this.order,
      pageOrder: pageOrder ?? Map.from(this.pageOrder),
    );
  }
}