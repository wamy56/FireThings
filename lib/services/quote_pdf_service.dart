import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import 'pdf_branding_service.dart';
import 'pdf_header_builder.dart';
import 'pdf_footer_builder.dart';
import 'company_pdf_config_service.dart';
import 'pdf_generation_data.dart';
import 'user_profile_service.dart';

int _hexToColorValue(String hex) {
  final clean = hex.replaceFirst('#', '');
  return 0xFF000000 | int.parse(clean, radix: 16);
}

/// Top-level function for compute() — builds the quote PDF in a background isolate.
Future<Uint8List> _buildQuotePdf(QuotePdfData data) async {
  final quote = Quote.fromJson(data.quoteJson);
  final headerConfig = PdfHeaderConfig.fromJson(data.headerConfigJson);
  final footerConfig = PdfFooterConfig.fromJson(data.footerConfigJson);
  final colourScheme =
      PdfColourScheme(primaryColorValue: data.colourSchemeValue);
  final primaryColor = colourScheme.primaryColor;

  final branding = data.brandingJson != null
      ? PdfBranding.fromJson(data.brandingJson!)
      : null;

  final effectiveFooterConfig = branding != null && branding.footerText.isNotEmpty
      ? PdfFooterConfig(
          leftLines: [HeaderTextLine(key: 'brandingText', value: branding.footerText, fontSize: 8)],
          centreLines: const [],
        )
      : footerConfig;

  final regularFont = data.regularFontBytes != null
      ? pw.Font.ttf(ByteData.sublistView(data.regularFontBytes!))
      : pw.Font.helvetica();
  final boldFont = data.boldFontBytes != null
      ? pw.Font.ttf(ByteData.sublistView(data.boldFontBytes!))
      : pw.Font.helveticaBold();

  final pdf = pw.Document(
    theme: pw.ThemeData.withFont(
      base: regularFont,
      bold: boldFont,
    ),
  );

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildHeader(quote, data.logoBytes, headerConfig, primaryColor,
            showCompanyName: branding?.headerShowCompanyName ?? true),
          pw.SizedBox(height: 24),
          _buildQuoteInfo(quote),
          pw.SizedBox(height: 24),
          _buildCustomerSection(quote, primaryColor),
          if (quote.defectId != null && quote.defectDescription != null) ...[
            pw.SizedBox(height: 24),
            _buildDefectSummary(quote),
          ],
          pw.SizedBox(height: 24),
          _buildItemsTable(quote, primaryColor),
          pw.SizedBox(height: 16),
          _buildTotalsSection(quote, primaryColor),
          if (quote.notes != null && quote.notes!.isNotEmpty) ...[
            pw.SizedBox(height: 24),
            _buildNotesSection(quote),
          ],
          pw.Spacer(),
          _buildTermsSection(quote, primaryColor),
          pw.SizedBox(height: 16),
          PdfFooterBuilder.buildFooter(
            config: effectiveFooterConfig,
            pageNumber: 1,
            pagesCount: 1,
            primaryColor: primaryColor,
            brandingFooterStyle: branding?.footerStyle,
            accentColor: branding != null
                ? PdfColor.fromInt(_hexToColorValue(branding.accentColour))
                : null,
            showPageNumbers: branding?.footerShowPageNumbers ?? true,
          ),
        ],
      ),
    ),
  );

  return await pdf.save();
}

// ── Constants ──

const _coralAccent = PdfColor.fromInt(0xFFF97316);
const PdfColor _darkGray = PdfColor.fromInt(0xFF424242);
const PdfColor _lightGray = PdfColor.fromInt(0xFFE0E0E0);
const PdfColor _white = PdfColors.white;

// ── Builder helpers (top-level for isolate compatibility) ──

pw.Widget _buildHeader(
  Quote quote,
  Uint8List? logoBytes,
  PdfHeaderConfig headerConfig,
  PdfColor primaryColor, {
  bool showCompanyName = true,
}) {
  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(color: primaryColor, width: 2),
      ),
    ),
    padding: const pw.EdgeInsets.only(bottom: 12),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 5,
          child: PdfHeaderBuilder.buildLeftAndCentre(
            config: headerConfig,
            logoBytes: logoBytes,
            primaryColor: primaryColor,
            showCompanyName: showCompanyName,
            fallbackValues: {
              'companyName': quote.engineerName,
              'engineerName': quote.engineerName,
            },
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: const pw.BoxDecoration(
            color: _coralAccent,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Text(
            'QUOTE',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: _white,
            ),
          ),
        ),
      ],
    ),
  );
}

pw.Widget _buildQuoteInfo(Quote quote) {
  final dateFormat = DateFormat('dd/MM/yyyy');

  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: PdfColor.fromInt(0xFFF5F5F5),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Quote No:', quote.quoteNumber),
            pw.SizedBox(height: 4),
            _buildInfoRow('Date:', dateFormat.format(quote.createdAt)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Valid Until:', dateFormat.format(quote.validUntil)),
            pw.SizedBox(height: 4),
            _buildInfoRow(
              'Status:',
              quote.status.name.toUpperCase(),
              valueColor:
                  quote.status == QuoteStatus.approved ? PdfColors.green : null,
            ),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _buildInfoRow(
  String label,
  String value, {
  PdfColor? valueColor,
}) {
  return pw.Row(
    children: [
      pw.Text(
        label,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: _darkGray,
        ),
      ),
      pw.SizedBox(width: 8),
      pw.Text(
        value,
        style: pw.TextStyle(
          fontSize: 10,
          color: valueColor ?? _darkGray,
          fontWeight: valueColor != null ? pw.FontWeight.bold : null,
        ),
      ),
    ],
  );
}

pw.Widget _buildCustomerSection(Quote quote, PdfColor primaryColor) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _lightGray),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'QUOTATION FOR:',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: primaryColor,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          quote.customerName,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          quote.customerAddress,
          style: const pw.TextStyle(fontSize: 10, color: _darkGray),
        ),
        if (quote.siteName.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            'Site: ${quote.siteName}',
            style: const pw.TextStyle(fontSize: 10, color: _darkGray),
          ),
        ],
      ],
    ),
  );
}

pw.Widget _buildDefectSummary(Quote quote) {
  PdfColor severityColor;
  switch (quote.defectSeverity) {
    case 'critical':
      severityColor = PdfColor.fromInt(0xFFD32F2F);
      break;
    case 'major':
      severityColor = PdfColor.fromInt(0xFFF97316);
      break;
    default:
      severityColor = PdfColor.fromInt(0xFF4CAF50);
  }

  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: PdfColor.fromInt(0xFFFFF3E0),
      border: pw.Border.all(color: PdfColor.fromInt(0xFFFFCC80)),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Text(
              'DEFECT FOUND DURING INSPECTION',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: _darkGray,
              ),
            ),
            pw.SizedBox(width: 8),
            if (quote.defectSeverity != null)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: pw.BoxDecoration(
                  color: severityColor,
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(2)),
                ),
                child: pw.Text(
                  quote.defectSeverity!.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: _white,
                  ),
                ),
              ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          quote.defectDescription!,
          style: const pw.TextStyle(fontSize: 10, color: _darkGray),
        ),
        if (quote.defectClauseReference != null) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            'BS 5839-1:2025 cl. ${quote.defectClauseReference}',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: _darkGray,
            ),
          ),
        ],
        if (quote.defectTriggeredProhibitedRule) ...[
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFFFEBEE),
              border: pw.Border.all(color: PdfColor.fromInt(0xFFD32F2F)),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
            ),
            child: pw.Text(
              'PROHIBITED VARIATION — This defect violates a mandatory requirement of BS 5839-1:2025 and must be rectified.',
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromInt(0xFFD32F2F),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

pw.Widget _buildItemsTable(Quote quote, PdfColor primaryColor) {
  final currencyFormat =
      NumberFormat.currency(symbol: '\u00A3', decimalDigits: 2);

  return pw.Table(
    border: pw.TableBorder.all(color: _lightGray),
    columnWidths: {
      0: const pw.FlexColumnWidth(3),
      1: const pw.FlexColumnWidth(1.2),
      2: const pw.FlexColumnWidth(1),
      3: const pw.FlexColumnWidth(1.2),
      4: const pw.FlexColumnWidth(1.2),
    },
    children: [
      pw.TableRow(
        decoration: pw.BoxDecoration(color: primaryColor),
        children: [
          _buildTableHeader('Description'),
          _buildTableHeader('Category'),
          _buildTableHeader('Qty'),
          _buildTableHeader('Unit Price'),
          _buildTableHeader('Total'),
        ],
      ),
      ...quote.items.map((item) => pw.TableRow(
            children: [
              _buildTableCell(item.description),
              _buildTableCell(
                  _formatCategory(item.category)),
              _buildTableCell(
                  item.quantity == item.quantity.truncateToDouble()
                      ? item.quantity.toInt().toString()
                      : item.quantity.toString(),
                  center: true),
              _buildTableCell(currencyFormat.format(item.unitPrice),
                  right: true),
              _buildTableCell(currencyFormat.format(item.total),
                  right: true),
            ],
          )),
    ],
  );
}

String _formatCategory(String? category) {
  if (category == null || category.isEmpty) return '-';
  return '${category[0].toUpperCase()}${category.substring(1)}';
}

pw.Widget _buildTableHeader(String text) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(8),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
        color: _white,
      ),
    ),
  );
}

pw.Widget _buildTableCell(
  String text, {
  bool center = false,
  bool right = false,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(8),
    child: pw.Text(
      text,
      style: const pw.TextStyle(fontSize: 10),
      textAlign: right
          ? pw.TextAlign.right
          : center
              ? pw.TextAlign.center
              : pw.TextAlign.left,
    ),
  );
}

pw.Widget _buildTotalsSection(Quote quote, PdfColor primaryColor) {
  final currencyFormat =
      NumberFormat.currency(symbol: '\u00A3', decimalDigits: 2);

  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.end,
    children: [
      pw.Container(
        width: 200,
        child: pw.Column(
          children: [
            _buildTotalRow(
                'Subtotal:', currencyFormat.format(quote.subtotal)),
            if (quote.includeVat) ...[
              pw.SizedBox(height: 4),
              _buildTotalRow(
                  'VAT (20%):', currencyFormat.format(quote.vatAmount)),
            ],
            pw.Divider(color: _darkGray),
            _buildTotalRow(
              'TOTAL:',
              currencyFormat.format(quote.total),
              isBold: true,
              isLarge: true,
              primaryColor: primaryColor,
            ),
          ],
        ),
      ),
    ],
  );
}

pw.Widget _buildTotalRow(
  String label,
  String value, {
  bool isBold = false,
  bool isLarge = false,
  PdfColor? primaryColor,
}) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(
        label,
        style: pw.TextStyle(
          fontSize: isLarge ? 12 : 10,
          fontWeight: isBold ? pw.FontWeight.bold : null,
          color: _darkGray,
        ),
      ),
      pw.Text(
        value,
        style: pw.TextStyle(
          fontSize: isLarge ? 14 : 10,
          fontWeight: isBold ? pw.FontWeight.bold : null,
          color: isBold ? (primaryColor ?? _darkGray) : _darkGray,
        ),
      ),
    ],
  );
}

pw.Widget _buildNotesSection(Quote quote) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: PdfColor.fromInt(0xFFFFF9E6),
      border: pw.Border.all(color: PdfColor.fromInt(0xFFFFE082)),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Notes:',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: _darkGray,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          quote.notes!,
          style: const pw.TextStyle(fontSize: 9, color: _darkGray),
        ),
      ],
    ),
  );
}

pw.Widget _buildTermsSection(Quote quote, PdfColor primaryColor) {
  final dateFormat = DateFormat('d MMMM yyyy');
  final primaryLightColor = PdfColor.fromInt(
    (primaryColor.toInt() & 0x00FFFFFF) | 0x1A000000,
  );

  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: primaryLightColor,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Terms',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: primaryColor,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'This quote is valid until ${dateFormat.format(quote.validUntil)}.',
          style: const pw.TextStyle(fontSize: 9, color: _darkGray),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'To accept, please reply to this email or call us.',
          style: const pw.TextStyle(fontSize: 9, color: _darkGray),
        ),
      ],
    ),
  );
}

/// Extracts raw TTF bytes from a Font loaded via PdfGoogleFonts.
Uint8List _extractFontBytes(pw.Font font) {
  final ttf = font as pw.TtfFont;
  return Uint8List.fromList(
    ttf.data.buffer
        .asUint8List(ttf.data.offsetInBytes, ttf.data.lengthInBytes),
  );
}

class QuotePdfService {
  static Future<Uint8List> generateQuotePdf(Quote quote) async {
    Uint8List? regularFontBytes;
    Uint8List? boldFontBytes;
    try {
      final regularFont = await PdfGoogleFonts.robotoRegular();
      final boldFont = await PdfGoogleFonts.robotoBold();
      regularFontBytes = _extractFontBytes(regularFont);
      boldFontBytes = _extractFontBytes(boldFont);
    } catch (_) {}

    PdfBranding? branding;
    Uint8List? brandingLogoBytes;

    if (quote.useCompanyBranding) {
      final companyId = UserProfileService.instance.companyId;
      if (companyId != null) {
        try {
          final b = await PdfBrandingService.instance.getBranding(companyId);
          if (b.appliesToDocType(BrandingDocType.quote)) {
            branding = b;
            if (b.logoUrl != null) {
              try {
                final response = await http.get(Uri.parse(b.logoUrl!));
                if (response.statusCode == 200) brandingLogoBytes = response.bodyBytes;
              } catch (e) {
                debugPrint('Failed to download branding logo: $e');
              }
            }
          }
        } catch (e) {
          debugPrint('Failed to load PdfBranding: $e');
        }
      }
    }

    final companyPdf = CompanyPdfConfigService.instance;
    final logoBytes = brandingLogoBytes ?? await companyPdf.getEffectiveLogoBytes(
      useCompanyBranding: quote.useCompanyBranding,
      type: PdfDocumentType.quote,
    );
    final headerConfig = await companyPdf.getEffectiveHeaderConfig(
      PdfDocumentType.quote,
      useCompanyBranding: quote.useCompanyBranding,
    );
    final footerConfig = await companyPdf.getEffectiveFooterConfig(
      PdfDocumentType.quote,
      useCompanyBranding: quote.useCompanyBranding,
    );
    final colourScheme = await companyPdf.getEffectiveColourScheme(
      PdfDocumentType.quote,
      useCompanyBranding: quote.useCompanyBranding,
    );

    final effectiveColourValue = branding != null
        ? _hexToColorValue(branding.primaryColour)
        : colourScheme.primaryColorValue;

    final data = QuotePdfData(
      quoteJson: quote.toJson(),
      logoBytes: logoBytes,
      headerConfigJson: headerConfig.toJson(),
      footerConfigJson: footerConfig.toJson(),
      colourSchemeValue: effectiveColourValue,
      brandingJson: branding?.toJson(),
      regularFontBytes: regularFontBytes,
      boldFontBytes: boldFontBytes,
    );

    if (kIsWeb) return _buildQuotePdf(data);
    return compute(_buildQuotePdf, data);
  }

  static Future<void> sharePdf(Uint8List pdfBytes, String filename) async {
    await Printing.sharePdf(bytes: pdfBytes, filename: filename);
  }

  static Future<void> printPdf(Uint8List pdfBytes) async {
    await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
  }
}
