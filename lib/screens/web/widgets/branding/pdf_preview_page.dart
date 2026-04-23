import 'package:flutter/material.dart';

class PdfPreviewPage extends StatelessWidget {
  final Widget child;

  const PdfPreviewPage({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 720,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(color: Color(0x1F000000), offset: Offset(0, 12), blurRadius: 40),
          BoxShadow(color: Color(0x0D000000), offset: Offset(0, 4), blurRadius: 12),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [child],
      ),
    );
  }
}
