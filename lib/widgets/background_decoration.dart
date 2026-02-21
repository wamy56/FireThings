import 'package:flutter/material.dart';
import '../utils/theme.dart';

/// Subtle, code-generated background decoration with semi-transparent
/// geometric shapes. Use as the first child in a [Stack] behind content.
class BackgroundDecoration extends StatelessWidget {
  const BackgroundDecoration({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final blue = isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue;
    final orange = isDark ? AppTheme.darkAccentOrange : AppTheme.accentOrange;
    // Lower opacity in dark mode so circles stay subtle against dark surfaces
    final baseOpacity = isDark ? 0.03 : 0.05;

    return IgnorePointer(
      child: SizedBox.expand(
        child: Stack(
          children: [
            // Large circle – top right
            Positioned(
              top: -60,
              right: -40,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: blue.withValues(alpha: baseOpacity),
                ),
              ),
            ),
            // Medium circle – bottom left
            Positioned(
              bottom: -50,
              left: -30,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: orange.withValues(alpha: baseOpacity * 0.9),
                ),
              ),
            ),
            // Small circle – centre-right accent
            Positioned(
              top: MediaQuery.of(context).size.height * 0.4,
              right: -60,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: blue.withValues(alpha: baseOpacity * 0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
