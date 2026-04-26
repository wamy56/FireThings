import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/company_site.dart';
import '../../../theme/web_theme.dart';

Widget bs5839Badge(bool isBs5839Site) {
  if (!isBs5839Site) return const SizedBox.shrink();

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
    decoration: BoxDecoration(
      color: FtColors.infoSoft,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(color: FtColors.info, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          'BS 5839',
          style: FtText.inter(size: 12, weight: FontWeight.w600, color: FtColors.info),
        ),
      ],
    ),
  );
}

Widget serviceDueBadge(DateTime? nextServiceDueDate) {
  if (nextServiceDueDate == null) return const SizedBox.shrink();

  final isOverdue = nextServiceDueDate.isBefore(DateTime.now());
  final color = isOverdue ? FtColors.danger : FtColors.success;
  final softColor = isOverdue ? FtColors.dangerSoft : FtColors.successSoft;
  final label = isOverdue ? 'Overdue' : 'Due ${DateFormat('dd MMM').format(nextServiceDueDate)}';

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
        Text(label, style: FtText.inter(size: 12, weight: FontWeight.w600, color: color)),
      ],
    ),
  );
}

String generateSitesCsv(
    List<CompanySite> sites, Map<String, bool> columnVisibility) {
  final buffer = StringBuffer();
  final dateTimeFmt = DateFormat('yyyy-MM-dd HH:mm');

  final columnDefs = <String, String>{
    'name': 'Name',
    'address': 'Address',
    'notes': 'Notes',
    'bs5839': 'BS 5839',
    'createdAt': 'Created',
  };

  final extraColumns = <String, String>{
    'latitude': 'Latitude',
    'longitude': 'Longitude',
    'nextServiceDueDate': 'Next Service Due',
  };

  final visibleKeys =
      columnDefs.keys.where((k) => columnVisibility[k] == true).toList();
  final allKeys = [...visibleKeys, ...extraColumns.keys];
  final allHeaders =
      allKeys.map((k) => columnDefs[k] ?? extraColumns[k] ?? k).toList();

  buffer.writeln(allHeaders.map(_escapeCsv).join(','));

  for (final s in sites) {
    final values = allKeys.map((key) {
      switch (key) {
        case 'name':
          return s.name;
        case 'address':
          return s.address;
        case 'notes':
          return s.notes ?? '';
        case 'bs5839':
          return s.isBs5839Site ? 'Yes' : 'No';
        case 'createdAt':
          return dateTimeFmt.format(s.createdAt);
        case 'latitude':
          return s.latitude?.toString() ?? '';
        case 'longitude':
          return s.longitude?.toString() ?? '';
        case 'nextServiceDueDate':
          return s.nextServiceDueDate != null
              ? dateTimeFmt.format(s.nextServiceDueDate!)
              : '';
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
