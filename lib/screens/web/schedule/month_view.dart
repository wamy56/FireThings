import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../models/dispatched_job.dart';
import '../../../utils/theme.dart';
import '../../../utils/icon_map.dart';
import 'job_block.dart';

/// Month calendar view with job pills in each day cell.
class ScheduleMonthView extends StatelessWidget {
  final List<DispatchedJob> allJobs;
  final DateTime focusedDay;
  final DateTime selectedDay;
  final bool isDark;
  final String? selectedJobId;
  final Color Function(DispatchedJob job) jobColorFn;
  final void Function(DateTime selected, DateTime focused) onDaySelected;
  final ValueChanged<DateTime> onPageChanged;
  final ValueChanged<String> onJobTap;

  const ScheduleMonthView({
    super.key,
    required this.allJobs,
    required this.focusedDay,
    required this.selectedDay,
    required this.isDark,
    required this.selectedJobId,
    required this.jobColorFn,
    required this.onDaySelected,
    required this.onPageChanged,
    required this.onJobTap,
  });

  List<DispatchedJob> _getJobsForDay(DateTime day) {
    return allJobs
        .where((job) =>
            job.scheduledDate != null && isSameDay(job.scheduledDate!, day))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: TableCalendar<DispatchedJob>(
            firstDay: DateTime(2020, 1, 1),
            lastDay: DateTime(2030, 12, 31),
            focusedDay: focusedDay,
            selectedDayPredicate: (day) => isSameDay(day, selectedDay),
            calendarFormat: CalendarFormat.month,
            startingDayOfWeek: StartingDayOfWeek.monday,
            availableCalendarFormats: const {CalendarFormat.month: 'Month'},
            headerVisible: false,
            eventLoader: _getJobsForDay,
            onDaySelected: onDaySelected,
            onPageChanged: onPageChanged,
            rowHeight: 90,
            daysOfWeekHeight: 32,
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
              ),
              weekendStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
              ),
            ),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: true,
              outsideTextStyle: TextStyle(
                color: (isDark ? Colors.white : AppTheme.darkGrey)
                    .withValues(alpha: 0.3),
              ),
              cellMargin: const EdgeInsets.all(2),
              cellPadding: EdgeInsets.zero,
              todayDecoration: const BoxDecoration(),
              selectedDecoration: const BoxDecoration(),
              defaultDecoration: const BoxDecoration(),
              weekendDecoration: const BoxDecoration(),
              outsideDecoration: const BoxDecoration(),
              markerDecoration: const BoxDecoration(),
              markersMaxCount: 0,
            ),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (ctx, day, focused) => _buildDayCell(
                  day, false, false, false),
              todayBuilder: (ctx, day, focused) => _buildDayCell(
                  day, true, isSameDay(day, selectedDay), false),
              selectedBuilder: (ctx, day, focused) => _buildDayCell(
                  day, isSameDay(day, DateTime.now()), true, false),
              outsideBuilder: (ctx, day, focused) =>
                  _buildDayCell(day, false, false, true),
            ),
          ),
        ),
        _buildSelectedDayJobs(),
      ],
    );
  }

  Widget _buildDayCell(
    DateTime day, bool isToday, bool isSelected, bool isOutside,
  ) {
    final jobs = _getJobsForDay(day);
    final textOpacity = isOutside ? 0.3 : 1.0;

    return Container(
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark
                ? AppTheme.accentOrange.withValues(alpha: 0.15)
                : AppTheme.accentOrange.withValues(alpha: 0.08))
            : isToday
                ? (isDark
                    ? AppTheme.darkPrimaryBlue.withValues(alpha: 0.08)
                    : AppTheme.primaryBlue.withValues(alpha: 0.04))
                : null,
        borderRadius: BorderRadius.circular(6),
        border: isSelected
            ? Border.all(color: AppTheme.accentOrange, width: 1.5)
            : Border.all(
                color: isDark ? AppTheme.darkDivider : AppTheme.dividerColor,
                width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: isToday
                      ? BoxDecoration(
                          color: isDark
                              ? AppTheme.darkPrimaryBlue
                              : AppTheme.primaryBlue,
                          shape: BoxShape.circle,
                        )
                      : null,
                  alignment: Alignment.center,
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                      color: isToday
                          ? Colors.white
                          : (isDark ? Colors.white : AppTheme.darkGrey)
                              .withValues(alpha: textOpacity),
                    ),
                  ),
                ),
                const Spacer(),
                if (jobs.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: (isDark
                              ? AppTheme.darkPrimaryBlue
                              : AppTheme.primaryBlue)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${jobs.length}',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppTheme.darkPrimaryBlue
                            : AppTheme.primaryBlue,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (jobs.isNotEmpty)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: jobs.take(3).map((job) {
                    final color = jobColorFn(job);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 1),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                        color: color.withValues(
                            alpha: isOutside ? 0.08 : 0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        job.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: color.withValues(
                              alpha: isOutside ? 0.4 : 0.9),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            )
          else
            const Spacer(),
        ],
      ),
    );
  }

  Widget _buildSelectedDayJobs() {
    final dayJobs = _getJobsForDay(selectedDay);
    final fmt = DateFormat('EEEE, MMM d');

    return Container(
      constraints: const BoxConstraints(maxHeight: 160),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
              color: isDark ? AppTheme.darkDivider : AppTheme.dividerColor),
        ),
        color: isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
            child: Row(
              children: [
                Text(
                  '${fmt.format(selectedDay)} (${dayJobs.length} ${dayJobs.length == 1 ? 'job' : 'jobs'})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.mediumGrey,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => onDaySelected(selectedDay, selectedDay),
                  icon: Icon(AppIcons.arrowRight, size: 14),
                  label: const Text('View Week',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          Expanded(
            child: dayJobs.isEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                    child: Text(
                      'No jobs scheduled for this day',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.mediumGrey,
                      ),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                    itemCount: dayJobs.length,
                    itemBuilder: (context, index) => SizedBox(
                      width: 180,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ScheduleJobBlock(
                          job: dayJobs[index],
                          isDark: isDark,
                          isSelected: selectedJobId == dayJobs[index].id,
                          color: jobColorFn(dayJobs[index]),
                          onTap: () => onJobTap(dayJobs[index].id),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
