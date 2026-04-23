import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../models/dispatched_job.dart';
import '../../../../theme/web_theme.dart';

class ScheduleJobBlock extends StatefulWidget {
  final DispatchedJob job;
  final VoidCallback? onTap;

  const ScheduleJobBlock({super.key, required this.job, this.onTap});

  @override
  State<ScheduleJobBlock> createState() => _ScheduleJobBlockState();
}

class _ScheduleJobBlockState extends State<ScheduleJobBlock>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  bool _focused = false;
  AnimationController? _pulseController;

  bool get _isInProgress =>
      widget.job.status == DispatchedJobStatus.onSite ||
      widget.job.status == DispatchedJobStatus.enRoute;

  bool get _isCompleted =>
      widget.job.status == DispatchedJobStatus.completed;

  bool get _isEmergency =>
      widget.job.priority == JobPriority.emergency;

  @override
  void initState() {
    super.initState();
    if (_isInProgress) {
      _pulseController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 2),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  Color get _borderColor {
    if (_isInProgress) return FtColors.accent;
    if (_isCompleted) return FtColors.success;
    switch (widget.job.priority) {
      case JobPriority.emergency:
        return FtColors.danger;
      case JobPriority.urgent:
        return FtColors.warning;
      case JobPriority.normal:
        return FtColors.info;
    }
  }

  BoxDecoration get _decoration {
    final base = BoxDecoration(
      borderRadius: BorderRadius.circular(7),
      border: Border(
        left: BorderSide(color: _borderColor, width: 3),
      ),
      boxShadow: _hovered
          ? FtShadows.sm
          : const [BoxShadow(color: Color(0x0A000000), offset: Offset(0, 1), blurRadius: 2)],
    );

    if (_isInProgress) {
      return base.copyWith(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FtColors.accentSoft, FtColors.bg],
        ),
        border: Border(
          left: BorderSide(color: FtColors.accent, width: 3),
          top: BorderSide(color: FtColors.accent, width: 1),
          right: BorderSide(color: FtColors.accent, width: 1),
          bottom: BorderSide(color: FtColors.accent, width: 1),
        ),
        boxShadow: [
          const BoxShadow(color: Color(0x26FFB020), blurRadius: 8),
          if (_hovered) ...FtShadows.sm,
        ],
      );
    }

    if (_isCompleted) {
      return base.copyWith(color: FtColors.successSoft);
    }

    if (_isEmergency) {
      return base.copyWith(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FtColors.dangerSoft, FtColors.bg],
        ),
      );
    }

    return base.copyWith(color: FtColors.bg);
  }

  BoxDecoration get _feedbackDecoration {
    final base = BoxDecoration(
      borderRadius: BorderRadius.circular(7),
      border: Border(
        left: BorderSide(color: _borderColor, width: 3),
      ),
      boxShadow: const [BoxShadow(color: Color(0x1A000000), offset: Offset(0, 4), blurRadius: 12)],
    );

    if (_isInProgress) {
      return base.copyWith(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FtColors.accentSoft, FtColors.bg],
        ),
      );
    }
    if (_isCompleted) return base.copyWith(color: FtColors.successSoft);
    if (_isEmergency) {
      return base.copyWith(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FtColors.dangerSoft, FtColors.bg],
        ),
      );
    }
    return base.copyWith(color: FtColors.bg);
  }

  String get _timeLabel {
    final parts = <String>[];
    if (widget.job.scheduledTime != null) parts.add(widget.job.scheduledTime!);
    if (widget.job.estimatedDuration != null) parts.add(widget.job.estimatedDuration!);
    return parts.join(' · ');
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_timeLabel.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              _timeLabel,
              style: FtText.mono(size: 10, weight: FontWeight.w600, color: FtColors.fg2),
            ),
          ),
        Text(
          widget.job.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: FtText.inter(
            size: 12,
            weight: FontWeight.w600,
            color: FtColors.fg1,
          ).copyWith(
            height: 1.3,
            decoration: _isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        if (widget.job.siteName.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              widget.job.siteName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FtText.inter(size: 11, weight: FontWeight.w500, color: FtColors.fg2),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = Focus(
      onFocusChange: (hasFocus) => setState(() => _focused = hasFocus),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onTap?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: MouseRegion(
          cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Container(
            decoration: _focused
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: FtColors.accent, width: 2),
                  )
                : null,
            child: AnimatedContainer(
              duration: FtMotion.fast,
              transform: _hovered
                  ? (Matrix4.identity()..translateByDouble(0.0, -1.0, 0.0, 0.0))
                  : Matrix4.identity(),
              decoration: _decoration,
              padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
              child: Opacity(
                opacity: _isCompleted ? 0.7 : 1.0,
                child: Stack(
                  children: [
                    _buildContent(),
                    if (_isInProgress && _pulseController != null)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: FadeTransition(
                          opacity: Tween<double>(begin: 0.5, end: 1.0).animate(_pulseController!),
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: FtColors.accent,
                              shape: BoxShape.circle,
                              boxShadow: const [
                                BoxShadow(color: Color(0x40FFB020), blurRadius: 3, spreadRadius: 1),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return Draggable<DispatchedJob>(
      data: widget.job,
      feedback: IgnorePointer(
        child: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: 200,
            child: Opacity(
              opacity: 0.85,
              child: Container(
                decoration: _feedbackDecoration,
                padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
                child: _buildContent(),
              ),
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: child),
      child: child,
    );
  }
}
