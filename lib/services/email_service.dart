import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:path_provider/path_provider.dart';

class EmailService {
  /// Send an invoice via email with PDF attachment
  /// Opens the default email app with the invoice attached
  static Future<void> sendInvoice({
    required String recipientEmail,
    required String invoiceNumber,
    required String customerName,
    required Uint8List pdfBytes,
    required String senderName,
  }) async {
    // Save PDF to temporary file for attachment
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/Invoice_$invoiceNumber.pdf';
    final file = File(filePath);
    await file.writeAsBytes(pdfBytes);

    final email = Email(
      body:
          '''Dear $customerName,

Please find attached invoice $invoiceNumber.

If you have any questions regarding this invoice, please don't hesitate to contact me.

Thank you for your business.

Best regards,
$senderName''',
      subject: 'Invoice $invoiceNumber',
      recipients: [recipientEmail],
      attachmentPaths: [filePath],
      isHTML: false,
    );

    try {
      await FlutterEmailSender.send(email);
    } catch (e) {
      debugPrint('Error sending email: $e');
      rethrow;
    }
  }
}
