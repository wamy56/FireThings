import 'package:flutter/material.dart';
import '../../../../models/dispatched_job.dart';
import '../../../../theme/web_theme.dart';
import 'schedule_job_block.dart';
import 'schedule_time_helpers.dart';
import 'schedule_week_grid.dart';

class ScheduleDayGrid extends StatelessWidget {
  final List<ScheduleEngineer> engineers;
  final ScheduleEngineer? unassignedRow;
  final Map<String?, List<DispatchedJob>> jobsByEngineer;
  final DateTime selectedDay;
  final ValueChanged<DispatchedJob>? onJobTap;
  final void Function(DispatchedJob job, DateTime targetDate, String? engineerId, String? engineerName)? onJobDrop;

  const ScheduleDayGrid({
    super.key,
    required this.engineers,
    this.unassignedRow,
    required this.jobsByEngineer,
    required this.selectedDay,
    this.onJobTap,
    this.onJobDrop,
  });

  static const _startHour = 7;
  static const _endHour = 19;
  static const _totalHours = 12;
  static const _hourHeight = 64.0;
  static const _labelWidth = 56.0;
  static const _minBlockHeight = 28.0;

  List<DispatchedJob> _jobsFor(String? engineerId) {
    return jobsByEngineer[engineerId] ?? [];
  }

  bool get _isToday {
    final now = DateTime.now();
    return selectedDay.year == now.year &&
        selectedDay.month == now.month &&
        selectedDay.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final allColumns = <ScheduleEngineer>[...engineers];
    final hasUnassigned = unassignedRow != null;

    return Container(
      color: FtColors.bg,
      child: Column(
        children: [
          _buildColumnHeaders(allColumns, hasUnassigned),
          Expanded(
            child: SingleChildScrollView(
              child: FocusTraversalGroup(
                policy: ReadingOrderTraversalPolicy(),
                child: SizedBox(
                  height: _totalHours * _hourHeight,
                  child: Stack(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHourLabels(),
                          for (final eng in allColumns)
                            Expanded(
                              child: _EngineerColumn(
                                engineer: eng,
                                jobs: _jobsFor(eng.id),
                                selectedDay: selectedDay,
                                isToday: _isToday,
                                onJobTap: onJobTap,
                                onJobDrop: onJobDrop,
                              ),
                            ),
                          if (hasUnassigned)
                            SizedBox(
                              width: 160,
                              child: _EngineerColumn(
                                engineer: unassignedRow!,
                                jobs: _jobsFor(null),
                                selectedDay: selectedDay,
                                isToday: _isToday,
                                isUnassigned: true,
                                onJobTap: onJobTap,
                                onJobDrop: onJobDrop,
                              ),
                            ),
                        ],
                      ),
                      if (_isToday) _buildNowIndicator(),
                    ],
                  ),
                ),
              ),
            ),
          ),
          _buildUntimedStrip(allColumns, hasUnassigned),
        ],
      ),
    );
  }

  Widget _buildColumnHeaders(List<ScheduleEngineer> columns, bool hasUnassigned) {
    return Container(
      decoration: const BoxDecoration(
        color: FtColors.bg,
        border: Border(bottom: BorderSide(color: FtColors.border, width: 2)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _labelWidth,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 14, 8, 14),
              child: Text(
                'HOUR',
                style: FtText.inter(
                  size: 11,
                  weight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: FtColors.hint,
                ),
              ),
            ),
          ),
          for (final eng in columns)
            Expanded(child: _ColumnHeader(engineer: eng)),
          if (hasUnassigned)
            SizedBox(width: 160, child: _ColumnHeader(engineer: unassignedRow!, isUnassigned: true)),
        ],
      ),
    );
  }

  Widget _buildHourLabels() {
    return SizedBox(
      width: _labelWidth,
      child: Column(
        children: [
          for (int h = _startHour; h < _endHour; h++)
            SizedBox(
              height: _hourHeight,
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8, top: 0),
                  child: Text(
                    '${h.toString().padLeft(2, '0')}:00',
                    style: FtText.mono(size: 10, weight: FontWeight.w600, color: FtColors.hint),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNowIndicator() {
    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final gridStartMinutes = _startHour * 60;
    final gridEndMinutes = _endHour * 60;
    if (nowMinutes < gridStartMinutes || nowMinutes > gridEndMinutes) {
      return const SizedBox.shrink();
    }
    final top = (nowMinutes - gridStartMinutes) / 60.0 * _hourHeight;
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: Row(
        children: [
          SizedBox(
            width: _labelWidth - 4,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: FtColors.danger,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(height: 2, color: FtColors.danger),
          ),
        ],
      ),
    );
  }

  Widget _buildUntimedStrip(List<ScheduleEngineer> columns, bool hasUnassigned) {
    final allUntimed = <String?, List<DispatchedJob>>{};
    bool hasAny = false;
    for (final eng in columns) {
      final untimed = _jobsFor(eng.id)
          .where((j) => parseScheduledTime(j.scheduledTime) == null)
          .toList();
      allUntimed[eng.id] = untimed;
      if (untimed.isNotEmpty) hasAny = true;
    }
    if (hasUnassigned) {
      final untimed = _jobsFor(null)
          .where((j) => parseScheduledTime(j.scheduledTime) == null)
          .toList();
      allUntimed[null] = untimed;
      if (untimed.isNotEmpty) hasAny = true;
    }

    if (!hasAny) return const SizedBox.shrink();

    return Container(
      decoration: const BoxDecoration(
        color: FtColors.bgAlt,
        border: Border(top: BorderSide(color: FtColors.border, width: 2)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _labelWidth,
            child: Padding(
              padding: const EdgeInsets.only(right: 8, top: 4),
              child: Align(
                alignment: Alignment.topRight,
                child: Text(
                  'NO\nTIME',
                  textAlign: TextAlign.right,
                  style: FtText.inter(size: 9, weight: FontWeight.w700, letterSpacing: 0.3, color: FtColors.hint),
                ),
              ),
            ),
          ),
          for (final eng in columns)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  children: [
                    for (final job in allUntimed[eng.id] ?? []) ...[
                      ScheduleJobBlock(
                        job: job,
                        onTap: onJobTap != null ? () => onJobTap!(job) : null,
                      ),
                      const SizedBox(height: 4),
                    ],
                  ],
                ),
              ),
            ),
          if (hasUnassigned)
            SizedBox(
              width: 160,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  children: [
                    for (final job in allUntimed[null] ?? []) ...[
                      ScheduleJobBlock(
                        job: job,
                        onTap: onJobTap != null ? () => onJobTap!(job) : null,
                      ),
                      const SizedBox(height: 4),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  final ScheduleEngineer engineer;
  final bool isUnassigned;

  const _ColumnHeader({required this.engineer, this.isUnassigned = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: FtColors.border, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isUnassigned ? Colors.transparent : engineer.color,
              shape: BoxShape.circle,
              border: isUnassigned
                  ? Border.all(color: const Color(0xFFB45309), width: 2, strokeAlign: BorderSide.strokeAlignInside)
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              isUnassigned ? '!' : engineer.initials,
              style: FtText.inter(
                size: 11,
                weight: FontWeight.w700,
                color: isUnassigned ? const Color(0xFFB45309) : Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            engineer.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: FtText.inter(
              size: 11,
              weight: FontWeight.w600,
              color: isUnassigned
                  ? const Color(0xFFB45309)
                  : !engineer.isActive
                      ? FtColors.hint
                      : FtColors.fg1,
            ),
          ),
        ],
      ),
    );
  }
}

class _EngineerColumn extends StatefulWidget {
  final ScheduleEngineer engineer;
  final List<DispatchedJob> jobs;
  final DateTime selectedDay;
  final bool isToday;
  final bool isUnassigned;
  final ValueChanged<DispatchedJob>? onJobTap;
  final void Function(DispatchedJob job, DateTime targetDate, String? engineerId, String? engineerName)? onJobDrop;

  const _EngineerColumn({
    required this.engineer,
    required this.jobs,
    required this.selectedDay,
    required this.isToday,
    this.isUnassigned = false,
    this.onJobTap,
    this.onJobDrop,
  });

  @override
  State<_EngineerColumn> createState() => _EngineerColumnState();
}

class _EngineerColumnState extends State<_EngineerColumn> {
  bool _isDragOver = false;

  List<DispatchedJob> get _timedJobs {
    return widget.jobs
        .where((j) => parseScheduledTime(j.scheduledTime) != null)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = !widget.engineer.isActive && !widget.isUnassigned;
    final engineerId = widget.isUnassigned ? null : widget.engineer.id;
    final engineerName = widget.isUnassigned ? null : widget.engineer.name;

    return DragTarget<DispatchedJob>(
      onWillAcceptWithDetails: (details) {
        if (isOffline) return false;
        setState(() => _isDragOver = true);
        return true;
      },
      onLeave: (_) => setState(() => _isDragOver = false),
      onAcceptWithDetails: (details) {
        setState(() => _isDragOver = false);
        widget.onJobDrop?.call(details.data, widget.selectedDay, engineerId, engineerName);
      },
      builder: (context, candidateData, rejectedData) {
        final hasDragOver = _isDragOver && candidateData.isNotEmpty;

        return Container(
          decoration: BoxDecoration(
            color: hasDragOver
                ? FtColors.accentSoft
                : isOffline
                    ? FtColors.bgSunken.withValues(alpha: 0.5)
                    : null,
            gradient: widget.isToday && !isOffline && !hasDragOver
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x0AFFB020), Colors.transparent],
                  )
                : null,
            border: hasDragOver
                ? Border.all(color: FtColors.accent, width: 2)
                : const Border(
                    right: BorderSide(color: FtColors.border, width: 1),
                  ),
          ),
          child: Stack(
            children: [
              for (int h = ScheduleDayGrid._startHour; h < ScheduleDayGrid._endHour; h++)
                Positioned(
                  top: (h - ScheduleDayGrid._startHour) * ScheduleDayGrid._hourHeight,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 1,
                    color: FtColors.border.withValues(alpha: 0.5),
                  ),
                ),
              for (final job in _timedJobs)
                _PositionedJobBlock(
                  job: job,
                  onTap: widget.onJobTap != null ? () => widget.onJobTap!(job) : null,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PositionedJobBlock extends StatelessWidget {
  final DispatchedJob job;
  final VoidCallback? onTap;

  const _PositionedJobBlock({required this.job, this.onTap});

  @override
  Widget build(BuildContext context) {
    final time = parseScheduledTime(job.scheduledTime);
    if (time == null) return const SizedBox.shrink();

    final startMinutes = time.hour * 60 + time.minute;
    final gridStartMinutes = ScheduleDayGrid._startHour * 60;
    final offsetMinutes = startMinutes - gridStartMinutes;
    final top = offsetMinutes / 60.0 * ScheduleDayGrid._hourHeight;

    final durationMinutes = parseDurationMinutes(job.estimatedDuration);
    final height = (durationMinutes / 60.0 * ScheduleDayGrid._hourHeight)
        .clamp(ScheduleDayGrid._minBlockHeight, double.infinity);

    return Positioned(
      top: top.clamp(0.0, double.infinity),
      left: 4,
      right: 4,
      height: height,
      child: ScheduleJobBlock(job: job, onTap: onTap),
    );
  }
}
