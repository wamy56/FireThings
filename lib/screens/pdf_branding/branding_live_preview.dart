import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../models/pdf_branding_config.dart';
import '../../models/pdf_content_block.dart';
import '../../models/pdf_header_config.dart' show PdfDocumentType;
import '../../models/pdf_layout_template.dart';
import '../../models/pdf_variable.dart';
import '../../utils/theme.dart';

/// Accurate live preview of the PDF header + body mockup + footer.
///
/// Reads actual colours, fonts, and block content from [config].
/// Renders a scaled-down representation of the PDF page.
class BrandingLivePreview extends StatelessWidget {
  final PdfBrandingConfig config;
  final PdfDocumentType docType;
  final Uint8List? logoBytes;

  const BrandingLivePreview({
    super.key,
    required this.config,
    required this.docType,
    this.logoBytes,
  });

  Color get _primary => Color(config.colourScheme.primaryColorValue);

  Color get _secondary => config.colourScheme.hasSecondary
      ? Color(config.colourScheme.secondaryColorValue!)
      : _primary;

  bool get _isSerif => config.fontConfig.family.isSerif;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppTheme.darkDivider : Colors.grey.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            _buildHeader(),
            // Body mockup
            _buildBodyMockup(),
            // Footer
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ── Header ──

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _primary, width: 2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildHeaderContent()),
          const SizedBox(width: 8),
          // Badge placeholder (like the PDF badge)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              docType == PdfDocumentType.invoice ? 'INVOICE\nINV-001' : 'JOBSHEET\nREF: 001',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 7,
                color: Colors.grey[500],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderContent() {
    switch (config.headerTemplate) {
      case HeaderLayoutTemplate.logoLeftTextRight:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (config.headerTemplate.hasLogo) ...[
              _buildLogoPreview(),
              const SizedBox(width: 8),
            ],
            Expanded(child: _renderBlockColumn(config.headerLeftBlocks)),
          ],
        );
      case HeaderLayoutTemplate.logoRightTextLeft:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _renderBlockColumn(config.headerLeftBlocks)),
            if (config.headerTemplate.hasLogo) ...[
              const SizedBox(width: 8),
              _buildLogoPreview(),
            ],
          ],
        );
      case HeaderLayoutTemplate.centeredLogoAboveText:
        return Column(
          children: [
            if (config.headerTemplate.hasLogo) ...[
              Center(child: _buildLogoPreview()),
              const SizedBox(height: 6),
            ],
            _renderBlockColumn(config.headerLeftBlocks, center: true),
          ],
        );
      case HeaderLayoutTemplate.textOnly:
        return _renderBlockColumn(config.headerLeftBlocks);
      case HeaderLayoutTemplate.twoColumn:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (config.headerTemplate.hasLogo) ...[
              _buildLogoPreview(),
              const SizedBox(width: 6),
            ],
            Expanded(child: _renderBlockColumn(config.headerLeftBlocks)),
            const SizedBox(width: 8),
            Expanded(child: _renderBlockColumn(config.headerRightBlocks)),
          ],
        );
      case HeaderLayoutTemplate.minimal:
        return _renderBlockColumn(config.headerLeftBlocks, center: true);
    }
  }

  Widget _buildLogoPreview() {
    final size = config.logoSize.pixels * 0.5;
    if (logoBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Image.memory(
          logoBytes!,
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: _primary.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Icon(
        Icons.image_outlined,
        size: size * 0.5,
        color: _primary.withValues(alpha: 0.4),
      ),
    );
  }

  Widget _renderBlockColumn(List<ContentBlock> blocks, {bool center = false}) {
    if (blocks.isEmpty) {
      return const SizedBox(height: 12);
    }
    return Column(
      crossAxisAlignment:
          center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: blocks.map((block) => _renderBlock(block, center)).toList(),
    );
  }

  Widget _renderBlock(ContentBlock block, bool parentCenter) {
    switch (block.type) {
      case ContentBlockType.text:
        final text = _resolvePreviewText(block);
        final alignment = block.alignment == TextAlignment.center || parentCenter
            ? CrossAxisAlignment.center
            : block.alignment == TextAlignment.right
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start;

        final textColor = block.colorValue != null
            ? Color(block.colorValue!)
            : (block.variable == PdfVariable.companyName ? _primary : Colors.grey[800]!);

        return Padding(
          padding: EdgeInsets.only(bottom: block.spacingAfter * 0.4),
          child: Align(
            alignment: alignment == CrossAxisAlignment.center
                ? Alignment.center
                : alignment == CrossAxisAlignment.end
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
            child: Text(
              block.uppercase ? text.toUpperCase() : text,
              style: TextStyle(
                fontSize: (block.fontSize * 0.55).clamp(5.0, 14.0),
                fontWeight: block.bold ? FontWeight.bold : FontWeight.normal,
                fontStyle: block.italic ? FontStyle.italic : FontStyle.normal,
                color: textColor,
                fontFamily: _isSerif ? 'Georgia' : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      case ContentBlockType.divider:
        return Padding(
          padding: EdgeInsets.only(bottom: block.spacingAfter * 0.4),
          child: Divider(
            height: 1,
            thickness: (block.dividerThickness ?? 1) * 0.5,
            color: block.dividerColorValue != null
                ? Color(block.dividerColorValue!)
                : _primary.withValues(alpha: 0.3),
          ),
        );
      case ContentBlockType.spacer:
        return SizedBox(height: block.spacingAfter * 0.4);
      case ContentBlockType.logo:
        return Padding(
          padding: EdgeInsets.only(bottom: block.spacingAfter * 0.4),
          child: _buildLogoPreview(),
        );
    }
  }

  String _resolvePreviewText(ContentBlock block) {
    if (block.text?.isNotEmpty == true) return block.text!;
    if (block.variable != null && block.variable != PdfVariable.custom) {
      return block.variable!.label;
    }
    return 'Text block';
  }

  // ── Body Mockup ──

  Widget _buildBodyMockup() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header mockup
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: _primary,
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(
              docType == PdfDocumentType.invoice ? 'Invoice Items' : 'Job Details',
              style: const TextStyle(
                fontSize: 7,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Table rows mockup
          _buildMockRow(true),
          _buildMockRow(false),
          _buildMockRow(true),
          const SizedBox(height: 6),
          // Secondary colour accent element
          if (config.colourScheme.hasSecondary) ...[
            Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primary, _secondary],
                ),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(height: 4),
          ],
          // More body lines
          ...List.generate(
            2,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 1.0 - i * 0.15,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMockRow(bool alternate) {
    // Tinted row using the primary colour (like actual PDF alternating rows)
    final bgColor = alternate
        ? Color.lerp(Colors.white, _primary, 0.06)!
        : Colors.white;

    return Container(
      height: 10,
      margin: const EdgeInsets.only(bottom: 1),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(
            color: _primary.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
              color: Colors.grey[300],
              height: 3,
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
              color: Colors.grey[200],
              height: 3,
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
              color: Colors.grey[200],
              height: 3,
            ),
          ),
        ],
      ),
    );
  }

  // ── Footer ──

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: _primary, width: 1),
        ),
      ),
      child: _buildFooterContent(),
    );
  }

  Widget _buildFooterContent() {
    switch (config.footerTemplate) {
      case FooterLayoutTemplate.leftTextRightPages:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: _renderBlockColumn(config.footerLeftBlocks)),
            Text(
              'Page 1 of 1',
              style: TextStyle(fontSize: 6, color: Colors.grey[500]),
            ),
          ],
        );
      case FooterLayoutTemplate.centeredTextPages:
        return Column(
          children: [
            _renderBlockColumn(config.footerLeftBlocks, center: true),
            Text(
              'Page 1 of 1',
              style: TextStyle(fontSize: 6, color: Colors.grey[500]),
            ),
          ],
        );
      case FooterLayoutTemplate.threeColumn:
        return Row(
          children: [
            Expanded(child: _renderBlockColumn(config.footerLeftBlocks)),
            Expanded(
              child: _renderBlockColumn(config.footerCentreBlocks, center: true),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Page 1 of 1',
                  style: TextStyle(fontSize: 6, color: Colors.grey[500]),
                ),
              ),
            ),
          ],
        );
      case FooterLayoutTemplate.minimal:
        return Center(
          child: Text(
            'Page 1 of 1',
            style: TextStyle(fontSize: 6, color: Colors.grey[500]),
          ),
        );
    }
  }
}
