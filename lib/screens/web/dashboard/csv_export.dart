import 'package:intl/intl.dart';
import '../../../models/dispatched_job.dart';
import 'job_helpers.dart';

String generateJobsCsv(List<DispatchedJob> jobs, Map<String, bool> columnVisibility) {
  final buffer = StringBuffer();

  // All possible columns
  final columnDefs = <String, String>{
    'title': 'Title',
    'jobNumber': 'Job Number',
    'jobType': 'Job Type',
    'site': 'Site Name',
    'engineer': 'Engineer',
    'date': 'Scheduled Date',
    'priority': 'Priority',
    'status': 'Status',
    'contactName': 'Contact Name',
  };

  // Extra columns always included in export for completeness
  final extraColumns = <String, String>{
    'siteAddress': 'Site Address',
    'contactPhone': 'Contact Phone',
    'contactEmail': 'Contact Email',
    'createdBy': 'Created By',
    'createdAt': 'Created At',
  };

  // Build visible + extra headers
  final visibleKeys = columnDefs.keys.where((k) => columnVisibility[k] == true).toList();
  final allKeys = [...visibleKeys, ...extraColumns.keys];
  final allHeaders = allKeys.map((k) => columnDefs[k] ?? extraColumns[k] ?? k).toList();

  buffer.writeln(allHeaders.map(_escapeCsv).join(','));

  final dateFmt = DateFormat('yyyy-MM-dd');
  final dateTimeFmt = DateFormat('yyyy-MM-dd HH:mm');

  for (final job in jobs) {
    final values = allKeys.map((key) {
      switch (key) {
        case 'title':
          return job.title;
        case 'jobNumber':
          return job.jobNumber ?? '';
        case 'jobType':
          return job.jobType ?? '';
        case 'site':
          return job.siteName;
        case 'siteAddress':
          return job.siteAddress;
        case 'engineer':
          return job.assignedToName ?? '';
        case 'date':
          return job.scheduledDate != null ? dateFmt.format(job.scheduledDate!) : '';
        case 'priority':
          return jobPriorityLabel(job.priority);
        case 'status':
          return jobStatusLabel(job.status);
        case 'contactName':
          return job.contactName ?? '';
        case 'contactPhone':
          return job.contactPhone ?? '';
        case 'contactEmail':
          return job.contactEmail ?? '';
        case 'createdBy':
          return job.createdByName;
        case 'createdAt':
          return dateTimeFmt.format(job.createdAt);
        default:
          return '';
      }
    }).toList();

    buffer.writeln(values.map(_escapeCsv).join(','));
  }

  return buffer.toString();
}

String _escapeCsv(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}
