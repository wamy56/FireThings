import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../utils/theme.dart';
import '../../../utils/icon_map.dart';

enum DateRangePreset { today, thisWeek, thisMonth, overdue, custom }

class DateRangeFilterBar extends StatelessWidget {
  final DateRangePreset? activePreset;
  final DateTimeRange? customRange;
  final ValueChanged<DateRangePreset?> onPresetChanged;
  final ValueChanged<DateTimeRange> onCustomRangeSelected;

  const DateRangeFilterBar({
    super.key,
    required this.activePreset,
    required this.customRange,
    required this.onPresetChanged,
    required this.onCustomRangeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Icon(
              AppIcons.calendar,
              size: 16,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
            ),
            const SizedBox(width: 8),
            _chip(context, 'Today', DateRangePreset.today),
            const SizedBox(width: 8),
            _chip(context, 'This Week', DateRangePreset.thisWeek),
            const SizedBox(width: 8),
            _chip(context, 'This Month', DateRangePreset.thisMonth),
            const SizedBox(width: 8),
            _chip(context, 'Overdue', DateRangePreset.overdue),
            const SizedBox(width: 8),
            _customChip(context),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String label, DateRangePreset preset) {
    final isSelected = activePreset == preset;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        onPresetChanged(isSelected ? null : preset);
      },
      selectedColor: AppTheme.primaryBlue.withValues(alpha: 0.15),
      checkmarkColor: AppTheme.primaryBlue,
      labelStyle: TextStyle(
        fontSize: 12,
        color: isSelected ? AppTheme.primaryBlue : null,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _customChip(BuildContext context) {
    final isSelected = activePreset == DateRangePreset.custom;
    String label = 'Custom...';
    if (isSelected && customRange != null) {
      final fmt = DateFormat('dd MMM');
      label = '${fmt.format(customRange!.start)} – ${fmt.format(customRange!.end)}';
    }

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) async {
        if (isSelected) {
          onPresetChanged(null);
          return;
        }
        final range = await showDateRangePicker(
          context: context,
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          initialDateRange: customRange,
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppTheme.primaryBlue,
                ),
              ),
              child: child!,
            );
          },
        );
        if (range != null) {
          onCustomRangeSelected(range);
        }
      },
      selectedColor: AppTheme.primaryBlue.withValues(alpha: 0.15),
      checkmarkColor: AppTheme.primaryBlue,
      labelStyle: TextStyle(
        fontSize: 12,
        color: isSelected ? AppTheme.primaryBlue : null,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
