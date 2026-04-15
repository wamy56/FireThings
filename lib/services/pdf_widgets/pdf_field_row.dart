import 'package:pdf/widgets.dart' as pw;
import '../../models/pdf_colour_scheme.dart';
import '../../models/pdf_typography_config.dart';

/// Builds a 2-column grid of label/value pairs
pw.Widget buildFieldGrid({
  required List<(String label, String value)> fields,
  required PdfColourScheme colors,
  required PdfTypographyConfig typography,
  bool alternatingBackground = true,
  bool twoColumn = true,
}) {
  if (!twoColumn) {
    return _buildSingleColumnLayout(
        fields, colors, typography, alternatingBackground);
  }

  final rows = <pw.Widget>[];

  for (int i = 0; i < fields.length; i += 2) {
    final isAlternate = (i ~/ 2).isOdd;
    final leftField = fields[i];
    final rightField = i + 1 < fields.length ? fields[i + 1] : null;

    rows.add(
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: pw.BoxDecoration(
          color:
              alternatingBackground && isAlternate ? colors.primarySoft : null,
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _buildField(leftField, colors, typography)),
            if (rightField != null) ...[
              pw.SizedBox(width: 16),
              pw.Expanded(child: _buildField(rightField, colors, typography)),
            ] else
              pw.Expanded(child: pw.SizedBox()),
          ],
        ),
      ),
    );
  }

  return pw.Column(children: rows);
}

pw.Widget _buildSingleColumnLayout(
  List<(String label, String value)> fields,
  PdfColourScheme colors,
  PdfTypographyConfig typography,
  bool alternatingBackground,
) {
  return pw.Column(
    children: fields.asMap().entries.map((entry) {
      final isAlternate = entry.key.isOdd;
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: pw.BoxDecoration(
          color:
              alternatingBackground && isAlternate ? colors.primarySoft : null,
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: _buildField(entry.value, colors, typography),
      );
    }).toList(),
  );
}

pw.Widget _buildField(
  (String label, String value) field,
  PdfColourScheme colors,
  PdfTypographyConfig typography,
) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        field.$1.toUpperCase(),
        style: pw.TextStyle(
          fontSize: typography.fieldLabelSize,
          color: colors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        field.$2.isEmpty ? '-' : field.$2,
        style: pw.TextStyle(
          fontSize: typography.fieldValueSize,
          fontWeight: pw.FontWeight.bold,
          color: colors.textPrimary,
        ),
      ),
    ],
  );
}

/// Builds a compact inline field row (label: value)
pw.Widget buildCompactFieldRow({
  required String label,
  required String value,
  required PdfColourScheme colors,
  required PdfTypographyConfig typography,
  bool isAlternate = false,
  bool alternatingBackground = true,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: pw.BoxDecoration(
      color: alternatingBackground && isAlternate ? colors.primarySoft : null,
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 90,
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: typography.fieldLabelSize + 1,
              fontWeight: pw.FontWeight.bold,
              color: colors.textSecondary,
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value.isEmpty ? '-' : value,
            style: pw.TextStyle(
              fontSize: typography.fieldValueSize,
              color: colors.textPrimary,
            ),
          ),
        ),
      ],
    ),
  );
}
