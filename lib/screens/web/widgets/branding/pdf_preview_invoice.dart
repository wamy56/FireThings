import 'package:flutter/material.dart';

import '../../../../models/pdf_branding.dart';
import '../../../../theme/web_theme.dart';
import 'pdf_preview_builders.dart';

class PdfPreviewInvoice extends StatelessWidget {
  final PdfBranding branding;
  final BrandingDocType selectedDocType;

  const PdfPreviewInvoice({
    super.key,
    required this.branding,
    required this.selectedDocType,
  });

  @override
  Widget build(BuildContext context) {
    final b = PdfPreviewBuilders(branding: branding, selectedDocType: selectedDocType);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        b.buildCover(
          defaultEyebrow: 'INVOICE · PAYMENT DUE 30 DAYS',
          defaultTitle: 'Invoice INV-2841',
          defaultSubtitle: 'Emergency callout — Berkeley Square Offices · 21 April 2026',
          metaItems: const [
            (label: 'BILL TO', value: 'Berkeley Estates Ltd'),
            (label: 'SITE', value: 'Berkeley Square Offices'),
            (label: 'INVOICE №', value: 'INV-2841'),
            (label: 'ISSUED', value: '21 April 2026'),
            (label: 'DUE DATE', value: '21 May 2026'),
            (label: 'TOTAL DUE', value: '£492.00'),
          ],
        ),
        b.buildPageHeader(metaText: 'Invoice INV-2841 · 21 April 2026'),
        _buildChargesSection(b),
        b.buildFooter(
          defaultLeftText: 'FireThings Demo Co. · Co. № 09238456 · VAT GB 234 5678 90',
          defaultPageText: 'Page 1 of 1',
        ),
      ],
    );
  }

  Widget _buildChargesSection(PdfPreviewBuilders b) {
    return Container(
      padding: const EdgeInsets.fromLTRB(56, 36, 56, 36),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE8E5DE))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          b.buildSectionHeader(
            eyebrow: 'SECTION 1 · CHARGES',
            title: 'Work completed',
          ),
          const SizedBox(height: 20),
          _lineItemHeader(),
          _lineItem('Emergency callout — fire alarm reset', '1', '£175.00'),
          _lineItem('Engineer labour (1.5 hours @ £85)', '1.5', '£127.50'),
          _lineItem('Battery replacement — main panel', '1', '£87.50'),
          _subtotalRow('Subtotal (excl. VAT)', '£390.00'),
          _subtotalRow('VAT @ 20%', '£78.00'),
          _totalRow('Total due', '£468.00', b.primary),
        ],
      ),
    );
  }

  Widget _lineItemHeader() {
    final style = FtText.inter(
      size: 10,
      weight: FontWeight.w700,
      color: FtColors.fg2,
      letterSpacing: 0.4,
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE8E5DE), width: 2)),
      ),
      child: Row(
        children: [
          Expanded(child: Text('DESCRIPTION', style: style)),
          SizedBox(width: 40, child: Text('QTY', style: style)),
          SizedBox(width: 90, child: Text('TOTAL', style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _lineItem(String desc, String qty, String total) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: FtColors.bgSunken)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(desc, style: FtText.inter(size: 13, weight: FontWeight.w500, color: FtColors.fg1)),
          ),
          SizedBox(
            width: 40,
            child: Text(qty, style: FtText.inter(size: 13, color: FtColors.fg2)),
          ),
          SizedBox(
            width: 90,
            child: Text(total,
                style: FtText.inter(size: 13, weight: FontWeight.w600, color: FtColors.fg1),
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _subtotalRow(String label, String total) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: FtColors.bgSunken)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: FtText.inter(size: 13, weight: FontWeight.w500, color: FtColors.fg2)),
          ),
          const SizedBox(width: 40),
          SizedBox(
            width: 90,
            child: Text(total,
                style: FtText.inter(size: 13, weight: FontWeight.w500, color: FtColors.fg1),
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, String total, Color colour) {
    return Container(
      padding: const EdgeInsets.only(top: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE8E5DE), width: 2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: FtText.inter(size: 13, weight: FontWeight.w700, color: colour)),
          ),
          const SizedBox(width: 40),
          SizedBox(
            width: 90,
            child: Text(total,
                style: FtText.inter(size: 13, weight: FontWeight.w700, color: colour),
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}
