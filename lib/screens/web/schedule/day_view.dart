import 'package:flutter/material.dart';
import '../../../models/dispatched_job.dart';
import '../../../utils/theme.dart';
import 'job_block.dart';

/// Parses a time string like "09:00", "9:00", "2:30 PM" into a TimeOfDay.
TimeOfDay? parseScheduledTime(String? time) {
  if (time == null || time.trim().isEmpty) return null;
  final t = time.trim().toUpperCase();

  // Try HH:mm or H:mm
  final match24 = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(t);
  if (match24 != null) {
    final h = int.parse(match24.group(1)!);
    final m = int.parse(match24.group(2)!);
    if (h >= 0 && h < 24 && m >= 0 && m < 60) {
      return TimeOfDay(hour: h, minute: m);
    }
  }

  // Try HH:mm AM/PM
  final match12 =
      RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$').firstMatch(t);
  if (match12 != null) {
    var h = int.parse(match12.group(1)!);
    final m = int.parse(match12.group(2)!);
    final ampm = match12.group(3)!;
    if (ampm == 'PM' && h != 12) h += 12;
    if (ampm == 'AM' && h == 12) h = 0;
    if (h >= 0 && h < 24 && m >= 0 && m < 60) {
      return TimeOfDay(hour: h, minute: m);
    }
  }

  return null;
}

/// Parses an estimated duration string into minutes.
/// Handles: "1 hour", "1.5 hours", "2h", "90 mins", "1h30m", "30 minutes".
int parseDurationMinutes(String? duration) {
  if (duration == null || duration.trim().isEmpty) return 60;
  final d = duration.trim().toLowerCase();

  // "1h30m" or "1h 30m"
  final hm = RegExp(r'(\d+)\s*h\s*(\d+)\s*m').firstMatch(d);
  if (hm != null) {
    return int.parse(hm.group(1)!) * 60 + int.parse(hm.group(2)!);
  }

  // "1.5 hours" or "1.5h"
  final decimalHours = RegExp(r'(\d+\.?\d*)\s*h').firstMatch(d);
  if (decimalHours != null) {
    return (double.parse(decimalHours.group(1)!) * 60).round();
  }

  // "90 mins" or "90 minutes" or "90min"
  final mins = RegExp(r'(\d+)\s*min').firstMatch(d);
  if (mins != null) {
    return int.parse(mins.group(1)!);
  }

  // "1.5 hours" (word form)
  final wordHours = RegExp(r'(\d+\.?\d*)\s*hour').firstMatch(d);
  if (wordHours != null) {
    return (double.parse(wordHours.group(1)!) * 60).round();
  }

  return 60; // Default 1 hour
}

/// Google Calendar-style single-day view with hourly time slots.
class ScheduleDayView extends StatelessWidget {
  final DateTime date;
  final List<DispatchedJob> dayJobs;
  final bool isDark;
  final String? selectedJobId;
  final Color Function(DispatchedJob job) jobColorFn;
  final ValueChanged<String> onJobTap;

  const ScheduleDayView({
    super.key,
    required this.date,
    required this.dayJobs,
    required this.isDark,
    required this.selectedJobId,
    required this.jobColorFn,
    required this.onJobTap,
  });

  static const _startHour = 6;
  static const _endHour = 21; // 9 PM
  static const _hourHeight = 60.0;
  static const _totalHours = _endHour - _startHour;

  @override
  Widget build(BuildContext context) {
    // Split jobs into timed and untimed
    final timedJobs = <DispatchedJob>[];
    final untimedJobs = <DispatchedJob>[];
    for (final job in dayJobs) {
      final time = parseScheduledTime(job.scheduledTime);
      if (time != null) {
        timedJobs.add(job);
      } else {
        untimedJobs.add(job);
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Untimed jobs sidebar
        _buildUntimedSidebar(untimedJobs),
        VerticalDivider(
          width: 1,
          color: isDark ? AppTheme.darkDivider : AppTheme.dividerColor,
        ),
        // Time grid
        Expanded(child: _buildTimeGrid(timedJobs)),
      ],
    );
  }

  Widget _buildUntimedSidebar(List<DispatchedJob> jobs) {
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Text(
              'Unslotted (${jobs.length})',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
              ),
            ),
          ),
          Expanded(
            child: jobs.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'No unslotted jobs',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.mediumGrey,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: jobs.length,
                    itemBuilder: (context, index) {
                      final job = jobs[index];
                      return ScheduleJobBlock(
                        job: job,
                        isDark: isDark,
                        isSelected: selectedJobId == job.id,
                        color: jobColorFn(job),
                        onTap: () => onJobTap(job.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeGrid(List<DispatchedJob> timedJobs) {
    // Group jobs by engineer for column layout
    final columns = _buildColumns(timedJobs);

    return SingleChildScrollView(
      child: SizedBox(
        height: _totalHours * _hourHeight + 20, // Extra padding at bottom
        child: Stack(
          children: [
            // Hour lines and labels
            ...List.generate(_totalHours + 1, (i) {
              final hour = _startHour + i;
              final y = i * _hourHeight;
              return Positioned(
                top: y,
                left: 0,
                right: 0,
                child: Row(
                  children: [
                    SizedBox(
                      width: 48,
                      child: Text(
                        '${hour.toString().padLeft(2, '0')}:00',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.mediumGrey,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 0.5,
                        color: isDark
                            ? AppTheme.darkDivider
                            : AppTheme.dividerColor,
                      ),
                    ),
                  ],
                ),
              );
            }),
            // Now indicator
            if (_isToday())
              Positioned(
                top: _timeToY(TimeOfDay.now()),
                left: 48,
                right: 0,
                child: Container(
                  height: 2,
                  color: AppTheme.errorRed,
                ),
              ),
            // Job blocks
            Padding(
              padding: const EdgeInsets.only(left: 56),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final availableWidth = constraints.maxWidth;
                  final colCount = columns.length.clamp(1, 10);
                  final colWidth = availableWidth / colCount;

                  return Stack(
                    children: [
                      for (var colIdx = 0; colIdx < columns.length; colIdx++)
                        for (final job in columns[colIdx])
                          _buildTimedJobBlock(
                            job,
                            colIdx * colWidth,
                            colWidth - 4, // 4px gap between columns
                          ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Groups timed jobs into columns. Jobs for the same engineer go in the
  /// same column; overlapping jobs for different engineers get separate columns.
  List<List<DispatchedJob>> _buildColumns(List<DispatchedJob> timedJobs) {
    if (timedJobs.isEmpty) return [];

    // Sort by time
    final sorted = List<DispatchedJob>.from(timedJobs)
      ..sort((a, b) {
        final ta = parseScheduledTime(a.scheduledTime)!;
        final tb = parseScheduledTime(b.scheduledTime)!;
        return (ta.hour * 60 + ta.minute).compareTo(tb.hour * 60 + tb.minute);
      });

    // Group by engineer
    final Map<String, List<DispatchedJob>> byEngineer = {};
    for (final job in sorted) {
      final key = job.assignedTo ?? 'unassigned';
      byEngineer.putIfAbsent(key, () => []).add(job);
    }

    return byEngineer.values.toList();
  }

  Widget _buildTimedJobBlock(DispatchedJob job, double left, double width) {
    final time = parseScheduledTime(job.scheduledTime)!;
    final durationMins = parseDurationMinutes(job.estimatedDuration);
    final y = _timeToY(time);
    final height = (durationMins / 60.0 * _hourHeight).clamp(24.0, _totalHours * _hourHeight);
    final color = jobColorFn(job);
    final isSelected = selectedJobId == job.id;

    return Positioned(
      top: y,
      left: left,
      width: width,
      height: height,
      child: GestureDetector(
        onTap: () => onJobTap(job.id),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isSelected ? 0.35 : 0.2),
            borderRadius: BorderRadius.circular(6),
            border: isSelected
                ? Border.all(color: color, width: 2)
                : Border.all(color: color.withValues(alpha: 0.4)),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                job.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppTheme.darkGrey,
                ),
              ),
              if (height > 36 && job.assignedToName != null)
                Text(
                  job.assignedToName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.mediumGrey,
                  ),
                ),
              if (height > 50)
                Text(
                  '${job.scheduledTime}${job.estimatedDuration != null ? ' · ${job.estimatedDuration}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  double _timeToY(TimeOfDay time) {
    final minutes = (time.hour - _startHour) * 60 + time.minute;
    return minutes / 60.0 * _hourHeight;
  }

  bool _isToday() {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}
