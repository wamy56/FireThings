import 'package:flutter/material.dart';

import '../../../../models/pdf_branding.dart';
import '../../../../theme/web_theme.dart';
import 'pdf_preview_builders.dart';

class PdfPreviewQuote extends StatelessWidget {
  final PdfBranding branding;
  final BrandingDocType selectedDocType;

  const PdfPreviewQuote({
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
          defaultEyebrow: 'QUOTATION · VALID 30 DAYS',
          defaultTitle: 'Detector replacement\nprogramme',
          defaultSubtitle: 'Recommended works following quarterly inspection · Quote Q-1204',
          metaItems: const [
            (label: 'CUSTOMER', value: 'Berkeley Estates Ltd'),
            (label: 'SITE', value: 'Berkeley Square Offices'),
            (label: 'QUOTE №', value: 'Q-1204'),
            (label: 'ISSUED', value: '21 April 2026'),
            (label: 'VALID UNTIL', value: '21 May 2026'),
            (label: 'TOTAL (EXCL. VAT)', value: '£1,840.00'),
          ],
        ),
        b.buildPageHeader(metaText: 'Quote Q-1204 · 21 April 2026'),
        _buildItemsSection(b),
        b.buildFooter(
          defaultLeftText: 'Quotation Q-1204 · Valid for 30 days from issue',
          defaultPageText: 'Page 1 of 2',
        ),
      ],
    );
  }

  Widget _buildItemsSection(PdfPreviewBuilders b) {
    return Container(
      padding: const EdgeInsets.fromLTRB(56, 36, 56, 36),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE8E5DE))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          b.buildSectionHeader(
            eyebrow: 'SECTION 1 · SCOPE OF WORKS',
            title: 'Itemised quotation',
          ),
          const SizedBox(height: 20),
          _lineItemHeader(),
          _lineItem('Apollo XP95 smoke detector — replacement', '4', '£640.00'),
          _lineItem('Apollo addressable MCP — replacement (cracked cover)', '1', '£165.00'),
          _lineItem('Battery replacement — main panel loop 2', '1', '£185.00'),
          _lineItem('Engineer labour (4 hours @ £85)', '4', '£340.00'),
          _lineItem('Programming & commissioning', '1', '£510.00'),
          _totalRow('Subtotal (excl. VAT)', '£1,840.00', b.primary),
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
