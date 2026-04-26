import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../models/models.dart' show PdfBranding, BrandingDocType, Quote, QuoteStatus;
import 'pdf_branding_service.dart';
import 'pdf_footer_builder.dart';
import 'pdf_generation_data.dart';
import 'company_service.dart';
import 'user_profile_service.dart';
import 'jobsheet_settings_service.dart';

import 'pdf_widgets/pdf_brand_tokens.dart';
import 'pdf_widgets/pdf_cover_builder.dart';
import 'pdf_widgets/pdf_font_registry.dart';
import 'pdf_widgets/pdf_modern_header.dart' show PdfHeaderBuilder;

/// Top-level function for compute() — builds the quote PDF in a background isolate.
Future<Uint8List> _buildQuotePdf(QuotePdfData data) async {
  final quote = Quote.fromJson(data.quoteJson);

  final branding = PdfBranding.fromJson(data.brandingJson);
  if (data.brandedFontBytes != null) {
    PdfFontRegistry.instance.loadFromBytes(data.brandedFontBytes!);
  }
  final fonts = PdfFontRegistry.instance;
  final pdf = pw.Document(
    theme: pw.ThemeData.withFont(
      base: fonts.interRegular,
      bold: fonts.interBold,
    ),
  );

  final primaryColor = PdfBrandTokens.primary(branding);
  final companyName = data.companyName;
  final dateStr = DateFormat('dd/MM/yyyy').format(quote.createdAt);

  // Cover page
  pdf.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: pw.EdgeInsets.zero,
    build: (_) => PdfCoverBuilder.build(
      branding: branding,
      docType: BrandingDocType.quote,
      defaultEyebrow: 'QUOTE',
      defaultTitle: 'Quote',
      defaultSubtitle: '${quote.customerName} · $dateStr',
      metaFields: [
        (label: 'QUOTE NO', value: quote.quoteNumber),
        (label: 'CUSTOMER', value: quote.customerName),
        (label: 'DATE', value: dateStr),
        (label: 'PREPARED BY', value: companyName),
      ],
      logoBytes: data.logoBytes,
      companyName: companyName,
    ),
  ));

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          PdfHeaderBuilder.build(
            branding: branding,
            companyName: companyName,
            metaText: 'QUOTE ${quote.quoteNumber}',
            logoBytes: data.logoBytes,
          ),
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
          PdfFooterBuilder.buildBrandedFooter(
            branding: branding,
            pageNumber: 1,
            pagesCount: 1,
            companyName: companyName,
            defaultFooterText: 'Quote ${quote.quoteNumber}',
          ),
        ],
      ),
    ),
  );

  return await pdf.save();
}

// ── Constants ──

const PdfColor _darkGray = PdfColor.fromInt(0xFF424242);
const PdfColor _lightGray = PdfColor.fromInt(0xFFE0E0E0);
const PdfColor _white = PdfColors.white;

// ── Builder helpers (top-level for isolate compatibility) ──

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

    // Branding
    PdfBrandingService.instance.clearCache();
    PdfBranding branding = PdfBranding.defaultBranding();
    Uint8List? brandingLogoBytes;
    try {
      final b = await PdfBrandingService.instance.resolveBrandingForCurrentUser();
      if (b.appliesToDocType(BrandingDocType.quote)) {
        branding = b;
      }
      if (branding.logoUrl != null) {
        try {
          final response = await http.get(Uri.parse(branding.logoUrl!));
          if (response.statusCode == 200) brandingLogoBytes = response.bodyBytes;
        } catch (e) {
          debugPrint('[BRANDING] Failed to download logo: $e');
        }
      }
    } catch (e, stack) {
      if (kIsWeb) {
        debugPrint('[BRANDING-RESOLUTION] PdfBranding resolution failed: $e');
      } else {
        FirebaseCrashlytics.instance.recordError(
          e, stack,
          reason: 'PdfBranding resolution failed — using default',
        );
      }
    }

    Map<String, Uint8List>? brandedFontBytes;
    try {
      await PdfFontRegistry.instance.ensureLoaded();
      brandedFontBytes = PdfFontRegistry.instance.extractFontBytes();
    } catch (e) {
      debugPrint('[BRANDING] Failed to load branded fonts: $e');
    }

    // Company name: Company doc → settings → quote.engineerName
    String companyName = '';
    final cid = UserProfileService.instance.companyId;
    if (cid != null) {
      final company = await CompanyService.instance.getCompany(cid);
      companyName = company?.name ?? '';
    }
    if (companyName.isEmpty) {
      final settings = await JobsheetSettingsService.getSettings();
      companyName = settings.companyName;
    }
    if (companyName.isEmpty) {
      companyName = quote.engineerName;
    }

    final data = QuotePdfData(
      quoteJson: quote.toJson(),
      logoBytes: brandingLogoBytes,
      brandingJson: branding.toJson(),
      regularFontBytes: regularFontBytes,
      boldFontBytes: boldFontBytes,
      brandedFontBytes: brandedFontBytes,
      companyName: companyName,
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
