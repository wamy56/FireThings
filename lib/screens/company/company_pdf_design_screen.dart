import 'package:flutter/material.dart';
import '../../models/pdf_header_config.dart' show PdfDocumentType;
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/adaptive_app_bar.dart';
import '../settings/unified_pdf_editor_screen.dart';

/// Company PDF branding screen - navigates to unified PDF editor in company mode.
class CompanyPdfDesignScreen extends StatelessWidget {
  final String companyId;

  const CompanyPdfDesignScreen({super.key, required this.companyId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AdaptiveNavigationBar(title: 'Company PDF Branding'),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 750),
          child: ListView(
            padding: const EdgeInsets.all(AppTheme.screenPadding),
            children: [
              Text(
                'Configure the PDF branding used for jobsheets, invoices, and quotes created from dispatched jobs.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // Jobsheet section
              _buildSectionTitle('Jobsheet PDF', isDark),
              const SizedBox(height: 12),
              _buildConfigCard(
                context,
                isDark,
                'Design',
                AppIcons.edit,
                'Customise header, footer, colours, sections, and typography',
                () => Navigator.push(
                  context,
                  adaptivePageRoute(
                    builder: (_) => UnifiedPdfEditorScreen(
                      docType: PdfDocumentType.jobsheet,
                      isCompany: true,
                      companyId: companyId,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Invoice section
              _buildSectionTitle('Invoice PDF', isDark),
              const SizedBox(height: 12),
              _buildConfigCard(
                context,
                isDark,
                'Design',
                AppIcons.edit,
                'Customise header, footer, colours, sections, and typography',
                () => Navigator.push(
                  context,
                  adaptivePageRoute(
                    builder: (_) => UnifiedPdfEditorScreen(
                      docType: PdfDocumentType.invoice,
                      isCompany: true,
                      companyId: companyId,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Quote section
              _buildSectionTitle('Quote PDF', isDark),
              const SizedBox(height: 12),
              _buildConfigCard(
                context,
                isDark,
                'Design',
                AppIcons.edit,
                'Customise header, footer, colours, sections, and typography',
                () => Navigator.push(
                  context,
                  adaptivePageRoute(
                    builder: (_) => UnifiedPdfEditorScreen(
                      docType: PdfDocumentType.quote,
                      isCompany: true,
                      companyId: companyId,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
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
