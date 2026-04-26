import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/company_member.dart';
import '../../../theme/web_theme.dart';

Color roleColor(CompanyRole role) {
  switch (role) {
    case CompanyRole.admin:
      return FtColors.warning;
    case CompanyRole.dispatcher:
      return FtColors.info;
    case CompanyRole.engineer:
      return FtColors.success;
  }
}

Color roleSoftColor(CompanyRole role) {
  switch (role) {
    case CompanyRole.admin:
      return FtColors.warningSoft;
    case CompanyRole.dispatcher:
      return FtColors.infoSoft;
    case CompanyRole.engineer:
      return FtColors.successSoft;
  }
}

String roleLabel(CompanyRole role) {
  switch (role) {
    case CompanyRole.admin:
      return 'Admin';
    case CompanyRole.dispatcher:
      return 'Dispatcher';
    case CompanyRole.engineer:
      return 'Engineer';
  }
}

Widget roleBadge(CompanyRole role) {
  final color = roleColor(role);
  final softColor = roleSoftColor(role);
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
          roleLabel(role),
          style: FtText.inter(size: 12, weight: FontWeight.w600, color: color),
        ),
      ],
    ),
  );
}

Widget activeBadge(bool isActive) {
  final color = isActive ? FtColors.success : FtColors.hint;
  final softColor = isActive ? FtColors.successSoft : FtColors.bgSunken;
  final label = isActive ? 'Active' : 'Inactive';

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

String generateTeamCsv(
    List<CompanyMember> members, Map<String, bool> columnVisibility) {
  final buffer = StringBuffer();
  final dateTimeFmt = DateFormat('yyyy-MM-dd HH:mm');

  final columnDefs = <String, String>{
    'name': 'Name',
    'email': 'Email',
    'role': 'Role',
    'joinedAt': 'Joined',
    'status': 'Status',
  };

  final visibleKeys =
      columnDefs.keys.where((k) => columnVisibility[k] == true).toList();

  buffer.writeln(visibleKeys.map((k) => columnDefs[k] ?? k).map(_escapeCsv).join(','));

  for (final m in members) {
    final values = visibleKeys.map((key) {
      switch (key) {
        case 'name':
          return m.displayName;
        case 'email':
          return m.email;
        case 'role':
          return roleLabel(m.role);
        case 'joinedAt':
          return dateTimeFmt.format(m.joinedAt);
        case 'status':
          return m.isActive ? 'Active' : 'Inactive';
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
