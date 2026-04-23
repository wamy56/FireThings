import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../theme/web_theme.dart';
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Icon(AppIcons.calendar, size: 16, color: FtColors.hint),
            const SizedBox(width: 8),
            _DateChip(
              label: 'Today',
              isSelected: activePreset == DateRangePreset.today,
              onTap: () => onPresetChanged(
                activePreset == DateRangePreset.today ? null : DateRangePreset.today,
              ),
            ),
            const SizedBox(width: 6),
            _DateChip(
              label: 'This Week',
              isSelected: activePreset == DateRangePreset.thisWeek,
              onTap: () => onPresetChanged(
                activePreset == DateRangePreset.thisWeek ? null : DateRangePreset.thisWeek,
              ),
            ),
            const SizedBox(width: 6),
            _DateChip(
              label: 'This Month',
              isSelected: activePreset == DateRangePreset.thisMonth,
              onTap: () => onPresetChanged(
                activePreset == DateRangePreset.thisMonth ? null : DateRangePreset.thisMonth,
              ),
            ),
            const SizedBox(width: 6),
            _DateChip(
              label: 'Overdue',
              isSelected: activePreset == DateRangePreset.overdue,
              onTap: () => onPresetChanged(
                activePreset == DateRangePreset.overdue ? null : DateRangePreset.overdue,
              ),
            ),
            const SizedBox(width: 6),
            _CustomDateChip(
              isSelected: activePreset == DateRangePreset.custom,
              customRange: customRange,
              onTap: () async {
                if (activePreset == DateRangePreset.custom) {
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
                          primary: FtColors.primary,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (range != null) onCustomRangeSelected(range);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DateChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DateChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_DateChip> createState() => _DateChipState();
}

class _DateChipState extends State<_DateChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: FtMotion.fast,
          curve: FtMotion.standardCurve,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? FtColors.primary
                : _hovered
                    ? FtColors.bg
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isSelected
                  ? FtColors.primary
                  : _hovered
                      ? FtColors.border
                      : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Text(
            widget.label,
            style: FtText.inter(
              size: 12,
              weight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
              color: widget.isSelected
                  ? Colors.white
                  : _hovered
                      ? FtColors.primary
                      : FtColors.fg2,
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomDateChip extends StatefulWidget {
  final bool isSelected;
  final DateTimeRange? customRange;
  final VoidCallback onTap;

  const _CustomDateChip({
    required this.isSelected,
    required this.customRange,
    required this.onTap,
  });

  @override
  State<_CustomDateChip> createState() => _CustomDateChipState();
}

class _CustomDateChipState extends State<_CustomDateChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    String label = 'Custom...';
    if (widget.isSelected && widget.customRange != null) {
      final fmt = DateFormat('dd MMM');
      label = '${fmt.format(widget.customRange!.start)} – ${fmt.format(widget.customRange!.end)}';
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: FtMotion.fast,
          curve: FtMotion.standardCurve,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? FtColors.primary
                : _hovered
                    ? FtColors.bg
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isSelected
                  ? FtColors.primary
                  : _hovered
                      ? FtColors.border
                      : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: FtText.inter(
              size: 12,
              weight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
              color: widget.isSelected
                  ? Colors.white
                  : _hovered
                      ? FtColors.primary
                      : FtColors.fg2,
            ),
          ),
        ),
      ),
    );
  }
}
