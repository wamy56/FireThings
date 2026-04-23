import 'package:flutter/material.dart';
import '../../../../models/dispatched_job.dart';
import '../../../../theme/web_theme.dart';
import 'schedule_job_block.dart';

class ScheduleDayCell extends StatefulWidget {
  final List<DispatchedJob> jobs;
  final DateTime date;
  final String? engineerId;
  final String? engineerName;
  final bool isToday;
  final bool isOffline;
  final ValueChanged<DispatchedJob>? onJobTap;
  final void Function(DispatchedJob job, DateTime targetDate, String? engineerId, String? engineerName)? onJobDrop;

  const ScheduleDayCell({
    super.key,
    required this.jobs,
    required this.date,
    this.engineerId,
    this.engineerName,
    this.isToday = false,
    this.isOffline = false,
    this.onJobTap,
    this.onJobDrop,
  });

  @override
  State<ScheduleDayCell> createState() => _ScheduleDayCellState();
}

class _ScheduleDayCellState extends State<ScheduleDayCell> {
  bool _hovered = false;
  bool _isDragOver = false;

  @override
  Widget build(BuildContext context) {
    return DragTarget<DispatchedJob>(
      onWillAcceptWithDetails: (details) {
        if (widget.isOffline) return false;
        setState(() => _isDragOver = true);
        return true;
      },
      onLeave: (_) => setState(() => _isDragOver = false),
      onAcceptWithDetails: (details) {
        setState(() => _isDragOver = false);
        widget.onJobDrop?.call(details.data, widget.date, widget.engineerId, widget.engineerName);
      },
      builder: (context, candidateData, rejectedData) {
        final hasDragOver = _isDragOver && candidateData.isNotEmpty;

        Color? bgColor;
        if (hasDragOver) {
          bgColor = FtColors.accentSoft;
        } else if (widget.isOffline) {
          bgColor = FtColors.bgSunken.withValues(alpha: 0.5);
        } else if (_hovered && !widget.isToday) {
          bgColor = FtColors.bgAlt;
        }

        return MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Container(
            constraints: const BoxConstraints(minHeight: 100),
            decoration: BoxDecoration(
              border: hasDragOver
                  ? Border.all(color: FtColors.accent, width: 2)
                  : const Border(
                      right: BorderSide(color: FtColors.border, width: 1),
                    ),
              gradient: widget.isToday && !widget.isOffline && !hasDragOver
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x0AFFB020), Colors.transparent],
                    )
                  : null,
              color: widget.isToday && !hasDragOver ? null : bgColor,
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < widget.jobs.length; i++) ...[
                  if (i > 0) const SizedBox(height: 5),
                  ScheduleJobBlock(
                    job: widget.jobs[i],
                    onTap: widget.onJobTap != null ? () => widget.onJobTap!(widget.jobs[i]) : null,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
