import 'package:flutter/material.dart';
import '../../../../models/dispatched_job.dart';
import '../../../../theme/web_theme.dart';
import 'schedule_day_header.dart';
import 'schedule_engineer_row.dart';

class ScheduleEngineer {
  final String id;
  final String name;
  final String initials;
  final Color color;
  final String presence;
  final bool isActive;
  final int weekJobCount;
  final String? offlineLabel;

  const ScheduleEngineer({
    required this.id,
    required this.name,
    required this.initials,
    required this.color,
    this.presence = 'online',
    this.isActive = true,
    this.weekJobCount = 0,
    this.offlineLabel,
  });
}

class ScheduleWeekGrid extends StatelessWidget {
  final List<ScheduleEngineer> engineers;
  final ScheduleEngineer? unassignedRow;
  final Map<String?, List<DispatchedJob>> jobsByEngineer;
  final DateTime weekStart;
  final ValueChanged<DispatchedJob>? onJobTap;
  final void Function(DispatchedJob job, DateTime targetDate, String? engineerId, String? engineerName)? onJobDrop;

  const ScheduleWeekGrid({
    super.key,
    required this.engineers,
    this.unassignedRow,
    required this.jobsByEngineer,
    required this.weekStart,
    this.onJobTap,
    this.onJobDrop,
  });

  List<List<DispatchedJob>> _splitIntoDays(String? engineerId) {
    final jobs = jobsByEngineer[engineerId] ?? [];
    final days = List.generate(7, (_) => <DispatchedJob>[]);

    for (final job in jobs) {
      if (job.scheduledDate == null) continue;
      final diff = job.scheduledDate!.difference(weekStart).inDays;
      if (diff >= 0 && diff < 7) {
        days[diff].add(job);
      }
    }

    for (final dayList in days) {
      dayList.sort((a, b) {
        final ta = a.scheduledTime ?? '';
        final tb = b.scheduledTime ?? '';
        return ta.compareTo(tb);
      });
    }

    return days;
  }

  int _jobCountForDay(int dayIndex) {
    int count = 0;
    for (final entry in jobsByEngineer.entries) {
      for (final job in entry.value) {
        if (job.scheduledDate == null) continue;
        if (job.scheduledDate!.difference(weekStart).inDays == dayIndex) {
          count++;
        }
      }
    }
    return count;
  }

  bool _isDayToday(int dayIndex) {
    final date = weekStart.add(Duration(days: dayIndex));
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: FtColors.bg,
      child: Column(
        children: [
          _buildDayHeaderRow(),
          Expanded(
            child: SingleChildScrollView(
              child: FocusTraversalGroup(
                policy: ReadingOrderTraversalPolicy(),
                child: Column(
                  children: [
                    for (final eng in engineers)
                      ScheduleEngineerRow(
                        engineer: eng,
                        jobsByDay: _splitIntoDays(eng.id),
                        weekStart: weekStart,
                        onJobTap: onJobTap,
                        onJobDrop: onJobDrop,
                      ),
                    if (unassignedRow != null)
                      ScheduleEngineerRow(
                        engineer: unassignedRow!,
                        jobsByDay: _splitIntoDays(null),
                        weekStart: weekStart,
                        isUnassigned: true,
                        onJobTap: onJobTap,
                        onJobDrop: onJobDrop,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeaderRow() {
    return Container(
      decoration: const BoxDecoration(
        color: FtColors.bg,
        border: Border(
          bottom: BorderSide(color: FtColors.border, width: 2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 180,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: const BoxDecoration(
              color: FtColors.bgAlt,
              border: Border(
                right: BorderSide(color: FtColors.border, width: 1),
              ),
            ),
            alignment: Alignment.centerLeft,
            child: Text(
              'ENGINEER',
              style: FtText.inter(
                size: 11,
                weight: FontWeight.w700,
                letterSpacing: 0.4,
                color: FtColors.hint,
              ),
            ),
          ),
          for (int i = 0; i < 7; i++)
            Expanded(
              child: ScheduleDayHeader(
                date: weekStart.add(Duration(days: i)),
                isToday: _isDayToday(i),
                jobCount: _jobCountForDay(i),
              ),
            ),
        ],
      ),
    );
  }
}
