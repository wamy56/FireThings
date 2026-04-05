import 'package:flutter/material.dart';
import '../../../models/dispatched_job.dart';
import '../../../utils/theme.dart';
import 'job_block.dart';

/// Callback for drag-and-drop rescheduling: job dropped on a new date.
typedef OnJobDroppedOnDate = void Function(DispatchedJob job, DateTime newDate);

/// Seven-column week grid showing job blocks per day.
/// Supports drag-and-drop rescheduling — jobs can be dragged between day columns.
class ScheduleWeekView extends StatelessWidget {
  final DateTime weekStart;
  final Map<int, List<DispatchedJob>> jobsByDay;
  final bool isDark;
  final String? selectedJobId;
  final bool colorByEngineer;
  final Color Function(DispatchedJob job) jobColorFn;
  final ValueChanged<String> onJobTap;
  final ValueChanged<DateTime> onDayHeaderTap;
  final OnJobDroppedOnDate? onJobDropped;

  const ScheduleWeekView({
    super.key,
    required this.weekStart,
    required this.jobsByDay,
    required this.isDark,
    required this.selectedJobId,
    required this.colorByEngineer,
    required this.jobColorFn,
    required this.onJobTap,
    required this.onDayHeaderTap,
    this.onJobDropped,
  });

  bool _canDrag(DispatchedJob job) {
    return job.status != DispatchedJobStatus.completed &&
        job.status != DispatchedJobStatus.declined;
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(7, (dayIndex) {
        final date = weekStart.add(Duration(days: dayIndex));
        final isToday = date.year == today.year &&
            date.month == today.month &&
            date.day == today.day;
        final jobs = jobsByDay[dayIndex] ?? [];

        return Expanded(
          child: _DayColumn(
            date: date,
            dayName: dayNames[dayIndex],
            isToday: isToday,
            isDark: isDark,
            jobs: jobs,
            selectedJobId: selectedJobId,
            jobColorFn: jobColorFn,
            canDrag: _canDrag,
            onJobTap: onJobTap,
            onDayHeaderTap: onDayHeaderTap,
            onJobDropped: onJobDropped,
            showLeftBorder: dayIndex > 0,
          ),
        );
      }),
    );
  }
}

class _DayColumn extends StatefulWidget {
  final DateTime date;
  final String dayName;
  final bool isToday;
  final bool isDark;
  final List<DispatchedJob> jobs;
  final String? selectedJobId;
  final Color Function(DispatchedJob job) jobColorFn;
  final bool Function(DispatchedJob job) canDrag;
  final ValueChanged<String> onJobTap;
  final ValueChanged<DateTime> onDayHeaderTap;
  final OnJobDroppedOnDate? onJobDropped;
  final bool showLeftBorder;

  const _DayColumn({
    required this.date,
    required this.dayName,
    required this.isToday,
    required this.isDark,
    required this.jobs,
    required this.selectedJobId,
    required this.jobColorFn,
    required this.canDrag,
    required this.onJobTap,
    required this.onDayHeaderTap,
    required this.onJobDropped,
    required this.showLeftBorder,
  });

  @override
  State<_DayColumn> createState() => _DayColumnState();
}

class _DayColumnState extends State<_DayColumn> {
  bool _isDragOver = false;

  @override
  Widget build(BuildContext context) {
    return DragTarget<DispatchedJob>(
      onWillAcceptWithDetails: (details) {
        setState(() => _isDragOver = true);
        return true;
      },
      onLeave: (data) => setState(() => _isDragOver = false),
      onAcceptWithDetails: (details) {
        setState(() => _isDragOver = false);
        widget.onJobDropped?.call(details.data, widget.date);
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          decoration: BoxDecoration(
            border: Border(
              left: widget.showLeftBorder
                  ? BorderSide(
                      color: widget.isDark
                          ? AppTheme.darkDivider
                          : AppTheme.dividerColor)
                  : BorderSide.none,
            ),
            color: _isDragOver
                ? (widget.isDark
                    ? AppTheme.accentOrange.withValues(alpha: 0.12)
                    : AppTheme.accentOrange.withValues(alpha: 0.08))
                : widget.isToday
                    ? (widget.isDark
                        ? AppTheme.darkPrimaryBlue.withValues(alpha: 0.08)
                        : AppTheme.primaryBlue.withValues(alpha: 0.04))
                    : null,
          ),
          child: Column(
            children: [
              // Day header
              GestureDetector(
                onTap: () => widget.onDayHeaderTap(widget.date),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: widget.isDark
                            ? AppTheme.darkDivider
                            : AppTheme.dividerColor,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        widget.dayName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: widget.isToday
                              ? (widget.isDark
                                  ? AppTheme.darkPrimaryBlue
                                  : AppTheme.primaryBlue)
                              : (widget.isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.mediumGrey),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: widget.isToday
                            ? BoxDecoration(
                                color: widget.isDark
                                    ? AppTheme.darkPrimaryBlue
                                    : AppTheme.primaryBlue,
                                shape: BoxShape.circle,
                              )
                            : null,
                        alignment: Alignment.center,
                        child: Text(
                          '${widget.date.day}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: widget.isToday
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: widget.isToday
                                ? Colors.white
                                : (widget.isDark
                                    ? Colors.white
                                    : AppTheme.darkGrey),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Jobs list
              Expanded(
                child: widget.jobs.isEmpty
                    ? const SizedBox.shrink()
                    : ListView.builder(
                        padding: const EdgeInsets.all(4),
                        itemCount: widget.jobs.length,
                        itemBuilder: (context, index) {
                          final job = widget.jobs[index];
                          final block = ScheduleJobBlock(
                            job: job,
                            isDark: widget.isDark,
                            isSelected: widget.selectedJobId == job.id,
                            color: widget.jobColorFn(job),
                            onTap: () => widget.onJobTap(job.id),
                          );

                          if (!widget.canDrag(job)) return block;

                          return Draggable<DispatchedJob>(
                            data: job,
                            feedback: Material(
                              elevation: 4,
                              borderRadius: BorderRadius.circular(6),
                              child: SizedBox(
                                width: 140,
                                child: Opacity(opacity: 0.85, child: block),
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.3,
                              child: block,
                            ),
                            child: block,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
