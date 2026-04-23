import 'package:flutter/material.dart';
import '../../../../models/dispatched_job.dart';
import '../../../../theme/web_theme.dart';
import 'schedule_week_grid.dart';
import 'schedule_day_cell.dart';

class ScheduleEngineerRow extends StatelessWidget {
  final ScheduleEngineer engineer;
  final List<List<DispatchedJob>> jobsByDay;
  final DateTime weekStart;
  final bool isUnassigned;
  final ValueChanged<DispatchedJob>? onJobTap;
  final void Function(DispatchedJob job, DateTime targetDate, String? engineerId, String? engineerName)? onJobDrop;

  const ScheduleEngineerRow({
    super.key,
    required this.engineer,
    required this.jobsByDay,
    required this.weekStart,
    this.isUnassigned = false,
    this.onJobTap,
    this.onJobDrop,
  });

  bool _isDayToday(int dayIndex) {
    final date = weekStart.add(Duration(days: dayIndex));
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final rowBg = isUnassigned ? FtColors.warningSoft : null;

    return Container(
      decoration: BoxDecoration(
        color: rowBg,
        border: const Border(
          bottom: BorderSide(color: FtColors.border, width: 1),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _EngineerCell(
              engineer: engineer,
              isUnassigned: isUnassigned,
              backgroundColor: isUnassigned ? FtColors.warningSoft : FtColors.bgAlt,
            ),
            for (int i = 0; i < 7; i++)
              Expanded(
                child: ScheduleDayCell(
                  jobs: i < jobsByDay.length ? jobsByDay[i] : [],
                  date: weekStart.add(Duration(days: i)),
                  engineerId: isUnassigned ? null : engineer.id,
                  engineerName: isUnassigned ? null : engineer.name,
                  isToday: _isDayToday(i),
                  isOffline: !engineer.isActive && !isUnassigned,
                  onJobTap: onJobTap,
                  onJobDrop: onJobDrop,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EngineerCell extends StatelessWidget {
  final ScheduleEngineer engineer;
  final bool isUnassigned;
  final Color backgroundColor;

  const _EngineerCell({
    required this.engineer,
    required this.isUnassigned,
    required this.backgroundColor,
  });

  Color get _presenceColor {
    switch (engineer.presence) {
      case 'online':
        return FtColors.success;
      case 'onsite':
        return FtColors.warning;
      default:
        return FtColors.hint;
    }
  }

  Color get _loadBarColor {
    if (engineer.weekJobCount <= 0) return FtColors.bgSunken;
    final pct = engineer.weekJobCount / 12.0;
    if (pct > 0.75) return FtColors.danger;
    if (pct > 0.5) return FtColors.warning;
    return FtColors.success;
  }

  double get _loadBarFill {
    if (engineer.weekJobCount <= 0) return 0;
    return (engineer.weekJobCount / 12.0).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: const Border(
          right: BorderSide(color: FtColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          _buildAvatar(),
          const SizedBox(width: 11),
          Expanded(child: _buildInfo()),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final isOffline = !engineer.isActive;

    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 36,
            height: 36,
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
                size: 12,
                weight: FontWeight.w700,
                color: isUnassigned ? const Color(0xFFB45309) : Colors.white,
              ),
            ),
          ),
          if (!isUnassigned)
            Positioned(
              bottom: -1,
              right: -1,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: isOffline ? FtColors.hint : _presenceColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: backgroundColor, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfo() {
    final isOffline = !engineer.isActive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          engineer.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: FtText.inter(
            size: 13,
            weight: FontWeight.w600,
            color: isUnassigned
                ? const Color(0xFFB45309)
                : isOffline
                    ? FtColors.hint
                    : FtColors.fg1,
          ),
        ),
        const SizedBox(height: 2),
        if (isUnassigned)
          Text(
            '${engineer.weekJobCount} jobs need assigning',
            style: FtText.inter(
              size: 11,
              weight: FontWeight.w500,
              color: const Color(0xFFB45309),
            ).copyWith(height: 1),
          )
        else if (isOffline)
          Text(
            engineer.offlineLabel ?? 'Offline',
            style: FtText.inter(size: 11, weight: FontWeight.w500, color: FtColors.hint).copyWith(height: 1),
          )
        else
          Row(
            children: [
              SizedBox(
                width: 60,
                height: 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: _loadBarFill,
                    backgroundColor: FtColors.bgSunken,
                    valueColor: AlwaysStoppedAnimation(_loadBarColor),
                    minHeight: 3,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '${engineer.weekJobCount} jobs',
                style: FtText.inter(size: 11, weight: FontWeight.w500, color: FtColors.fg2).copyWith(height: 1),
              ),
            ],
          ),
      ],
    );
  }
}
