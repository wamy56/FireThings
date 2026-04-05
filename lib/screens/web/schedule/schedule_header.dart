import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../utils/theme.dart';
import '../../../utils/icon_map.dart';
import 'schedule_helpers.dart';

/// Header bar for the schedule screen with view toggle, colour toggle, and navigation.
class ScheduleHeader extends StatelessWidget {
  final ScheduleViewMode viewMode;
  final ValueChanged<ScheduleViewMode> onViewModeChanged;
  final bool colorByEngineer;
  final ValueChanged<bool> onColorModeChanged;
  final DateTime weekStart;
  final DateTime focusedDay;
  final DateTime selectedDay;
  final bool isDark;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onGoToToday;
  final void Function(DateTime selected) onDatePicked;

  /// Whether to show the Calendar/Map tab toggle (for narrower screens).
  final bool showMapToggle;
  final bool showMapTab;
  final ValueChanged<bool>? onMapToggle;

  const ScheduleHeader({
    super.key,
    required this.viewMode,
    required this.onViewModeChanged,
    required this.colorByEngineer,
    required this.onColorModeChanged,
    required this.weekStart,
    required this.focusedDay,
    required this.selectedDay,
    required this.isDark,
    required this.onPreviousWeek,
    required this.onNextWeek,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onGoToToday,
    required this.onDatePicked,
    this.showMapToggle = false,
    this.showMapTab = false,
    this.onMapToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Row(
        children: [
          Text(
            'Schedule',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          // View toggle
          SegmentedButton<ScheduleViewMode>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: ScheduleViewMode.week,
                label: const Text('Week'),
                icon: Icon(AppIcons.calendar, size: 16),
              ),
              ButtonSegment(
                value: ScheduleViewMode.month,
                label: const Text('Month'),
                icon: Icon(AppIcons.grid, size: 16),
              ),
              ButtonSegment(
                value: ScheduleViewMode.day,
                label: const Text('Day'),
                icon: Icon(AppIcons.clock, size: 16),
              ),
            ],
            selected: {viewMode},
            onSelectionChanged: (v) => onViewModeChanged(v.first),
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStatePropertyAll(
                TextStyle(fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Colour toggle
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: true, label: Text('By Engineer')),
              ButtonSegment(value: false, label: Text('By Status')),
            ],
            selected: {colorByEngineer},
            onSelectionChanged: (v) => onColorModeChanged(v.first),
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStatePropertyAll(
                TextStyle(fontSize: 12),
              ),
            ),
          ),
          // Map toggle (narrower screens only)
          if (showMapToggle && onMapToggle != null) ...[
            const SizedBox(width: 12),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: false,
                  label: const Text('Calendar'),
                  icon: Icon(AppIcons.calendar, size: 16),
                ),
                ButtonSegment(
                  value: true,
                  label: const Text('Map'),
                  icon: Icon(AppIcons.location, size: 16),
                ),
              ],
              selected: {showMapTab},
              onSelectionChanged: (v) => onMapToggle!(v.first),
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStatePropertyAll(
                  TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
          const SizedBox(width: 16),
          // Navigation
          if (viewMode == ScheduleViewMode.month)
            _buildMonthNav(context)
          else if (viewMode == ScheduleViewMode.day)
            _buildDayNav(context)
          else
            _buildWeekNav(context),
        ],
      ),
    );
  }

  Widget _buildWeekNav(BuildContext context) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    final fmt = DateFormat('MMM d');
    final today = DateTime.now();
    final isCurrentWeek = !weekStart.isAfter(today) && !weekEnd.isBefore(today);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPreviousWeek,
          icon: Icon(AppIcons.arrowLeft, size: 18),
          tooltip: 'Previous week',
        ),
        TextButton(
          onPressed: () => _showDatePickerDialog(context),
          child: Text(
            '${fmt.format(weekStart)} – ${fmt.format(weekEnd)}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.darkGrey,
            ),
          ),
        ),
        IconButton(
          onPressed: onNextWeek,
          icon: Icon(AppIcons.arrowRight, size: 18),
          tooltip: 'Next week',
        ),
        if (!isCurrentWeek) ...[
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onGoToToday,
            child: const Text('Today'),
          ),
        ],
      ],
    );
  }

  Widget _buildMonthNav(BuildContext context) {
    final fmt = DateFormat('MMMM yyyy');
    final today = DateTime.now();
    final isCurrentMonth = focusedDay.year == today.year && focusedDay.month == today.month;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPreviousMonth,
          icon: Icon(AppIcons.arrowLeft, size: 18),
          tooltip: 'Previous month',
        ),
        TextButton(
          onPressed: () => _showDatePickerDialog(context),
          child: Text(
            fmt.format(focusedDay),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.darkGrey,
            ),
          ),
        ),
        IconButton(
          onPressed: onNextMonth,
          icon: Icon(AppIcons.arrowRight, size: 18),
          tooltip: 'Next month',
        ),
        if (!isCurrentMonth) ...[
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onGoToToday,
            child: const Text('Today'),
          ),
        ],
      ],
    );
  }

  Widget _buildDayNav(BuildContext context) {
    final fmt = DateFormat('EEEE, MMM d yyyy');
    final today = DateTime.now();
    final isToday = selectedDay.year == today.year &&
        selectedDay.month == today.month &&
        selectedDay.day == today.day;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => onDatePicked(selectedDay.subtract(const Duration(days: 1))),
          icon: Icon(AppIcons.arrowLeft, size: 18),
          tooltip: 'Previous day',
        ),
        TextButton(
          onPressed: () => _showDatePickerDialog(context),
          child: Text(
            fmt.format(selectedDay),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.darkGrey,
            ),
          ),
        ),
        IconButton(
          onPressed: () => onDatePicked(selectedDay.add(const Duration(days: 1))),
          icon: Icon(AppIcons.arrowRight, size: 18),
          tooltip: 'Next day',
        ),
        if (!isToday) ...[
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onGoToToday,
            child: const Text('Today'),
          ),
        ],
      ],
    );
  }

  void _showDatePickerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        DateTime tempFocused = focusedDay;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => Dialog(
            alignment: Alignment.topCenter,
            insetPadding: const EdgeInsets.only(top: 70, left: 16, right: 16),
            child: Container(
              width: 350,
              padding: const EdgeInsets.all(16),
              child: TableCalendar(
                firstDay: DateTime(2020, 1, 1),
                lastDay: DateTime(2030, 12, 31),
                focusedDay: tempFocused,
                selectedDayPredicate: (day) => isSameDay(day, selectedDay),
                calendarFormat: CalendarFormat.month,
                startingDayOfWeek: StartingDayOfWeek.monday,
                availableCalendarFormats: const {CalendarFormat.month: 'Month'},
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: isDark ? Colors.white : AppTheme.darkGrey,
                  ),
                  leftChevronIcon: Icon(AppIcons.arrowLeft, size: 16),
                  rightChevronIcon: Icon(AppIcons.arrowRight, size: 16),
                ),
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: (isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue)
                        .withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: TextStyle(
                    color: isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue,
                    fontWeight: FontWeight.bold,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: AppTheme.accentOrange,
                    shape: BoxShape.circle,
                  ),
                  selectedTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onDaySelected: (selected, focused) {
                  onDatePicked(selected);
                  Navigator.pop(ctx);
                },
                onPageChanged: (focused) {
                  setDialogState(() => tempFocused = focused);
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
