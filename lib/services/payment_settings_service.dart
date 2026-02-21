import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage user payment details and invoice settings that persist across sessions
class PaymentSettingsService {
  static const _keyBankName = 'payment_bank_name';
  static const _keyAccountName = 'payment_account_name';
  static const _keySortCode = 'payment_sort_code';
  static const _keyAccountNumber = 'payment_account_number';
  static const _keyPaymentTerms = 'payment_terms';
  static const _keyLastInvoiceNumber = 'last_invoice_number';
  static const _keyEngineerName = 'engineer_name';

  /// Get payment details for the current user
  static Future<PaymentDetails> getPaymentDetails() async {
    final prefs = await SharedPreferences.getInstance();
    return PaymentDetails(
      bankName: prefs.getString(_keyBankName) ?? '',
      accountName: prefs.getString(_keyAccountName) ?? '',
      sortCode: prefs.getString(_keySortCode) ?? '',
      accountNumber: prefs.getString(_keyAccountNumber) ?? '',
      paymentTerms: prefs.getString(_keyPaymentTerms) ?? 'Payment is due within 30 days of the invoice date.',
    );
  }

  /// Save payment details
  static Future<void> savePaymentDetails(PaymentDetails details) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBankName, details.bankName);
    await prefs.setString(_keyAccountName, details.accountName);
    await prefs.setString(_keySortCode, details.sortCode);
    await prefs.setString(_keyAccountNumber, details.accountNumber);
    await prefs.setString(_keyPaymentTerms, details.paymentTerms);
  }

  /// Check if payment details have been set up
  static Future<bool> hasPaymentDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final accountName = prefs.getString(_keyAccountName);
    return accountName != null && accountName.isNotEmpty;
  }

  /// Get the last used invoice number
  static Future<String?> getLastInvoiceNumber() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastInvoiceNumber);
  }

  /// Save the last used invoice number
  static Future<void> saveLastInvoiceNumber(String invoiceNumber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastInvoiceNumber, invoiceNumber);
  }

  /// Get the saved engineer name
  static Future<String?> getEngineerName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyEngineerName);
  }

  /// Save the engineer name
  static Future<void> saveEngineerName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEngineerName, name);
  }

  /// Increment invoice number and return the new one
  static String incrementInvoiceNumber(String currentNumber) {
    // Try to parse the number part
    final regex = RegExp(r'(\d+)$');
    final match = regex.firstMatch(currentNumber);

    if (match != null) {
      final numberPart = match.group(1)!;
      final prefix = currentNumber.substring(0, match.start);
      final newNumber = int.parse(numberPart) + 1;
      final paddedNumber = newNumber.toString().padLeft(numberPart.length, '0');
      return '$prefix$paddedNumber';
    }

    // If no number found, just append 1
    return '${currentNumber}1';
  }
}

/// Model class for payment details
class PaymentDetails {
  final String bankName;
  final String accountName;
  final String sortCode;
  final String accountNumber;
  final String paymentTerms;

  PaymentDetails({
    required this.bankName,
    required this.accountName,
    required this.sortCode,
    required this.accountNumber,
    required this.paymentTerms,
  });

  bool get isEmpty => bankName.isEmpty && accountName.isEmpty && sortCode.isEmpty && accountNumber.isEmpty;
}
