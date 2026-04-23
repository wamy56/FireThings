import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../theme/web_theme.dart';

class ScheduleDayHeader extends StatelessWidget {
  final DateTime date;
  final bool isToday;
  final int jobCount;

  const ScheduleDayHeader({
    super.key,
    required this.date,
    required this.isToday,
    required this.jobCount,
  });

  String get _dayLabel {
    if (isToday) return 'TODAY';
    return DateFormat('E').format(date).toUpperCase().substring(0, 3);
  }

  String get _monthWeekday {
    final month = DateFormat('MMM').format(date);
    if (isToday) {
      final weekday = DateFormat('E').format(date);
      return '$month · $weekday';
    }
    return month;
  }

  String get _statText {
    if (jobCount == 0) return '0 jobs';
    final label = jobCount == 1 ? 'job' : 'jobs';
    if (jobCount >= 8) return '$jobCount $label · full';
    return '$jobCount $label';
  }

  Color get _statColor {
    if (jobCount == 0) return FtColors.hint;
    if (jobCount >= 8) return FtColors.danger;
    if (jobCount >= 6) return FtColors.warning;
    return FtColors.fg2;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        border: const Border(
          right: BorderSide(color: FtColors.border, width: 1),
        ),
        gradient: isToday
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [FtColors.accentSoft, Colors.transparent],
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _dayLabel,
            style: FtText.inter(
              size: 11,
              weight: FontWeight.w700,
              letterSpacing: 0.4,
              color: isToday ? FtColors.accentHover : FtColors.fg2,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${date.day}',
                style: FtText.outfit(
                  size: 22,
                  weight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: isToday ? FtColors.accentHover : FtColors.primary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _monthWeekday,
                style: FtText.inter(size: 12, weight: FontWeight.w600, color: FtColors.fg2),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _statText,
            style: FtText.inter(size: 11, weight: FontWeight.w600, color: _statColor),
          ),
        ],
      ),
    );
  }
}
