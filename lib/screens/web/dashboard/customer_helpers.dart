import 'package:intl/intl.dart';
import '../../../models/company_customer.dart';

String generateCustomersCsv(
    List<CompanyCustomer> customers, Map<String, bool> columnVisibility) {
  final buffer = StringBuffer();
  final dateTimeFmt = DateFormat('yyyy-MM-dd HH:mm');

  final columnDefs = <String, String>{
    'name': 'Name',
    'address': 'Address',
    'email': 'Email',
    'phone': 'Phone',
    'notes': 'Notes',
    'createdAt': 'Created',
  };

  final visibleKeys =
      columnDefs.keys.where((k) => columnVisibility[k] == true).toList();

  buffer.writeln(visibleKeys.map((k) => columnDefs[k] ?? k).map(_escapeCsv).join(','));

  for (final c in customers) {
    final values = visibleKeys.map((key) {
      switch (key) {
        case 'name':
          return c.name;
        case 'address':
          return c.address ?? '';
        case 'email':
          return c.email ?? '';
        case 'phone':
          return c.phone ?? '';
        case 'notes':
          return c.notes ?? '';
        case 'createdAt':
          return dateTimeFmt.format(c.createdAt);
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
