import 'package:flutter/material.dart';
import '../../../models/dispatched_job.dart';
import '../../../utils/theme.dart';

Color jobStatusColor(DispatchedJobStatus status) {
  switch (status) {
    case DispatchedJobStatus.created:
      return Colors.orange;
    case DispatchedJobStatus.assigned:
      return Colors.blue;
    case DispatchedJobStatus.accepted:
      return Colors.teal;
    case DispatchedJobStatus.enRoute:
      return Colors.indigo;
    case DispatchedJobStatus.onSite:
      return Colors.purple;
    case DispatchedJobStatus.completed:
      return AppTheme.successGreen;
    case DispatchedJobStatus.declined:
      return Colors.red;
  }
}

String jobStatusLabel(DispatchedJobStatus status) {
  switch (status) {
    case DispatchedJobStatus.created:
      return 'Unassigned';
    case DispatchedJobStatus.assigned:
      return 'Assigned';
    case DispatchedJobStatus.accepted:
      return 'Accepted';
    case DispatchedJobStatus.enRoute:
      return 'En Route';
    case DispatchedJobStatus.onSite:
      return 'On Site';
    case DispatchedJobStatus.completed:
      return 'Completed';
    case DispatchedJobStatus.declined:
      return 'Declined';
  }
}

String jobStatusToString(DispatchedJobStatus status) {
  switch (status) {
    case DispatchedJobStatus.created:
      return 'created';
    case DispatchedJobStatus.assigned:
      return 'assigned';
    case DispatchedJobStatus.accepted:
      return 'accepted';
    case DispatchedJobStatus.enRoute:
      return 'en_route';
    case DispatchedJobStatus.onSite:
      return 'on_site';
    case DispatchedJobStatus.completed:
      return 'completed';
    case DispatchedJobStatus.declined:
      return 'declined';
  }
}

Widget jobStatusBadge(DispatchedJobStatus status) {
  final color = jobStatusColor(status);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      jobStatusLabel(status),
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
    ),
  );
}

Widget jobPriorityBadge(JobPriority priority) {
  if (priority == JobPriority.normal) {
    return Text(
      'Normal',
      style: TextStyle(fontSize: 12, color: AppTheme.mediumGrey),
    );
  }
  final isEmergency = priority == JobPriority.emergency;
  final color = isEmergency ? Colors.red : Colors.orange;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      isEmergency ? 'EMERGENCY' : 'URGENT',
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
    ),
  );
}

String jobPriorityLabel(JobPriority priority) {
  switch (priority) {
    case JobPriority.normal:
      return 'Normal';
    case JobPriority.urgent:
      return 'Urgent';
    case JobPriority.emergency:
      return 'Emergency';
  }
}

bool isToday(DateTime date) {
  final now = DateTime.now();
  return date.year == now.year &&
      date.month == now.month &&
      date.day == now.day;
}
