import 'dart:convert';
import 'package:pdf/widgets.dart' as pw;
import '../../models/pdf_colour_scheme.dart';
import '../../models/pdf_typography_config.dart';

/// Builds improved signature section with two boxes side by side
pw.Widget buildSignatureSection({
  required String? engineerSignatureBase64,
  required String? customerSignatureBase64,
  required String engineerName,
  required String? customerName,
  required String date,
  required PdfColourScheme colors,
  required PdfTypographyConfig typography,
  double boxHeight = 60,
}) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        child: _buildSignatureBox(
          title: 'Engineer Signature',
          signatureBase64: engineerSignatureBase64,
          name: engineerName,
          date: date,
          colors: colors,
          typography: typography,
          boxHeight: boxHeight,
        ),
      ),
      pw.SizedBox(width: 16),
      pw.Expanded(
        child: _buildSignatureBox(
          title: 'Customer / Site Representative',
          signatureBase64: customerSignatureBase64,
          name: customerName ?? '',
          date: date,
          colors: colors,
          typography: typography,
          boxHeight: boxHeight,
        ),
      ),
    ],
  );
}

pw.Widget _buildSignatureBox({
  required String title,
  required String? signatureBase64,
  required String name,
  required String date,
  required PdfColourScheme colors,
  required PdfTypographyConfig typography,
  required double boxHeight,
}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: typography.fieldLabelSize + 1,
          fontWeight: pw.FontWeight.bold,
          color: colors.textSecondary,
        ),
      ),
      pw.SizedBox(height: 6),
      pw.Container(
        height: boxHeight,
        width: double.infinity,
        decoration: pw.BoxDecoration(
          color: colors.primarySoft,
          border: pw.Border.all(color: colors.primaryMedium, width: 0.5),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: signatureBase64 != null && signatureBase64.isNotEmpty
            ? pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Center(
                  child: pw.Image(
                    pw.MemoryImage(base64Decode(signatureBase64)),
                    fit: pw.BoxFit.contain,
                  ),
                ),
              )
            : pw.Center(
                child: pw.Text(
                  'Signature',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: colors.textMuted,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
      ),
      pw.SizedBox(height: 6),
      _buildNameDateRow(name, date, colors, typography),
    ],
  );
}

pw.Widget _buildNameDateRow(
  String name,
  String date,
  PdfColourScheme colors,
  PdfTypographyConfig typography,
) {
  return pw.Row(
    children: [
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'NAME',
              style: pw.TextStyle(
                fontSize: typography.fieldLabelSize - 1,
                color: colors.textMuted,
                letterSpacing: 0.5,
              ),
            ),
            pw.Text(
              name.isEmpty ? '-' : name,
              style: pw.TextStyle(
                fontSize: typography.fieldValueSize - 1,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
      pw.SizedBox(width: 8),
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'DATE',
            style: pw.TextStyle(
              fontSize: typography.fieldLabelSize - 1,
              color: colors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          pw.Text(
            date,
            style: pw.TextStyle(
              fontSize: typography.fieldValueSize - 1,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    ],
  );
}
