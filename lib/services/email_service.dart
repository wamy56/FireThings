import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';

class EmailService {
  /// Opens the native email client with pre-filled feedback email
  /// containing device and app info for bug reports / feature requests.
  static Future<void> sendFeedback() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final deviceInfo = DeviceInfoPlugin();

    String deviceString;
    String platformName;

    if (Platform.isAndroid) {
      final info = await deviceInfo.androidInfo;
      deviceString = '${info.manufacturer} ${info.model}, Android ${info.version.release} (SDK ${info.version.sdkInt})';
      platformName = 'android';
    } else if (Platform.isIOS) {
      final info = await deviceInfo.iosInfo;
      deviceString = '${info.utsname.machine}, iOS ${info.systemVersion}';
      platformName = 'ios';
    } else if (Platform.isWindows) {
      final info = await deviceInfo.windowsInfo;
      deviceString = 'Windows ${info.majorVersion}.${info.minorVersion} (Build ${info.buildNumber})';
      platformName = 'windows';
    } else if (Platform.isMacOS) {
      final info = await deviceInfo.macOsInfo;
      deviceString = '${info.model}, macOS ${info.majorVersion}.${info.minorVersion}.${info.patchVersion}';
      platformName = 'macos';
    } else if (Platform.isLinux) {
      final info = await deviceInfo.linuxInfo;
      deviceString = info.prettyName;
      platformName = 'linux';
    } else {
      deviceString = 'Unknown';
      platformName = Platform.operatingSystem;
    }

    final body = '''Please describe the issue or feedback below:


---
App: firethings v${packageInfo.version} (${packageInfo.buildNumber})
Device: $deviceString
Platform: $platformName
''';

    final email = Email(
      body: body,
      subject: 'FireThings Feedback — v${packageInfo.version}',
      recipients: ['cscott93@hotmail.co.uk'],
      isHTML: false,
    );

    await FlutterEmailSender.send(email);
  }


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

  /// Send a quote via email with PDF attachment
  static Future<void> sendQuote({
    required String recipientEmail,
    required String recipientName,
    required String quoteNumber,
    required double total,
    required DateTime validUntil,
    required Uint8List pdfBytes,
    required String senderName,
    String? senderPhone,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/Quote_$quoteNumber.pdf';
    final file = File(filePath);
    await file.writeAsBytes(pdfBytes);

    final formattedDate = DateFormat('d MMMM yyyy').format(validUntil);
    final phoneLine =
        senderPhone != null ? ' or call us on $senderPhone' : '';

    final email = Email(
      body:
          '''Dear $recipientName,

Please find attached our quotation $quoteNumber for the value of \u00A3${total.toStringAsFixed(2)}.

This quote is valid until $formattedDate.

To accept this quote, please reply to this email$phoneLine.

Kind regards,
$senderName''',
      subject: 'Quote $quoteNumber from $senderName',
      recipients: [recipientEmail],
      attachmentPaths: [filePath],
      isHTML: false,
    );

    try {
      await FlutterEmailSender.send(email);
    } catch (e) {
      debugPrint('Error sending quote email: $e');
      rethrow;
    }
  }
}
