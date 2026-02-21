import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../models/pdf_colour_scheme.dart';
import 'payment_settings_service.dart';
import 'branding_service.dart';
import 'pdf_header_config_service.dart';
import 'pdf_header_builder.dart';
import 'pdf_footer_config_service.dart';
import 'pdf_footer_builder.dart';
import 'pdf_colour_scheme_service.dart';
import 'pdf_generation_data.dart';

/// Top-level function for compute() — builds the invoice PDF in a background isolate.
Future<Uint8List> _buildInvoicePdf(InvoicePdfData data) async {
  final invoice = Invoice.fromJson(data.invoiceJson);
  final headerConfig = PdfHeaderConfig.fromJson(data.headerConfigJson);
  final footerConfig = PdfFooterConfig.fromJson(data.footerConfigJson);
  final colourScheme = PdfColourScheme(primaryColorValue: data.colourSchemeValue);
  final primaryColor = colourScheme.primaryColor;
  final primaryLightColor = colourScheme.primaryLight;

  final paymentDetails = PaymentDetails(
    bankName: data.paymentDetailsMap['bankName'] ?? '',
    accountName: data.paymentDetailsMap['accountName'] ?? '',
    sortCode: data.paymentDetailsMap['sortCode'] ?? '',
    accountNumber: data.paymentDetailsMap['accountNumber'] ?? '',
    paymentTerms: data.paymentDetailsMap['paymentTerms'] ?? '',
  );

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
          _buildHeader(invoice, data.logoBytes, headerConfig, primaryColor),
          pw.SizedBox(height: 24),
          _buildInvoiceInfo(invoice),
          pw.SizedBox(height: 24),
          _buildCustomerSection(invoice, primaryColor),
          pw.SizedBox(height: 24),
          _buildItemsTable(invoice, primaryColor),
          pw.SizedBox(height: 16),
          _buildTotalsSection(invoice, primaryColor),
          if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
            pw.SizedBox(height: 24),
            _buildNotesSection(invoice),
          ],
          pw.Spacer(),
          if (!paymentDetails.isEmpty) _buildPaymentTerms(paymentDetails, primaryColor, primaryLightColor),
          pw.SizedBox(height: 16),
          PdfFooterBuilder.buildFooter(
            config: footerConfig,
            pageNumber: 1,
            pagesCount: 1,
            primaryColor: primaryColor,
          ),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text(
              'Thank you for your business!',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor),
            ),
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

pw.Widget _buildHeader(Invoice invoice, Uint8List? logoBytes, PdfHeaderConfig headerConfig, PdfColor primaryColor) {
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
            fallbackValues: {
              'companyName': invoice.engineerName,
              'engineerName': invoice.engineerName,
            },
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: primaryColor,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Text(
            'INVOICE',
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

pw.Widget _buildInvoiceInfo(Invoice invoice) {
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
            _buildInfoRow('Invoice No:', invoice.invoiceNumber),
            pw.SizedBox(height: 4),
            _buildInfoRow('Date:', dateFormat.format(invoice.date)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Due Date:', dateFormat.format(invoice.dueDate)),
            pw.SizedBox(height: 4),
            _buildInfoRow(
              'Status:',
              invoice.status.name.toUpperCase(),
              valueColor: invoice.status == InvoiceStatus.paid
                  ? PdfColors.green
                  : _darkGray,
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

pw.Widget _buildCustomerSection(Invoice invoice, PdfColor primaryColor) {
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
          'BILL TO:',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: primaryColor,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          invoice.customerName,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          invoice.customerAddress,
          style: const pw.TextStyle(fontSize: 10, color: _darkGray),
        ),
      ],
    ),
  );
}

pw.Widget _buildItemsTable(Invoice invoice, PdfColor primaryColor) {
  final currencyFormat = NumberFormat.currency(symbol: '\u00A3', decimalDigits: 2);

  return pw.Table(
    border: pw.TableBorder.all(color: _lightGray),
    columnWidths: {
      0: const pw.FlexColumnWidth(4),
      1: const pw.FlexColumnWidth(1),
      2: const pw.FlexColumnWidth(1.5),
      3: const pw.FlexColumnWidth(1.5),
    },
    children: [
      pw.TableRow(
        decoration: pw.BoxDecoration(color: primaryColor),
        children: [
          _buildTableHeader('Description'),
          _buildTableHeader('Qty'),
          _buildTableHeader('Unit Price'),
          _buildTableHeader('Total'),
        ],
      ),
      ...invoice.items.map((item) => pw.TableRow(
            children: [
              _buildTableCell(item.description),
              _buildTableCell(item.quantity.toString(), center: true),
              _buildTableCell(currencyFormat.format(item.unitPrice), right: true),
              _buildTableCell(currencyFormat.format(item.total), right: true),
            ],
          )),
    ],
  );
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

pw.Widget _buildTotalsSection(Invoice invoice, PdfColor primaryColor) {
  final currencyFormat = NumberFormat.currency(symbol: '\u00A3', decimalDigits: 2);

  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.end,
    children: [
      pw.Container(
        width: 200,
        child: pw.Column(
          children: [
            _buildTotalRow('Subtotal:', currencyFormat.format(invoice.subtotal)),
            if (invoice.includeVat) ...[
              pw.SizedBox(height: 4),
              _buildTotalRow('VAT (20%):', currencyFormat.format(invoice.tax)),
            ],
            pw.Divider(color: _darkGray),
            _buildTotalRow(
              'TOTAL:',
              currencyFormat.format(invoice.total),
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

pw.Widget _buildNotesSection(Invoice invoice) {
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
          invoice.notes!,
          style: const pw.TextStyle(fontSize: 9, color: _darkGray),
        ),
      ],
    ),
  );
}

pw.Widget _buildPaymentTerms(PaymentDetails paymentDetails, PdfColor primaryColor, PdfColor primaryLightColor) {
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
          'Payment Details',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: primaryColor,
          ),
        ),
        pw.SizedBox(height: 6),
        if (paymentDetails.paymentTerms.isNotEmpty)
          pw.Text(
            paymentDetails.paymentTerms,
            style: const pw.TextStyle(fontSize: 9, color: _darkGray),
          ),
        if (paymentDetails.bankName.isNotEmpty || paymentDetails.accountName.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            '${paymentDetails.bankName.isNotEmpty ? "Bank: ${paymentDetails.bankName}" : ""}${paymentDetails.bankName.isNotEmpty && paymentDetails.accountName.isNotEmpty ? " | " : ""}${paymentDetails.accountName.isNotEmpty ? "Account Name: ${paymentDetails.accountName}" : ""}',
            style: const pw.TextStyle(fontSize: 9, color: _darkGray),
          ),
        ],
        if (paymentDetails.sortCode.isNotEmpty || paymentDetails.accountNumber.isNotEmpty)
          pw.Text(
            '${paymentDetails.sortCode.isNotEmpty ? "Sort Code: ${paymentDetails.sortCode}" : ""}${paymentDetails.sortCode.isNotEmpty && paymentDetails.accountNumber.isNotEmpty ? " | " : ""}${paymentDetails.accountNumber.isNotEmpty ? "Account No: ${paymentDetails.accountNumber}" : ""}',
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
    ttf.data.buffer.asUint8List(ttf.data.offsetInBytes, ttf.data.lengthInBytes),
  );
}

class InvoicePDFService {
  static Future<Uint8List> generateInvoicePDF(
    Invoice invoice,
    PaymentDetails paymentDetails,
  ) async {
    // ── Gather phase (main thread) ──
    Uint8List? regularFontBytes;
    Uint8List? boldFontBytes;
    try {
      final regularFont = await PdfGoogleFonts.robotoRegular();
      final boldFont = await PdfGoogleFonts.robotoBold();
      regularFontBytes = _extractFontBytes(regularFont);
      boldFontBytes = _extractFontBytes(boldFont);
    } catch (_) {
      // Google Fonts unavailable — isolate will fall back to Helvetica
    }

    final logoBytes = await BrandingService.getLogoBytes();
    final headerConfig = await PdfHeaderConfigService.getConfig();
    final footerConfig = await PdfFooterConfigService.getConfig();
    final colourScheme = await PdfColourSchemeService.getScheme();

    final data = InvoicePdfData(
      invoiceJson: invoice.toJson(),
      paymentDetailsMap: {
        'bankName': paymentDetails.bankName,
        'accountName': paymentDetails.accountName,
        'sortCode': paymentDetails.sortCode,
        'accountNumber': paymentDetails.accountNumber,
        'paymentTerms': paymentDetails.paymentTerms,
      },
      logoBytes: logoBytes,
      headerConfigJson: headerConfig.toJson(),
      footerConfigJson: footerConfig.toJson(),
      colourSchemeValue: colourScheme.primaryColorValue,
      regularFontBytes: regularFontBytes,
      boldFontBytes: boldFontBytes,
    );

    // ── Build phase (background isolate) ──
    return compute(_buildInvoicePdf, data);
  }

  static Future<void> sharePDF(Uint8List pdfBytes, String filename) async {
    await Printing.sharePdf(bytes: pdfBytes, filename: filename);
  }

  static Future<void> printPDF(Uint8List pdfBytes) async {
    await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
  }
}
