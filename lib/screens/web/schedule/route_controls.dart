import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/company_member.dart';
import '../../../utils/theme.dart';
import '../../../utils/icon_map.dart';

/// Toolbar overlay for the map to select an engineer and date for route view.
class RouteControls extends StatelessWidget {
  final List<CompanyMember> members;
  final String? selectedEngineerId;
  final DateTime selectedDate;
  final bool isDark;
  final ValueChanged<String?> onEngineerChanged;
  final ValueChanged<DateTime> onDateChanged;

  const RouteControls({
    super.key,
    required this.members,
    required this.selectedEngineerId,
    required this.selectedDate,
    required this.isDark,
    required this.onEngineerChanged,
    required this.onDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final engineers = members
        .where((m) => m.role == CompanyRole.engineer || m.role == CompanyRole.admin)
        .toList();
    final fmt = DateFormat('EEE, MMM d');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.routing, size: 16,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey),
          const SizedBox(width: 8),
          // Engineer dropdown
          DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: selectedEngineerId,
              hint: Text(
                'Select engineer',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
                ),
              ),
              isDense: true,
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All jobs',
                      style: TextStyle(fontSize: 12,
                        color: isDark ? Colors.white : AppTheme.darkGrey)),
                ),
                ...engineers.map((m) => DropdownMenuItem<String?>(
                      value: m.uid,
                      child: Text(m.displayName,
                          style: TextStyle(fontSize: 12,
                            color: isDark ? Colors.white : AppTheme.darkGrey)),
                    )),
              ],
              onChanged: onEngineerChanged,
            ),
          ),
          const SizedBox(width: 12),
          // Date navigation
          IconButton(
            onPressed: () => onDateChanged(
                selectedDate.subtract(const Duration(days: 1))),
            icon: Icon(AppIcons.arrowLeft, size: 14),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
            tooltip: 'Previous day',
          ),
          Text(
            fmt.format(selectedDate),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.darkGrey,
            ),
          ),
          IconButton(
            onPressed: () =>
                onDateChanged(selectedDate.add(const Duration(days: 1))),
            icon: Icon(AppIcons.arrowRight, size: 14),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
            tooltip: 'Next day',
          ),
        ],
      ),
    );
  }
}
