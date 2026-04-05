import 'package:flutter/material.dart';
import '../../../models/dispatched_job.dart';
import '../../../utils/theme.dart';
import 'schedule_helpers.dart';

/// A compact job card used in week view, month selected-day list, and day view.
class ScheduleJobBlock extends StatelessWidget {
  final DispatchedJob job;
  final bool isDark;
  final bool isSelected;
  final Color color;
  final VoidCallback? onTap;

  const ScheduleJobBlock({
    super.key,
    required this.job,
    required this.isDark,
    required this.isSelected,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isSelected ? 0.3 : 0.15),
          borderRadius: BorderRadius.circular(6),
          border: isSelected
              ? Border.all(color: color, width: 2)
              : Border.all(color: color.withValues(alpha: 0.3)),
        ),
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
            if (job.assignedToName != null)
              Text(
                job.assignedToName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
                ),
              ),
            if (job.scheduledTime != null)
              Text(
                job.scheduledTime!,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            // Status label
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: jobStatusColor(job.status).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                jobStatusLabel(job.status),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: jobStatusColor(job.status),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
