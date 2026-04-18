import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/invoice.dart';
import '../../../utils/theme.dart';

Color invoiceStatusColor(InvoiceStatus status) {
  switch (status) {
    case InvoiceStatus.draft:
      return AppTheme.mediumGrey;
    case InvoiceStatus.sent:
      return Colors.blue;
    case InvoiceStatus.paid:
      return AppTheme.successGreen;
  }
}

String invoiceStatusLabel(InvoiceStatus status) {
  switch (status) {
    case InvoiceStatus.draft:
      return 'Draft';
    case InvoiceStatus.sent:
      return 'Sent';
    case InvoiceStatus.paid:
      return 'Paid';
  }
}

Widget invoiceStatusBadge(InvoiceStatus status) {
  final color = invoiceStatusColor(status);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      invoiceStatusLabel(status),
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
    ),
  );
}

String generateInvoicesCsv(
    List<Invoice> invoices, Map<String, bool> columnVisibility) {
  final buffer = StringBuffer();
  final dateFmt = DateFormat('yyyy-MM-dd');
  final dateTimeFmt = DateFormat('yyyy-MM-dd HH:mm');
  final currencyFmt = NumberFormat.currency(symbol: '\u00A3', decimalDigits: 2);

  final columnDefs = <String, String>{
    'invoiceNumber': 'Invoice #',
    'customer': 'Customer',
    'engineer': 'Engineer',
    'status': 'Status',
    'total': 'Total',
    'date': 'Date',
    'dueDate': 'Due Date',
    'createdAt': 'Created',
  };

  final extraColumns = <String, String>{
    'customerAddress': 'Customer Address',
    'customerEmail': 'Customer Email',
    'subtotal': 'Subtotal',
    'vat': 'VAT',
    'notes': 'Notes',
  };

  final visibleKeys =
      columnDefs.keys.where((k) => columnVisibility[k] == true).toList();
  final allKeys = [...visibleKeys, ...extraColumns.keys];
  final allHeaders =
      allKeys.map((k) => columnDefs[k] ?? extraColumns[k] ?? k).toList();

  buffer.writeln(allHeaders.map(_escapeCsv).join(','));

  for (final inv in invoices) {
    final values = allKeys.map((key) {
      switch (key) {
        case 'invoiceNumber':
          return inv.invoiceNumber;
        case 'customer':
          return inv.customerName;
        case 'customerAddress':
          return inv.customerAddress;
        case 'customerEmail':
          return inv.customerEmail ?? '';
        case 'engineer':
          return inv.engineerName;
        case 'status':
          return invoiceStatusLabel(inv.status);
        case 'total':
          return currencyFmt.format(inv.total);
        case 'subtotal':
          return currencyFmt.format(inv.subtotal);
        case 'vat':
          return currencyFmt.format(inv.tax);
        case 'date':
          return dateFmt.format(inv.date);
        case 'dueDate':
          return dateFmt.format(inv.dueDate);
        case 'createdAt':
          return dateTimeFmt.format(inv.createdAt);
        case 'notes':
          return inv.notes ?? '';
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
