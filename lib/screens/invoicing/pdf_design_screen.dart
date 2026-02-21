import 'package:flutter/material.dart';
import '../../utils/adaptive_widgets.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../settings/pdf_header_designer_screen.dart';
import '../settings/pdf_footer_designer_screen.dart';
import '../settings/pdf_colour_scheme_screen.dart';
import '../../widgets/adaptive_app_bar.dart';

class PdfDesignScreen extends StatelessWidget {
  const PdfDesignScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite;
    final shadow = isDark ? AppTheme.darkCardShadow : AppTheme.cardShadow;

    return Scaffold(
      appBar: AdaptiveNavigationBar(title: 'PDF Design'),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? Colors.blue.shade900.withValues(alpha: 0.3) : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              border: Border.all(
                color: isDark ? Colors.blue.shade700 : Colors.blue.shade200,
              ),
            ),
            child: Row(
              children: [
                Icon(AppIcons.infoCircle, color: Colors.blue.shade600, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'These settings apply to both invoice and jobsheet PDFs.',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: isDark ? Colors.blue.shade200 : Colors.blue.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Header Designer tile
          _buildTile(
            context,
            icon: AppIcons.edit,
            title: 'Header Designer',
            subtitle: 'Customise your PDF header and logo',
            cardColor: cardColor,
            shadow: shadow,
            onTap: () => Navigator.push(
              context,
              adaptivePageRoute(builder: (_) => const PdfHeaderDesignerScreen()),
            ),
          ),
          const SizedBox(height: 12),

          // Footer Designer tile
          _buildTile(
            context,
            icon: AppIcons.edit,
            title: 'Footer Designer',
            subtitle: 'Customise your PDF footer content',
            cardColor: cardColor,
            shadow: shadow,
            onTap: () => Navigator.push(
              context,
              adaptivePageRoute(builder: (_) => const PdfFooterDesignerScreen()),
            ),
          ),
          const SizedBox(height: 12),

          // Colour Scheme tile
          _buildTile(
            context,
            icon: AppIcons.colorSwatch,
            title: 'Colour Scheme',
            subtitle: 'Choose your PDF colour theme',
            cardColor: cardColor,
            shadow: shadow,
            onTap: () => Navigator.push(
              context,
              adaptivePageRoute(builder: (_) => const PdfColourSchemeScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color cardColor,
    required List<BoxShadow> shadow,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: shadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  AppIcons.arrowRight,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
