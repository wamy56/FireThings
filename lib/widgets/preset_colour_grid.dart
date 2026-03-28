import 'package:flutter/material.dart';
import '../models/pdf_colour_scheme.dart';
import '../utils/theme.dart';
import '../utils/icon_map.dart';

class PresetColourGrid extends StatelessWidget {
  const PresetColourGrid({
    super.key,
    required this.selectedPrimaryColorValue,
    required this.isDark,
    required this.onPresetSelected,
  });

  final int selectedPrimaryColorValue;
  final bool isDark;
  final ValueChanged<PdfColourScheme> onPresetSelected;

  @override
  Widget build(BuildContext context) {
    final presets = PdfColourScheme.presets;

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth < 600 ? 4 : 8;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 8,
          childAspectRatio: 0.85,
          children: presets.map((preset) {
            final color = Color(preset.scheme.primaryColorValue);
            final isSelected =
                selectedPrimaryColorValue == preset.scheme.primaryColorValue;

            return GestureDetector(
              onTap: () => onPresetSelected(preset.scheme),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(
                              color: isDark ? Colors.white : AppTheme.textPrimary,
                              width: 3,
                            )
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: isSelected
                        ? Icon(AppIcons.tickCircle, color: Colors.white, size: 22)
                        : null,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    preset.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
