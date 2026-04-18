import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/quote.dart';
import '../../../utils/theme.dart';

Color quoteStatusColor(QuoteStatus status) {
  switch (status) {
    case QuoteStatus.draft:
      return AppTheme.mediumGrey;
    case QuoteStatus.sent:
      return Colors.blue;
    case QuoteStatus.approved:
      return AppTheme.successGreen;
    case QuoteStatus.declined:
      return AppTheme.errorRed;
    case QuoteStatus.converted:
      return Colors.purple;
  }
}

String quoteStatusLabel(QuoteStatus status) {
  switch (status) {
    case QuoteStatus.draft:
      return 'Draft';
    case QuoteStatus.sent:
      return 'Sent';
    case QuoteStatus.approved:
      return 'Approved';
    case QuoteStatus.declined:
      return 'Declined';
    case QuoteStatus.converted:
      return 'Converted';
  }
}

Widget quoteStatusBadge(QuoteStatus status) {
  final color = quoteStatusColor(status);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      quoteStatusLabel(status),
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
    ),
  );
}

String generateQuotesCsv(
    List<Quote> quotes, Map<String, bool> columnVisibility) {
  final buffer = StringBuffer();
  final dateFmt = DateFormat('yyyy-MM-dd');
  final dateTimeFmt = DateFormat('yyyy-MM-dd HH:mm');
  final currencyFmt = NumberFormat.currency(symbol: '\u00A3', decimalDigits: 2);

  final columnDefs = <String, String>{
    'quoteNumber': 'Quote #',
    'customer': 'Customer',
    'site': 'Site',
    'engineer': 'Engineer',
    'status': 'Status',
    'total': 'Total',
    'validUntil': 'Valid Until',
    'createdAt': 'Created',
  };

  final extraColumns = <String, String>{
    'customerAddress': 'Customer Address',
    'customerEmail': 'Customer Email',
    'defectDescription': 'Defect',
    'notes': 'Notes',
  };

  final visibleKeys =
      columnDefs.keys.where((k) => columnVisibility[k] == true).toList();
  final allKeys = [...visibleKeys, ...extraColumns.keys];
  final allHeaders =
      allKeys.map((k) => columnDefs[k] ?? extraColumns[k] ?? k).toList();

  buffer.writeln(allHeaders.map(_escapeCsv).join(','));

  for (final q in quotes) {
    final values = allKeys.map((key) {
      switch (key) {
        case 'quoteNumber':
          return q.quoteNumber;
        case 'customer':
          return q.customerName;
        case 'customerAddress':
          return q.customerAddress;
        case 'customerEmail':
          return q.customerEmail ?? '';
        case 'site':
          return q.siteName;
        case 'engineer':
          return q.engineerName;
        case 'status':
          return quoteStatusLabel(q.status);
        case 'total':
          return currencyFmt.format(q.total);
        case 'validUntil':
          return dateFmt.format(q.validUntil);
        case 'createdAt':
          return dateTimeFmt.format(q.createdAt);
        case 'defectDescription':
          return q.defectDescription ?? '';
        case 'notes':
          return q.notes ?? '';
        default:
          return '';
      }
    }).toList();
    buffer.writeln(values.map(_escapeCsv).join(','));
  }

  return buffer.toString();
}

String _escapeCsv(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}
