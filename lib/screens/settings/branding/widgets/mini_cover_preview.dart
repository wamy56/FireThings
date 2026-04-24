import 'package:flutter/material.dart';

import '../../../../models/pdf_branding.dart';
import '../../../../utils/theme.dart';

class MiniCoverPreview extends StatelessWidget {
  final CoverStyle coverStyle;
  final Color primaryColor;
  final Color accentColor;
  final String? logoUrl;

  const MiniCoverPreview({
    super.key,
    required this.coverStyle,
    required this.primaryColor,
    required this.accentColor,
    this.logoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Preview',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite,
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            boxShadow: isDark ? null : AppTheme.cardShadow,
          ),
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: 210 / 180,
            child: _buildCover(),
          ),
        ),
      ],
    );
  }

  Widget _buildCover() {
    final onDark = coverStyle == CoverStyle.bold;
    final bg = onDark ? primaryColor : Colors.white;
    final fg = onDark ? Colors.white : primaryColor;

    final border = coverStyle == CoverStyle.bordered
        ? Border(
            top: BorderSide(color: primaryColor, width: 5),
            bottom: BorderSide(color: primaryColor, width: 5),
          )
        : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: bg, border: border),
      child: Stack(
        children: [
          if (coverStyle == CoverStyle.bold)
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.7],
                  ),
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'COMPLIANCE REPORT',
                style: TextStyle(
                  fontSize: 7,
                  fontWeight: FontWeight.w700,
                  color: onDark
                      ? Colors.white.withValues(alpha: 0.6)
                      : accentColor,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildLogoMark(),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Your Company',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: fg,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (coverStyle == CoverStyle.minimal)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(width: 28, height: 2.5, color: accentColor),
                ),
              Text(
                'Fire Alarm\nSystem Report',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: fg,
                  height: 1.1,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '123 Example Street',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: onDark
                      ? Colors.white.withValues(alpha: 0.7)
                      : primaryColor.withValues(alpha: 0.6),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: onDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : primaryColor.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    _buildMetaItem('Date', '24 Apr 2026', onDark),
                    const SizedBox(width: 24),
                    _buildMetaItem('Engineer', 'J. Smith', onDark),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogoMark() {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: accentColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Center(
        child: Text(
          'F',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: primaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildMetaItem(String label, String value, bool onDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 6,
            fontWeight: FontWeight.w700,
            color: onDark
                ? Colors.white.withValues(alpha: 0.5)
                : primaryColor.withValues(alpha: 0.45),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: onDark ? Colors.white : primaryColor,
          ),
        ),
      ],
    );
  }
}
