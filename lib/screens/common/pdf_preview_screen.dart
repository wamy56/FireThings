import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../utils/icon_map.dart';
import '../../widgets/adaptive_app_bar.dart';

/// Full-screen PDF preview with Print and Share actions in the app bar.
class PdfPreviewScreen extends StatelessWidget {
  final Uint8List pdfBytes;
  final String title;
  final String fileName;

  const PdfPreviewScreen({
    super.key,
    required this.pdfBytes,
    required this.title,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdaptiveNavigationBar(
        title: title,
        actions: [
          IconButton(
            icon: Icon(AppIcons.printer),
            onPressed: () => Printing.layoutPdf(onLayout: (_) => pdfBytes),
            tooltip: 'Print',
          ),
          IconButton(
            icon: Icon(AppIcons.share),
            onPressed: () => Printing.sharePdf(bytes: pdfBytes, filename: fileName),
            tooltip: 'Share',
          ),
        ],
      ),
      body: PdfPreview(
        build: (_) => pdfBytes,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        allowPrinting: false,
        allowSharing: false,
        pdfFileName: fileName,
      ),
    );
  }
}
