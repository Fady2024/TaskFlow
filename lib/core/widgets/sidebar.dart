import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../theme/theme_provider.dart';
import '../services/task_service.dart';
import '../../features/task/bloc/task_bloc.dart';
import '../../features/task/bloc/task_state.dart';

class Sidebar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;
  final List<Map<String, dynamic>> customLists;
  final VoidCallback onAddNewList;
  final Function(String, int) onDeleteList;
  final bool isDrawerExpanded;
  final bool isDrawerPinned;
  final VoidCallback onTogglePin;
  final VoidCallback onToggleExpansion;

  const Sidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    required this.customLists,
    required this.onAddNewList,
    required this.onDeleteList,
    required this.isDrawerExpanded,
    required this.isDrawerPinned,
    required this.onTogglePin,
    required this.onToggleExpansion,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  final TaskService _taskService = TaskService();
  bool _isProductivityExpanded = false;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);

    return Container(
      width: widget.isDrawerExpanded ? 280 : 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: themeProvider.themeMode == ThemeMode.dark
              ? [const Color(0xFF2A3756), const Color(0xFF1F2A44)]
              : [const Color(0xFFFDFDFD), const Color(0xFFECEFF1)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: BlocBuilder<TaskBloc, TaskState>(
        builder: (context, state) {
          int myDayCount = 0;
          int importantCount = 0;
          int plannedCount = 0;
          int favoriteCount = 0;
          int allTasksCount = 0;

          if (state is TasksLoaded) {
            myDayCount = state.tasks.where((t) => t.isInMyDay()).length;
            importantCount = state.tasks.where((t) => t.isImportant).length;
            plannedCount = state.tasks.where((t) => t.dueDate != null).length;
            favoriteCount = state.tasks.where((t) => t.isFavorite).length;
            allTasksCount = state.tasks.length;
          }

          return Column(
            children: [
              _buildSidebarHeader(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _buildDrawerItem(0, Icons.wb_sunny_outlined, 'My Day',
                        color: const Color(0xFFF1C40F), badgeCount: myDayCount),
                    _buildDrawerItem(1, Icons.star_border, 'Important',
                        color: const Color(0xFFE74C3C), badgeCount: importantCount),
                    _buildDrawerItem(2, Icons.calendar_today_outlined, 'Planned',
                        color: const Color(0xFF3498DB), badgeCount: plannedCount),
                    _buildDrawerItem(3, Icons.favorite_border, 'Favorite',
                        color: const Color(0xFFE91E63), badgeCount: favoriteCount),
                    _buildDrawerItem(4, Icons.task_alt_outlined, 'All Tasks',
                        color: const Color(0xFF2ECC71), badgeCount: allTasksCount),
                    _buildSeparator(),
                    _buildDrawerItem(
                      5,
                      Icons.trending_up,
                      'Productivity & Analytics',
                      color: const Color(0xFF00B4D8),
                      onTap: () {
                        widget.onItemTapped(5);
                        setState(() {
                          _isProductivityExpanded = !_isProductivityExpanded;
                        });
                        if (!widget.isDrawerPinned) Navigator.pop(context);
                      },
                    ),
                    _buildDrawerItem(
                      6,
                      Icons.timer,
                      'Pomodoro Timer',
                      color: const Color(0xFF00B4D8),
                    ),
                    if (_isProductivityExpanded && widget.isDrawerExpanded)
                      Column(
                        children: [
                          _buildSubDrawerItem(7, Icons.bar_chart, 'Task Completion Rate',
                              color: const Color(0xFF00B4D8)),
                          _buildSubDrawerItem(8, Icons.show_chart, 'Daily/Weekly Progress',
                              color: const Color(0xFF00B4D8)),
                        ],
                      ),
                    _buildSeparator(),
                    ...widget.customLists.asMap().entries.map((entry) => _buildCustomListItem(entry)),
                    _buildDrawerItem(-1, Icons.add_circle_outline, 'Add List',
                        color: const Color(0xFF9B59B6), onTap: widget.onAddNewList),
                    _buildSeparator(),
                  ],
                ),
              ),
              _buildDrawerItem(
                -2,
                themeProvider.themeMode == ThemeMode.dark
                    ? Icons.wb_sunny_outlined
                    : Icons.nightlight_outlined,
                'Toggle Theme',
                color: const Color(0xFF34495E),
                onTap: () => themeProvider.toggleTheme(themeProvider.themeMode != ThemeMode.dark),
              ),
              _buildDrawerItem(
                -3,
                widget.isDrawerPinned ? Icons.push_pin : Icons.push_pin_outlined,
                widget.isDrawerPinned ? 'Unpin' : 'Pin',
                color: const Color(0xFF7F8C8D),
                onTap: widget.onTogglePin,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSidebarHeader() {
    final theme = Theme.of(context);
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          widget.isDrawerExpanded
              ? Expanded(
            child: Text(
              'TaskFlow',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          )
              : const Icon(Icons.task_alt, color: Colors.white, size: 28),
          if (!widget.isDrawerPinned)
            SizedBox(
              width: 28,
              height: 28,
              child: IconButton(
                icon: Icon(
                  widget.isDrawerExpanded ? Icons.chevron_left : Icons.chevron_right,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: widget.onToggleExpansion,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(int index, IconData icon, String title,
      {Widget? trailing, VoidCallback? onTap, required Color color, int badgeCount = 0}) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: widget.selectedIndex == index ? color.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topRight,
          children: [
            Icon(
              icon,
              color: widget.selectedIndex == index ? color : theme.iconTheme.color?.withOpacity(0.7),
              size: 24,
            ),
            if (badgeCount > 0 && !widget.isDrawerExpanded)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    '$badgeCount',
                    style: GoogleFonts.poppins(fontSize: 10, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        title: widget.isDrawerExpanded
            ? Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: widget.selectedIndex == index ? color : theme.textTheme.bodyMedium?.color,
                ),
              ),
            ),
            if (badgeCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$badgeCount',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        )
            : null,
        trailing: trailing,
        selected: widget.selectedIndex == index,
        onTap: onTap ??
                () {
              widget.onItemTapped(index);
              if (!widget.isDrawerPinned) Navigator.pop(context);
            },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildSubDrawerItem(int index, IconData icon, String title, {required Color color}) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(left: 32, right: 8, top: 2, bottom: 2),
      decoration: BoxDecoration(
        color: widget.selectedIndex == index ? color.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: widget.selectedIndex == index ? color : theme.iconTheme.color?.withOpacity(0.7),
          size: 20,
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: widget.selectedIndex == index ? color : theme.textTheme.bodyMedium?.color,
          ),
        ),
        selected: widget.selectedIndex == index,
        onTap: () {
          widget.onItemTapped(index);
          if (!widget.isDrawerPinned) Navigator.pop(context);
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildCustomListItem(MapEntry<int, Map<String, dynamic>> entry) {
    final index = 6 + entry.key + 2;
    final list = entry.value;
    final theme = Theme.of(context);
    const color = Color(0xFF00CEC9);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: widget.selectedIndex == index ? color.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: FutureBuilder<int>(
        future: _taskService.getTaskCount(list['id'] as String),
        builder: (context, snapshot) {
          final count = snapshot.data ?? 0;
          return ListTile(
            leading: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topRight,
              children: [
                Icon(
                  Icons.list_alt_outlined,
                  color: widget.selectedIndex == index ? color : theme.iconTheme.color?.withOpacity(0.7),
                  size: 24,
                ),
                if (count > 0 && !widget.isDrawerExpanded)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '$count',
                        style: GoogleFonts.poppins(fontSize: 10, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            title: widget.isDrawerExpanded
                ? Row(
              children: [
                Expanded(
                  child: Text(
                    list['name'] as String,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: widget.selectedIndex == index ? color : theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
                if (count > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            )
                : null,
            trailing: widget.isDrawerExpanded
                ? IconButton(
              icon: const Icon(Icons.delete_outline, color: Color(0xFFE74C3C), size: 20),
              onPressed: () => widget.onDeleteList(list['id'] as String, index),
            )
                : null,
            selected: widget.selectedIndex == index,
            onTap: () {
              widget.onItemTapped(index);
              if (!widget.isDrawerPinned) Navigator.pop(context);
            },
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            dense: true,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          );
        },
      ),
    );
  }

  Widget _buildSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 2,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF1C40F), Color(0xFFE74C3C), Color(0xFF3498DB)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.star,
            size: 8,
            color: Color(0xFFE91E63),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 2,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF3498DB), Color(0xFFE74C3C), Color(0xFFF1C40F)],
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}