import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/quote.dart';
import '../../../theme/web_theme.dart';

Color quoteStatusColor(QuoteStatus status) {
  switch (status) {
    case QuoteStatus.draft:
      return FtColors.hint;
    case QuoteStatus.sent:
      return FtColors.info;
    case QuoteStatus.approved:
      return FtColors.success;
    case QuoteStatus.declined:
      return FtColors.danger;
    case QuoteStatus.converted:
      return FtColors.primary;
  }
}

Color quoteStatusSoftColor(QuoteStatus status) {
  switch (status) {
    case QuoteStatus.draft:
      return FtColors.bgSunken;
    case QuoteStatus.sent:
      return FtColors.infoSoft;
    case QuoteStatus.approved:
      return FtColors.successSoft;
    case QuoteStatus.declined:
      return FtColors.dangerSoft;
    case QuoteStatus.converted:
      return const Color(0xFFE8E8F0);
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
  final softColor = quoteStatusSoftColor(status);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
    decoration: BoxDecoration(
      color: softColor,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          quoteStatusLabel(status),
          style: FtText.inter(size: 12, weight: FontWeight.w600, color: color),
        ),
      ],
    ),
  );
}

String generateQuotesCsv(
    List<Quote> quotes, Map<String, bool> columnVisibility) {
  final buffer = StringBuffer();
  final dateFmt = DateFormat('yyyy-MM-dd');
  final dateTimeFmt = DateFormat('yyyy-MM-dd HH:mm');
  final currencyFmt = NumberFormat.currency(symbol: '£', decimalDigits: 2);

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
