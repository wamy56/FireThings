import 'package:pdf/widgets.dart' as pw;
import '../../models/pdf_colour_scheme.dart';
import '../../models/pdf_typography_config.dart';
import 'pdf_style_helpers.dart';

/// Builds a modern styled table with colored header
pw.Widget buildModernTable({
  required List<String> headers,
  required List<List<String>> rows,
  required PdfColourScheme colors,
  required PdfTypographyConfig typography,
  List<int>? columnFlex,
  bool alternatingRows = true,
}) {
  final flexList = columnFlex ?? List.filled(headers.length, 1);

  return pw.Table(
    border: pw.TableBorder.all(
      color: colors.primaryMedium,
      width: 0.5,
    ),
    columnWidths: {
      for (var i = 0; i < headers.length; i++)
        i: pw.FlexColumnWidth(flexList[i].toDouble()),
    },
    children: [
      // Header row
      pw.TableRow(
        decoration: pw.BoxDecoration(color: colors.primaryColor),
        children: headers
            .map((h) => pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  child: pw.Text(
                    h.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: typography.tableHeaderSize,
                      fontWeight: pw.FontWeight.bold,
                      color: pdfWhite,
                      letterSpacing: 0.3,
                    ),
                  ),
                ))
            .toList(),
      ),
      // Data rows
      ...rows.asMap().entries.map((entry) {
        final isAlternate = entry.key.isOdd;
        return pw.TableRow(
          decoration: pw.BoxDecoration(
            color: alternatingRows && isAlternate ? colors.primarySoft : null,
          ),
          children: entry.value
              .map((cell) => pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    child: pw.Text(
                      cell,
                      style: pw.TextStyle(
                        fontSize: typography.tableBodySize,
                        color: colors.textPrimary,
                      ),
                    ),
                  ))
              .toList(),
        );
      }),
    ],
  );
}

/// Builds a simple table without header (for repeat groups etc.)
pw.Widget buildSimpleTable({
  required List<List<String>> rows,
  required PdfColourScheme colors,
  required PdfTypographyConfig typography,
  List<int>? columnFlex,
}) {
  final numCols = rows.isNotEmpty ? rows.first.length : 0;
  final flexList = columnFlex ?? List.filled(numCols, 1);

  return pw.Table(
    border: pw.TableBorder.all(
      color: pdfLightGray,
      width: 0.5,
    ),
    columnWidths: {
      for (var i = 0; i < numCols; i++)
        i: pw.FlexColumnWidth(flexList[i].toDouble()),
    },
    children: rows.asMap().entries.map((entry) {
      final isAlternate = entry.key.isOdd;
      return pw.TableRow(
        decoration: pw.BoxDecoration(
          color: isAlternate ? colors.primarySoft : null,
        ),
        children: entry.value
            .map((cell) => pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    cell,
                    style: pw.TextStyle(
                      fontSize: typography.tableBodySize,
                      color: colors.textPrimary,
                    ),
                  ),
                ))
            .toList(),
      );
    }).toList(),
  );
}
