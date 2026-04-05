import 'package:flutter/material.dart';
import '../../../models/dispatched_job.dart';
import '../../../utils/theme.dart';

/// Horizontal scrolling strip of unscheduled job cards at the bottom of the schedule.
class UnscheduledStrip extends StatelessWidget {
  final List<DispatchedJob> jobs;
  final bool isDark;
  final String? selectedJobId;
  final Color Function(DispatchedJob job) jobColorFn;
  final ValueChanged<String> onJobTap;

  const UnscheduledStrip({
    super.key,
    required this.jobs,
    required this.isDark,
    required this.selectedJobId,
    required this.jobColorFn,
    required this.onJobTap,
  });

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxHeight: 120),
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
            child: Text(
              'Unscheduled (${jobs.length})',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              itemCount: jobs.length,
              itemBuilder: (context, index) {
                final job = jobs[index];
                final color = jobColorFn(job);
                final isSelected = selectedJobId == job.id;

                final card = GestureDetector(
                  onTap: () => onJobTap(job.id),
                  child: Container(
                    width: 160,
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: isSelected ? 0.3 : 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? Border.all(color: color, width: 2)
                          : Border.all(color: color.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          job.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
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
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.mediumGrey,
                            ),
                          ),
                      ],
                    ),
                  ),
                );

                // Wrap in Draggable for drag-to-schedule
                return Draggable<DispatchedJob>(
                  data: job,
                  feedback: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(width: 160, child: Opacity(opacity: 0.85, child: card)),
                  ),
                  childWhenDragging: Opacity(opacity: 0.3, child: card),
                  child: card,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
