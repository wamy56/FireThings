import 'package:flutter/material.dart';

import '../../../../models/pdf_branding.dart';
import '../../../../theme/web_theme.dart';
import 'pdf_preview_builders.dart';

class PdfPreviewReport extends StatelessWidget {
  final PdfBranding branding;
  final String companyName;
  final BrandingDocType selectedDocType;

  const PdfPreviewReport({
    super.key,
    required this.branding,
    required this.companyName,
    required this.selectedDocType,
  });

  @override
  Widget build(BuildContext context) {
    final b = PdfPreviewBuilders(branding: branding, companyName: companyName, selectedDocType: selectedDocType);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        b.buildCover(
          defaultEyebrow: 'FIRE DETECTION & ALARM SYSTEM',
          defaultTitle: 'Annual Inspection\nCertificate',
          defaultSubtitle: 'BS 5839-1:2025 · L2 system · Service period ending April 2026',
          metaItems: const [
            (label: 'SITE', value: 'Berkeley Square Offices'),
            (label: 'ADDRESS', value: '15 Berkeley Sq, London W1J 8DU'),
            (label: 'INSPECTED', value: '21 April 2026'),
            (label: 'ENGINEER', value: 'Sarah Patel · BAFE SP203-1'),
            (label: 'CERTIFICATE №', value: 'BS-2026-04-1107'),
            (label: 'NEXT SERVICE DUE', value: '21 October 2026'),
          ],
        ),
        b.buildPageHeader(metaText: 'Cert № BS-2026-04-1107 · 21 April 2026'),
        _buildSummarySection(b),
        _buildAssetSection(b),
        b.buildFooter(
          defaultLeftText: 'BS 5839-1:2025 Annual Inspection Certificate',
          defaultPageText: 'Page 1 of 14',
        ),
      ],
    );
  }

  // ── Summary section ──

  Widget _buildSummarySection(PdfPreviewBuilders b) {
    return Container(
      padding: const EdgeInsets.fromLTRB(56, 36, 56, 36),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE8E5DE))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          b.buildSectionHeader(
            eyebrow: 'SECTION 1 · COMPLIANCE SUMMARY',
            title: 'System overview',
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE8E5DE)),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              children: [
                _summaryCell('87', 'Total assets', b.primary),
                _summaryCell('82', 'Pass', const Color(0xFF2F7D32)),
                _summaryCell('3', 'Fail', FtColors.danger),
                _summaryCell('2', 'Due', const Color(0xFFB45309)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCell(String value, String label, Color valueColour) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: Color(0xFFE8E5DE))),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: FtText.outfit(
                size: 26,
                weight: FontWeight.w800,
                color: valueColour,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: FtText.inter(
                size: 11,
                weight: FontWeight.w600,
                color: FtColors.fg2,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Asset section ──

  Widget _buildAssetSection(PdfPreviewBuilders b) {
    return Container(
      padding: const EdgeInsets.fromLTRB(56, 36, 56, 36),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE8E5DE))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          b.buildSectionHeader(
            eyebrow: 'SECTION 2 · ASSET REGISTER',
            title: 'Full asset listing',
          ),
          const SizedBox(height: 20),
          _assetHeader(),
          _assetRow('SD-001', 'Apollo XP95 smoke detector', 'Reception', 'Pass', true),
          _assetRow('SD-002', 'Apollo XP95 smoke detector', 'Stair core 1, L1', 'Pass', true),
          _assetRow('SD-004', 'Apollo XP95 smoke detector', 'Reception zone', 'Fail', false),
          _assetRow('MCP-001', 'Apollo addressable manual call point', 'Reception entrance', 'Pass', true),
        ],
      ),
    );
  }

  Widget _assetHeader() {
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
          Expanded(child: Text('DESCRIPTION', style: style)),
          SizedBox(width: 80, child: Text('LOCATION', style: style)),
          SizedBox(width: 90, child: Text('RESULT', style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _assetRow(String ref, String desc, String loc, String result, bool pass) {
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
            child: Text(desc,
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
