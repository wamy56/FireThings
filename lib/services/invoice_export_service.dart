import 'dart:io';
import 'dart:ui';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/invoice.dart';

class InvoiceExportService {
  /// Returns invoices falling within a specific UK tax year.
  /// UK tax year runs 6 Apr – 5 Apr.
  /// [endYear] is the year the tax year ends in.
  /// E.g. endYear=2025 → 6 Apr 2024 – 5 Apr 2025.
  static List<Invoice> getInvoicesForTaxYear(List<Invoice> invoices, int endYear) {
    final start = DateTime(endYear - 1, 4, 6); // 6 Apr start-year
    final end = DateTime(endYear, 4, 5, 23, 59, 59); // 5 Apr end-year

    return invoices
        .where((inv) =>
            !inv.date.isBefore(start) && !inv.date.isAfter(end))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Returns a sorted list of tax year end-years that contain at least one invoice.
  /// E.g. if invoices span 2023–2025, returns [2024, 2025, 2026].
  static List<int> getAvailableTaxYears(List<Invoice> invoices) {
    final years = <int>{};
    for (final inv in invoices) {
      // If the invoice date is before 6 Apr, it belongs to the tax year
      // ending in that calendar year; otherwise the tax year ending next year.
      final d = inv.date;
      final endYear = (d.month < 4 || (d.month == 4 && d.day <= 5))
          ? d.year
          : d.year + 1;
      years.add(endYear);
    }
    final sorted = years.toList()..sort();
    return sorted;
  }

  /// Generates a CSV string from a list of invoices.
  static String generateCsv(List<Invoice> invoices) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final buf = StringBuffer();

    buf.writeln(
      'Invoice Number,Customer,Date,Due Date,Subtotal,VAT,Total,Status',
    );

    for (final inv in invoices) {
      buf.writeln([
        _escapeCsv(inv.invoiceNumber),
        _escapeCsv(inv.customerName),
        dateFormat.format(inv.date),
        dateFormat.format(inv.dueDate),
        inv.subtotal.toStringAsFixed(2),
        inv.tax.toStringAsFixed(2),
        inv.total.toStringAsFixed(2),
        inv.status.name,
      ].join(','));
    }

    return buf.toString();
  }

  /// Writes CSV to a temp file and opens the platform share sheet.
  /// [endYear] is the tax year end-year to export.
  static Future<void> exportAndShare(
    List<Invoice> invoices,
    int endYear, {
    Rect? sharePositionOrigin,
  }) async {
    final filtered = getInvoicesForTaxYear(invoices, endYear);
    final csv = generateCsv(filtered);
    final dir = await getTemporaryDirectory();

    final fileName = 'paid_invoices_${endYear - 1}_$endYear.csv';

    final file = File('${dir.path}/$fileName');
    await file.writeAsString(csv);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Paid Invoices ${endYear - 1}/$endYear',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  static String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
