import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/invoice.dart';
import '../../../theme/web_theme.dart';

Color invoiceStatusColor(InvoiceStatus status) {
  switch (status) {
    case InvoiceStatus.draft:
      return FtColors.hint;
    case InvoiceStatus.sent:
      return FtColors.info;
    case InvoiceStatus.paid:
      return FtColors.success;
  }
}

Color invoiceStatusSoftColor(InvoiceStatus status) {
  switch (status) {
    case InvoiceStatus.draft:
      return FtColors.bgSunken;
    case InvoiceStatus.sent:
      return FtColors.infoSoft;
    case InvoiceStatus.paid:
      return FtColors.successSoft;
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
  final softColor = invoiceStatusSoftColor(status);
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
          invoiceStatusLabel(status),
          style: FtText.inter(size: 12, weight: FontWeight.w600, color: color),
        ),
      ],
    ),
  );
}

String generateInvoicesCsv(
    List<Invoice> invoices, Map<String, bool> columnVisibility) {
  final buffer = StringBuffer();
  final dateFmt = DateFormat('yyyy-MM-dd');
  final dateTimeFmt = DateFormat('yyyy-MM-dd HH:mm');
  final currencyFmt = NumberFormat.currency(symbol: '£', decimalDigits: 2);

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
