import 'package:flutter/material.dart';

import '../../../../models/pdf_branding.dart';
import '../../../../theme/web_theme.dart';
import 'branding_doc_type_switcher.dart';
import 'pdf_preview_invoice.dart';
import 'pdf_preview_jobsheet.dart';
import 'pdf_preview_page.dart';
import 'pdf_preview_quote.dart';
import 'pdf_preview_report.dart';

class BrandingPreviewCanvas extends StatelessWidget {
  final PdfBranding branding;
  final BrandingDocType selectedDocType;
  final ValueChanged<BrandingDocType> onDocTypeChanged;

  const BrandingPreviewCanvas({
    super.key,
    required this.branding,
    required this.selectedDocType,
    required this.onDocTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: FtColors.bgSunken,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.6),
                  radius: 0.8,
                  colors: [
                    FtColors.accent.withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
            child: Column(
              children: [
                BrandingDocTypeSwitcher(
                  selectedDocType: selectedDocType,
                  onDocTypeChanged: onDocTypeChanged,
                ),
                const SizedBox(height: 12),
                _buildToolbar(),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 64),
                    child: Center(
                      child: PdfPreviewPage(
                        child: _buildPreviewForDocType(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewForDocType() {
    return switch (selectedDocType) {
      BrandingDocType.report => PdfPreviewReport(
          branding: branding, selectedDocType: selectedDocType),
      BrandingDocType.quote => PdfPreviewQuote(
          branding: branding, selectedDocType: selectedDocType),
      BrandingDocType.invoice => PdfPreviewInvoice(
          branding: branding, selectedDocType: selectedDocType),
      BrandingDocType.jobsheet => PdfPreviewJobsheet(
          branding: branding, selectedDocType: selectedDocType),
    };
  }

  // ── Toolbar ──

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: FtColors.bg,
        border: Border.all(color: FtColors.border),
        borderRadius: FtRadii.mdAll,
        boxShadow: FtShadows.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toolBtn('100%', true),
          _toolBtn('Fit', false),
          _toolBtn('75%', false),
          _divider(),
          _toolIconBtn(Icons.crop_portrait, true),
          _toolIconBtn(Icons.menu_book_outlined, false),
          _divider(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: FtColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Previewing with ',
                    style: FtText.inter(
                        size: 11, weight: FontWeight.w500, color: FtColors.fg2)),
                Text('Berkeley Square Offices',
                    style: FtText.inter(
                        size: 11, weight: FontWeight.w600, color: FtColors.fg1)),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down,
                    size: 11, color: FtColors.fg2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolBtn(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? FtColors.primary : null,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: FtText.inter(
          size: 12,
          weight: FontWeight.w600,
          color: active ? Colors.white : FtColors.fg2,
        ),
      ),
    );
  }

  Widget _toolIconBtn(IconData icon, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: active ? FtColors.primary : null,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 14, color: active ? Colors.white : FtColors.fg2),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: FtColors.border,
    );
  }
}
