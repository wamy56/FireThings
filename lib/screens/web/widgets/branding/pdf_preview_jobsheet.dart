import 'package:flutter/material.dart';

import '../../../../models/pdf_branding.dart';
import '../../../../theme/web_theme.dart';
import 'pdf_preview_builders.dart';

class PdfPreviewJobsheet extends StatelessWidget {
  final PdfBranding branding;
  final BrandingDocType selectedDocType;

  const PdfPreviewJobsheet({
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
          defaultEyebrow: 'JOB SHEET · CUSTOMER COPY',
          defaultTitle: 'Job completed JOB-2841',
          defaultSubtitle: 'Fire alarm reset and battery replacement · Berkeley Square Offices',
          metaItems: const [
            (label: 'SITE', value: 'Berkeley Square Offices'),
            (label: 'CUSTOMER', value: 'Berkeley Estates Ltd'),
            (label: 'JOB №', value: 'JOB-2841'),
            (label: 'ENGINEER', value: 'Dan Miller'),
            (label: 'STARTED', value: '21 April · 10:44'),
            (label: 'COMPLETED', value: '21 April · 12:18'),
          ],
        ),
        b.buildPageHeader(metaText: 'Job JOB-2841 · 21 April 2026'),
        _buildWorkSection(b),
        b.buildFooter(
          defaultLeftText: 'Job sheet JOB-2841 · Customer signature on Page 2',
          defaultPageText: 'Page 1 of 2',
        ),
      ],
    );
  }

  Widget _buildWorkSection(PdfPreviewBuilders b) {
    return Container(
      padding: const EdgeInsets.fromLTRB(56, 36, 56, 36),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE8E5DE))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          b.buildSectionHeader(
            eyebrow: 'SECTION 1 · WORK PERFORMED',
            title: 'Visit summary',
          ),
          const SizedBox(height: 16),
          Text(
            'Attended site following customer report of intermittent sounder '
            'activation in reception. Investigation found contamination on '
            'detectors SD-004 and adjacent units. Cleaned detectors, replaced '
            'battery on main panel loop 2, tested system end-to-end. All zones '
            'now operating normally. Recommend full detector replacement '
            'programme — quote Q-1204 issued.',
            style: FtText.inter(
              size: 13,
              weight: FontWeight.w400,
              color: FtColors.fg1,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          _workHeader(),
          _workRow('SD-004', 'Cleaned', 'Reception', 'Pass', true),
          _workRow('BAT-L2', 'Replaced', 'Main panel', 'Pass', true),
          _workRow('PAN-01', 'Reset & tested', 'Reception', 'Pass', true),
        ],
      ),
    );
  }

  Widget _workHeader() {
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
          SizedBox(width: 70, child: Text('REF', style: style)),
          Expanded(child: Text('ACTION', style: style)),
          SizedBox(width: 80, child: Text('LOCATION', style: style)),
          SizedBox(width: 90, child: Text('RESULT', style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _workRow(String ref, String action, String loc, String result, bool pass) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: FtColors.bgSunken)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(ref,
                style: FtText.mono(size: 12, weight: FontWeight.w500, color: FtColors.fg2)),
          ),
          Expanded(
            child: Text(action,
                style: FtText.inter(size: 13, weight: FontWeight.w500, color: FtColors.fg1)),
          ),
          SizedBox(
            width: 80,
            child: Text(loc, style: FtText.inter(size: 12, color: FtColors.fg2)),
          ),
          SizedBox(
            width: 90,
            child: Text(
              result,
              style: FtText.inter(
                size: 13,
                weight: FontWeight.w600,
                color: pass ? const Color(0xFF2F7D32) : FtColors.danger,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
