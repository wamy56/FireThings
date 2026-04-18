import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/pdf_header_config.dart';
import '../models/pdf_footer_config.dart';
import '../models/pdf_colour_scheme.dart';
import '../models/pdf_section_style_config.dart';
import '../models/pdf_typography_config.dart';
import '../utils/theme.dart';

/// A unified PDF preview widget that shows the combined effect of all PDF styling settings.
/// Used in the unified PDF editor to provide live preview as users change settings.
class UnifiedPdfPreview extends StatelessWidget {
  final PdfDocumentType docType;
  final PdfHeaderConfig headerConfig;
  final PdfFooterConfig footerConfig;
  final PdfColourScheme colourScheme;
  final PdfSectionStyleConfig sectionStyle;
  final PdfTypographyConfig typography;
  final Uint8List? logoBytes;

  /// Fallback values for header text line keys
  final Map<String, String> fallbackValues;

  const UnifiedPdfPreview({
    super.key,
    required this.docType,
    required this.headerConfig,
    required this.footerConfig,
    required this.colourScheme,
    required this.sectionStyle,
    required this.typography,
    this.logoBytes,
    this.fallbackValues = const {},
  });

  Color get _primaryColor => Color(colourScheme.primaryColorValue);
  Color get _lightTint => Color.lerp(_primaryColor, Colors.white, 0.9)!;
  Color get _mediumTint => Color.lerp(_primaryColor, Colors.white, 0.6)!;

  // Scale factor to fit preview in available space (roughly 40% of original)
  static const double _scale = 0.55;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(sectionStyle.innerPadding * _scale),
              child: docType == PdfDocumentType.invoice
                  ? _buildInvoiceContent()
                  : _buildJobsheetContent(),
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    switch (headerConfig.headerStyle) {
      case HeaderStyle.classic:
        return _buildClassicHeader();
      case HeaderStyle.minimal:
        return _buildMinimalHeader();
    }
  }

  Widget _buildClassicHeader() {

    final contentRow = Row(
      children: [
        if (headerConfig.logoZone == LogoZone.left && logoBytes != null)
          _buildLogo(),
        if (headerConfig.logoZone == LogoZone.left && logoBytes != null)
          SizedBox(width: 8 * _scale),
        Expanded(
            child: _buildHeaderZone(headerConfig.leftLines, _primaryColor)),
        if (headerConfig.centreLines.isNotEmpty) ...[
          SizedBox(width: 8 * _scale),
          Expanded(
              child:
                  _buildHeaderZone(headerConfig.centreLines, _primaryColor)),
        ],
        SizedBox(width: 8 * _scale),
        _buildDocTypeBadge(),
      ],
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: headerConfig.horizontalPadding * _scale,
        vertical: headerConfig.verticalPadding * _scale,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _primaryColor, width: 2),
        ),
      ),
      child: contentRow,
    );
  }

  Widget _buildMinimalHeader() {

    final contentRow = Row(
      children: [
        if (headerConfig.logoZone == LogoZone.left && logoBytes != null)
          _buildLogo(),
        if (headerConfig.logoZone == LogoZone.left && logoBytes != null)
          SizedBox(width: 8 * _scale),
        Expanded(
            child: _buildHeaderZone(headerConfig.leftLines, _primaryColor)),
        if (headerConfig.centreLines.isNotEmpty) ...[
          SizedBox(width: 8 * _scale),
          Expanded(
              child:
                  _buildHeaderZone(headerConfig.centreLines, _primaryColor)),
        ],
        SizedBox(width: 8 * _scale),
        _buildDocTypeBadge(),
      ],
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: headerConfig.horizontalPadding * _scale,
        vertical: (headerConfig.verticalPadding + 4) * _scale,
      ),
      child: contentRow,
    );
  }

  Widget _buildLogo() {
    final size = headerConfig.logoSize.pixels * _scale;
    return Container(
      width: size,
      height: size * 0.6,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(4),
      ),
      child: logoBytes != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.memory(
                logoBytes!,
                fit: BoxFit.contain,
              ),
            )
          : Center(
              child: Icon(
                Icons.image,
                size: size * 0.4,
                color: Colors.grey.shade400,
              ),
            ),
    );
  }

  Widget _buildHeaderZone(List<HeaderTextLine> lines, Color textColor) {
    if (lines.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: lines.map((line) {
        final text = line.value.isNotEmpty
            ? line.value
            : fallbackValues[line.key] ?? _defaultForKey(line.key);
        return Text(
          text,
          style: TextStyle(
            fontSize: line.fontSize * _scale,
            fontWeight: line.bold ? FontWeight.bold : FontWeight.normal,
            color: textColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      }).toList(),
    );
  }

  String _defaultForKey(String key) {
    switch (key) {
      case 'companyName':
        return 'YOUR COMPANY';
      case 'tagline':
        return 'Professional Services';
      case 'address':
        return '123 Example Street, City';
      case 'phone':
        return '01onal 123 456';
      case 'engineerName':
        return 'Engineer Name';
      case 'companyDetails':
        return 'Company details here';
      default:
        return 'Custom text';
    }
  }

  Widget _buildDocTypeBadge() {
    final label = docType == PdfDocumentType.invoice ? 'INVOICE' : 'JOBSHEET';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 8 * _scale,
        vertical: 4 * _scale,
      ),
      decoration: BoxDecoration(
        color: _primaryColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10 * _scale,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildJobsheetContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Job Information section
        _buildSectionCard(
          title: 'JOB INFORMATION',
          children: [
            _buildFieldRow('Date:', '14/03/2026', false),
            _buildFieldRow('Engineer:', 'John Smith', true),
            _buildFieldRow('Job No:', 'JS-001', false),
          ],
        ),
        SizedBox(height: sectionStyle.sectionSpacing * _scale),

        // Work Details section
        _buildSectionCard(
          title: 'WORK DETAILS',
          children: [
            _buildFieldRow('System Type:', 'Conventional', false),
            _buildFieldRow('Panels Tested:', 'Yes', true),
          ],
        ),
        SizedBox(height: sectionStyle.sectionSpacing * _scale),

        // Signatures
        _buildSignatureSection(),
      ],
    );
  }

  Widget _buildInvoiceContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Invoice info
        _buildSectionCard(
          title: 'INVOICE DETAILS',
          children: [
            _buildFieldRow('Invoice No:', 'INV-001', false),
            _buildFieldRow('Date:', '01/01/2025', true),
            _buildFieldRow('Due Date:', '31/01/2025', false),
          ],
        ),
        SizedBox(height: sectionStyle.sectionSpacing * _scale),

        // Line items table
        _buildTableSection(),
        SizedBox(height: sectionStyle.sectionSpacing * _scale),

        // Totals
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'TOTAL: \u00A3750.00',
            style: TextStyle(
              fontSize: typography.sectionHeaderSize * _scale,
              fontWeight: FontWeight.bold,
              color: _primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: _buildCardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(title),
          Padding(
            padding: EdgeInsets.all(sectionStyle.innerPadding * _scale),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _buildCardDecoration() {
    final radius = BorderRadius.circular(sectionStyle.cornerRadius.pixels * _scale);

    switch (sectionStyle.cardStyle) {
      case SectionCardStyle.bordered:
        return BoxDecoration(
          color: Colors.white,
          borderRadius: radius,
          border: Border.all(color: Colors.grey.shade300),
        );
      case SectionCardStyle.shadowed:
        return BoxDecoration(
          color: Colors.white,
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        );
      case SectionCardStyle.elevated:
        return BoxDecoration(
          color: Colors.white,
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        );
      case SectionCardStyle.flat:
        return BoxDecoration(
          color: _lightTint,
          borderRadius: radius,
        );
    }
  }

  Widget _buildSectionHeader(String title) {
    switch (sectionStyle.headerStyle) {
      case SectionHeaderStyle.fullWidth:
        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: sectionStyle.innerPadding * _scale,
            vertical: 4 * _scale,
          ),
          decoration: BoxDecoration(
            color: _primaryColor,
            borderRadius: sectionStyle.cardStyle == SectionCardStyle.flat
                ? null
                : BorderRadius.only(
                    topLeft: Radius.circular(sectionStyle.cornerRadius.pixels * _scale),
                    topRight: Radius.circular(sectionStyle.cornerRadius.pixels * _scale),
                  ),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: typography.sectionHeaderSize * _scale,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        );

      case SectionHeaderStyle.leftAccent:
        return Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            sectionStyle.innerPadding * _scale,
            4 * _scale,
            sectionStyle.innerPadding * _scale,
            4 * _scale,
          ),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: _primaryColor, width: 3 * _scale),
            ),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: typography.sectionHeaderSize * _scale,
              fontWeight: FontWeight.bold,
              color: _primaryColor,
              letterSpacing: 0.5,
            ),
          ),
        );

      case SectionHeaderStyle.underlined:
        return Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            sectionStyle.innerPadding * _scale,
            4 * _scale,
            sectionStyle.innerPadding * _scale,
            4 * _scale,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: _mediumTint, width: 1),
            ),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: typography.sectionHeaderSize * _scale,
              fontWeight: FontWeight.bold,
              color: _primaryColor,
              letterSpacing: 0.5,
            ),
          ),
        );
    }
  }

  Widget _buildFieldRow(String label, String value, bool isAlternate) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 4 * _scale,
        vertical: 2 * _scale,
      ),
      decoration: BoxDecoration(
        color: isAlternate ? _lightTint : null,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 60 * _scale,
            child: Text(
              label,
              style: TextStyle(
                fontSize: typography.fieldLabelSize * _scale,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: typography.fieldValueSize * _scale,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableSection() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _mediumTint.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(sectionStyle.cornerRadius.pixels * _scale),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Table header
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: 6 * _scale,
              vertical: 4 * _scale,
            ),
            color: _primaryColor,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Description',
                    style: TextStyle(
                      fontSize: typography.tableHeaderSize * _scale,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Qty',
                    style: TextStyle(
                      fontSize: typography.tableHeaderSize * _scale,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Total',
                    style: TextStyle(
                      fontSize: typography.tableHeaderSize * _scale,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          // Table rows
          _buildTableRow('Service item one', '1', '\u00A3250.00'),
          _buildTableRow('Service item two', '2', '\u00A3500.00'),
        ],
      ),
    );
  }

  Widget _buildTableRow(String desc, String qty, String total) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 6 * _scale,
        vertical: 3 * _scale,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              desc,
              style: TextStyle(
                fontSize: typography.tableBodySize * _scale,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              qty,
              style: TextStyle(
                fontSize: typography.tableBodySize * _scale,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              total,
              style: TextStyle(
                fontSize: typography.tableBodySize * _scale,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureSection() {
    return Row(
      children: [
        Expanded(child: _buildSignatureBox('Engineer')),
        SizedBox(width: 8 * _scale),
        Expanded(child: _buildSignatureBox('Customer')),
      ],
    );
  }

  Widget _buildSignatureBox(String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: typography.fieldLabelSize * _scale,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: 2 * _scale),
        Container(
          height: 24 * _scale,
          decoration: BoxDecoration(
            color: _lightTint,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Center(
            child: Text(
              'Signature',
              style: TextStyle(
                fontSize: 6 * _scale,
                color: Colors.grey.shade400,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    if (footerConfig.leftLines.isEmpty && footerConfig.centreLines.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 12 * _scale,
        vertical: 6 * _scale,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Left zone
          if (footerConfig.leftLines.isNotEmpty)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: footerConfig.leftLines.map((line) {
                  final text = line.value.isNotEmpty
                      ? line.value
                      : fallbackValues[line.key] ?? _defaultForKey(line.key);
                  return Text(
                    text,
                    style: TextStyle(
                      fontSize: typography.footerSize * _scale,
                      fontWeight: line.bold ? FontWeight.bold : FontWeight.normal,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                }).toList(),
              ),
            ),

          // Centre zone
          if (footerConfig.centreLines.isNotEmpty)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: footerConfig.centreLines.map((line) {
                  final text = line.value.isNotEmpty
                      ? line.value
                      : fallbackValues[line.key] ?? _defaultForKey(line.key);
                  return Text(
                    text,
                    style: TextStyle(
                      fontSize: typography.footerSize * _scale,
                      fontWeight: line.bold ? FontWeight.bold : FontWeight.normal,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                }).toList(),
              ),
            ),

          // Page number (right zone)
          Text(
            'Page 1 of 1',
            style: TextStyle(
              fontSize: typography.footerSize * _scale,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
