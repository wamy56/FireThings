import 'package:flutter/material.dart';
import '../../../models/dispatched_job.dart';
import '../../../models/company_member.dart';
import '../dashboard/job_helpers.dart';

export '../dashboard/job_helpers.dart' show jobStatusColor, jobStatusLabel;

/// Engineer colour palette for calendar blocks.
const engineerColors = [
  Colors.blue,
  Colors.teal,
  Colors.orange,
  Colors.purple,
  Colors.indigo,
  Colors.pink,
  Colors.cyan,
  Colors.amber,
  Colors.green,
  Colors.deepOrange,
];

/// Get a colour for an engineer based on their index in the members list.
Color engineerColor(String? engineerId, List<CompanyMember> members) {
  if (engineerId == null) return Colors.grey;
  final idx = members.indexWhere((m) => m.uid == engineerId);
  if (idx < 0) return Colors.grey;
  return engineerColors[idx % engineerColors.length];
}

/// Get job colour based on the current colour mode.
Color jobColor(DispatchedJob job, bool colorByEngineer, List<CompanyMember> members) {
  return colorByEngineer
      ? engineerColor(job.assignedTo, members)
      : jobStatusColor(job.status);
}

/// Schedule view mode.
enum ScheduleViewMode { week, month, day }
