import 'package:flutter/material.dart';
import '../../models/pdf_header_config.dart' show PdfDocumentType;
import '../../services/pdf_branding_editor_adapter.dart';
import '../../utils/adaptive_widgets.dart';
import '../../utils/icon_map.dart';
import '../../utils/theme.dart';
import '../../widgets/adaptive_app_bar.dart';
import 'pdf_branding_editor_screen.dart';

/// Hub screen for PDF branding customisation.
///
/// Shows Jobsheet and Invoice sections with "Edit Branding" cards.
/// When [docType] is provided, shows only that type's section.
/// Replaces the old [PdfDesignScreen] with navigation to the new
/// unified [PdfBrandingEditorScreen].
class PdfBrandingHubScreen extends StatelessWidget {
  /// When null, shows both Jobsheet and Invoice sections (used from Settings).
  /// When provided, shows only that document type's section.
  final PdfDocumentType? docType;

  /// Adapter factory. Defaults to personal branding.
  final PdfBrandingEditorAdapter Function()? adapterFactory;

  const PdfBrandingHubScreen({
    super.key,
    this.docType,
    this.adapterFactory,
  });

  PdfBrandingEditorAdapter _createAdapter() =>
      adapterFactory?.call() ?? const PersonalBrandingAdapter();

  String get _title {
    if (docType == null) return 'PDF Branding';
    return docType == PdfDocumentType.jobsheet
        ? 'Jobsheet PDF Branding'
        : 'Invoice PDF Branding';
  }

  void _openEditor(BuildContext context, PdfDocumentType type) {
    Navigator.push(
      context,
      adaptivePageRoute(
        builder: (_) => PdfBrandingEditorScreen(
          adapter: _createAdapter(),
          docType: type,
        ),
      ),
    );
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
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Jobsheet section
          if (docType == null || docType == PdfDocumentType.jobsheet) ...[
            _buildSectionTitle('Jobsheet PDF', isDark),
            const SizedBox(height: 8),
            Text(
              'Header, footer, colours, fonts, and logo for jobsheet PDFs. '
              'Compliance reports inherit this branding.',
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            _buildBrandingCard(
              context,
              isDark,
              'Edit Jobsheet Branding',
              AppIcons.brush,
              () => _openEditor(context, PdfDocumentType.jobsheet),
            ),
          ],

          if (docType == null) const SizedBox(height: 32),

          // Invoice section
          if (docType == null || docType == PdfDocumentType.invoice) ...[
            _buildSectionTitle('Invoice PDF', isDark),
            const SizedBox(height: 8),
            Text(
              'Header, footer, colours, fonts, and logo for invoice PDFs.',
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            _buildBrandingCard(
              context,
              isDark,
              'Edit Invoice Branding',
              AppIcons.brush,
              () => _openEditor(context, PdfDocumentType.invoice),
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

  Widget _buildBrandingCard(
    BuildContext context,
    bool isDark,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: isDark ? null : AppTheme.cardShadow,
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue,
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text(
          'Header, footer, colours, fonts, logo',
        ),
        trailing: Icon(AppIcons.arrowRight),
        onTap: onTap,
      ),
    );
  }
}
