import 'package:flutter/material.dart';
import '../../../models/dispatched_job.dart';
import '../../../theme/web_theme.dart';

Color jobStatusColor(DispatchedJobStatus status) {
  switch (status) {
    case DispatchedJobStatus.created:
      return FtColors.danger;
    case DispatchedJobStatus.assigned:
      return FtColors.info;
    case DispatchedJobStatus.accepted:
      return const Color(0xFF1D4ED8);
    case DispatchedJobStatus.enRoute:
      return FtColors.warning;
    case DispatchedJobStatus.onSite:
      return FtColors.accent;
    case DispatchedJobStatus.completed:
      return FtColors.success;
    case DispatchedJobStatus.declined:
      return FtColors.danger;
  }
}

Color jobStatusSoftColor(DispatchedJobStatus status) {
  switch (status) {
    case DispatchedJobStatus.created:
      return FtColors.dangerSoft;
    case DispatchedJobStatus.assigned:
      return FtColors.infoSoft;
    case DispatchedJobStatus.accepted:
      return const Color(0xFFDBEAFE);
    case DispatchedJobStatus.enRoute:
      return FtColors.warningSoft;
    case DispatchedJobStatus.onSite:
      return FtColors.accentSoft;
    case DispatchedJobStatus.completed:
      return FtColors.successSoft;
    case DispatchedJobStatus.declined:
      return FtColors.dangerSoft;
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
  final softColor = jobStatusSoftColor(status);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
    decoration: BoxDecoration(
      color: softColor,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          jobStatusLabel(status),
          style: FtText.inter(size: 12, weight: FontWeight.w600, color: color),
        ),
      ],
    ),
  );
}

Widget jobPriorityBadge(JobPriority priority) {
  if (priority == JobPriority.normal) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: FtColors.hint,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: FtColors.bgSunken, spreadRadius: 3, blurRadius: 0)],
          ),
        ),
        const SizedBox(width: 5),
        Text(
          'NORMAL',
          style: FtText.inter(size: 11, weight: FontWeight.w700, color: FtColors.hint),
        ),
      ],
    );
  }
  final isEmergency = priority == JobPriority.emergency;
  final color = isEmergency ? FtColors.danger : FtColors.warning;
  final softColor = isEmergency ? FtColors.dangerSoft : FtColors.warningSoft;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: softColor, spreadRadius: 3, blurRadius: 0)],
        ),
      ),
      const SizedBox(width: 5),
      Text(
        isEmergency ? 'EMERGENCY' : 'URGENT',
        style: FtText.inter(size: 11, weight: FontWeight.w700, color: color),
      ),
    ],
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
