import 'package:flutter/material.dart';

import '../../../../models/pdf_branding.dart';
import '../../../../utils/theme.dart';

class CoverStylePicker extends StatelessWidget {
  final CoverStyle selected;
  final Color primaryColor;
  final Color accentColor;
  final ValueChanged<CoverStyle> onChanged;

  const CoverStylePicker({
    super.key,
    required this.selected,
    required this.primaryColor,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Cover style',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Row(
          children: CoverStyle.values.map((style) {
            final isSelected = style == selected;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: style != CoverStyle.bordered ? 8 : 0,
                ),
                child: _StyleCard(
                  style: style,
                  isSelected: isSelected,
                  primaryColor: primaryColor,
                  accentColor: accentColor,
                  onTap: () => onChanged(style),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _StyleCard extends StatelessWidget {
  final CoverStyle style;
  final bool isSelected;
  final Color primaryColor;
  final Color accentColor;
  final VoidCallback onTap;

  const _StyleCard({
    required this.style,
    required this.isSelected,
    required this.primaryColor,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppTheme.normalAnimation,
        curve: AppTheme.defaultCurve,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? accentColor
                : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06)),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isDark ? null : AppTheme.cardShadow,
        ),
        child: Column(
          children: [
            _buildMiniPreview(),
            const SizedBox(height: 8),
            Text(
              style.name[0].toUpperCase() + style.name.substring(1),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? (isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.textPrimary)
                        : (isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textSecondary),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniPreview() {
    final onDark = style == CoverStyle.bold;
    final bg = onDark ? primaryColor : Colors.white;
    final fg = onDark ? Colors.white : primaryColor;

    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: style == CoverStyle.bordered
            ? Border(
                top: BorderSide(color: primaryColor, width: 3),
                bottom: BorderSide(color: primaryColor, width: 3),
              )
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (style == CoverStyle.bold)
            Positioned(
              top: -20,
              right: -20,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.7],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 6),
                if (style == CoverStyle.minimal)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Container(
                      width: 20,
                      height: 2,
                      color: accentColor,
                    ),
                  ),
                Container(
                  width: 48,
                  height: 6,
                  decoration: BoxDecoration(
                    color: fg.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: fg.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
