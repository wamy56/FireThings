import 'package:flutter/material.dart';
import '../../models/pdf_header_config.dart' show PdfDocumentType;
import '../../utils/adaptive_widgets.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../settings/pdf_header_designer_screen.dart';
import '../settings/pdf_footer_designer_screen.dart';
import '../settings/pdf_colour_scheme_screen.dart';
import '../settings/pdf_section_style_screen.dart';
import '../settings/pdf_typography_screen.dart';
import '../../widgets/adaptive_app_bar.dart';

class PdfDesignScreen extends StatelessWidget {
  /// When null, shows both Jobsheet and Invoice sections (used from Settings).
  /// When provided, shows only that document type's section (used from hubs).
  final PdfDocumentType? docType;

  const PdfDesignScreen({super.key, this.docType});

  String get _title {
    if (docType == null) return 'PDF Branding';
    return docType == PdfDocumentType.jobsheet
        ? 'Jobsheet PDF Design'
        : 'Invoice PDF Design';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AdaptiveNavigationBar(title: _title),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        children: [
          if (docType == null) ...[
            Text(
              'Customise the PDF branding used for your jobsheets and invoices.',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Jobsheet section
          if (docType == null || docType == PdfDocumentType.jobsheet) ...[
            _buildSectionTitle('Jobsheet PDF', isDark),
            const SizedBox(height: 12),
            _buildConfigCard(
              context,
              isDark,
              'Header',
              AppIcons.edit,
              'Customise your jobsheet PDF header and logo',
              () => Navigator.push(
                context,
                adaptivePageRoute(
                  builder: (_) => PdfHeaderDesignerScreen(docType: PdfDocumentType.jobsheet),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildConfigCard(
              context,
              isDark,
              'Footer',
              AppIcons.edit,
              'Customise your jobsheet PDF footer content',
              () => Navigator.push(
                context,
                adaptivePageRoute(
                  builder: (_) => PdfFooterDesignerScreen(docType: PdfDocumentType.jobsheet),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildConfigCard(
              context,
              isDark,
              'Colour Scheme',
              AppIcons.colorSwatch,
              'Choose your jobsheet PDF colour theme',
              () => Navigator.push(
                context,
                adaptivePageRoute(
                  builder: (_) => PdfColourSchemeScreen(docType: PdfDocumentType.jobsheet),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildConfigCard(
              context,
              isDark,
              'Section Style',
              AppIcons.layout,
              'Customise section cards and spacing',
              () => Navigator.push(
                context,
                adaptivePageRoute(
                  builder: (_) => PdfSectionStyleScreen(docType: PdfDocumentType.jobsheet),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildConfigCard(
              context,
              isDark,
              'Typography',
              AppIcons.text,
              'Adjust font sizes throughout the document',
              () => Navigator.push(
                context,
                adaptivePageRoute(
                  builder: (_) => PdfTypographyScreen(docType: PdfDocumentType.jobsheet),
                ),
              ),
            ),
          ],

          if (docType == null) const SizedBox(height: 32),

          // Invoice section
          if (docType == null || docType == PdfDocumentType.invoice) ...[
            _buildSectionTitle('Invoice PDF', isDark),
            const SizedBox(height: 12),
            _buildConfigCard(
              context,
              isDark,
              'Header',
              AppIcons.edit,
              'Customise your invoice PDF header and logo',
              () => Navigator.push(
                context,
                adaptivePageRoute(
                  builder: (_) => PdfHeaderDesignerScreen(docType: PdfDocumentType.invoice),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildConfigCard(
              context,
              isDark,
              'Footer',
              AppIcons.edit,
              'Customise your invoice PDF footer content',
              () => Navigator.push(
                context,
                adaptivePageRoute(
                  builder: (_) => PdfFooterDesignerScreen(docType: PdfDocumentType.invoice),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildConfigCard(
              context,
              isDark,
              'Colour Scheme',
              AppIcons.colorSwatch,
              'Choose your invoice PDF colour theme',
              () => Navigator.push(
                context,
                adaptivePageRoute(
                  builder: (_) => PdfColourSchemeScreen(docType: PdfDocumentType.invoice),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildConfigCard(
              context,
              isDark,
              'Section Style',
              AppIcons.layout,
              'Customise section cards and spacing',
              () => Navigator.push(
                context,
                adaptivePageRoute(
                  builder: (_) => PdfSectionStyleScreen(docType: PdfDocumentType.invoice),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildConfigCard(
              context,
              isDark,
              'Typography',
              AppIcons.text,
              'Adjust font sizes throughout the document',
              () => Navigator.push(
                context,
                adaptivePageRoute(
                  builder: (_) => PdfTypographyScreen(docType: PdfDocumentType.invoice),
                ),
              ),
            ),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
      ),
    );
  }

  Widget _buildConfigCard(
    BuildContext context,
    bool isDark,
    String title,
    IconData icon,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: isDark ? null : AppTheme.cardShadow,
      ),
      child: ListTile(
        leading: Icon(icon, color: isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: Icon(AppIcons.arrowRight),
        onTap: onTap,
      ),
    );
  }
}
