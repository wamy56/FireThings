import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/pdf_branding_config.dart';
import '../models/pdf_colour_scheme_v2.dart';
import '../models/pdf_content_block.dart';
import '../models/pdf_layout_template.dart';
import '../models/pdf_variable.dart';

/// Builds PDF header and footer widgets from a [PdfBrandingConfig].
///
/// Replaces [PdfHeaderBuilder] and [PdfFooterBuilder] with a unified,
/// template-aware builder that supports content blocks, dynamic variables,
/// and the extended colour scheme.
class PdfBrandingBuilder {
  static const PdfColor _darkGray = PdfColor.fromInt(0xFF424242);

  // ── Header ──

  /// Build the header widget from a [PdfBrandingConfig].
  static pw.Widget buildHeader({
    required PdfBrandingConfig config,
    required PdfVariableResolver resolver,
    Uint8List? logoBytes,
    pw.Font? font,
    pw.Font? boldFont,
    pw.Font? italicFont,
    pw.Font? boldItalicFont,
  }) {
    final scheme = config.colourScheme;

    return switch (config.headerTemplate) {
      HeaderLayoutTemplate.logoLeftTextRight => _buildLogoSideTextSide(
          config: config,
          resolver: resolver,
          logoBytes: logoBytes,
          scheme: scheme,
          logoOnLeft: true,
          font: font,
          boldFont: boldFont,
          italicFont: italicFont,
          boldItalicFont: boldItalicFont,
        ),
      HeaderLayoutTemplate.logoRightTextLeft => _buildLogoSideTextSide(
          config: config,
          resolver: resolver,
          logoBytes: logoBytes,
          scheme: scheme,
          logoOnLeft: false,
          font: font,
          boldFont: boldFont,
          italicFont: italicFont,
          boldItalicFont: boldItalicFont,
        ),
      HeaderLayoutTemplate.centeredLogoAboveText => _buildCenteredLogoAbove(
          config: config,
          resolver: resolver,
          logoBytes: logoBytes,
          scheme: scheme,
          font: font,
          boldFont: boldFont,
          italicFont: italicFont,
          boldItalicFont: boldItalicFont,
        ),
      HeaderLayoutTemplate.textOnly => _buildTextOnlyHeader(
          config: config,
          resolver: resolver,
          scheme: scheme,
          font: font,
          boldFont: boldFont,
          italicFont: italicFont,
          boldItalicFont: boldItalicFont,
        ),
      HeaderLayoutTemplate.twoColumn => _buildTwoColumnHeader(
          config: config,
          resolver: resolver,
          logoBytes: logoBytes,
          scheme: scheme,
          font: font,
          boldFont: boldFont,
          italicFont: italicFont,
          boldItalicFont: boldItalicFont,
        ),
      HeaderLayoutTemplate.minimal => _buildMinimalHeader(
          config: config,
          resolver: resolver,
          scheme: scheme,
          font: font,
          boldFont: boldFont,
          italicFont: italicFont,
          boldItalicFont: boldItalicFont,
        ),
    };
  }

  // ── Footer ──

  /// Build the footer widget from a [PdfBrandingConfig].
  static pw.Widget buildFooter({
    required PdfBrandingConfig config,
    required PdfVariableResolver resolver,
    required int pageNumber,
    required int pagesCount,
    pw.Font? font,
    pw.Font? boldFont,
    pw.Font? italicFont,
    pw.Font? boldItalicFont,
  }) {
    final scheme = config.colourScheme;
    final pageResolver = PdfVariableResolver({
      ...resolver.context,
      '{page}': '$pageNumber',
      '{pages}': '$pagesCount',
    });

    final content = switch (config.footerTemplate) {
      FooterLayoutTemplate.leftTextRightPages => _buildLeftTextRightPagesFooter(
          config: config,
          resolver: pageResolver,
          scheme: scheme,
          pageNumber: pageNumber,
          pagesCount: pagesCount,
          font: font,
          boldFont: boldFont,
          italicFont: italicFont,
          boldItalicFont: boldItalicFont,
        ),
      FooterLayoutTemplate.centeredTextPages => _buildCenteredFooter(
          config: config,
          resolver: pageResolver,
          scheme: scheme,
          pageNumber: pageNumber,
          pagesCount: pagesCount,
          font: font,
          boldFont: boldFont,
          italicFont: italicFont,
          boldItalicFont: boldItalicFont,
        ),
      FooterLayoutTemplate.threeColumn => _buildThreeColumnFooter(
          config: config,
          resolver: pageResolver,
          scheme: scheme,
          pageNumber: pageNumber,
          pagesCount: pagesCount,
          font: font,
          boldFont: boldFont,
          italicFont: italicFont,
          boldItalicFont: boldItalicFont,
        ),
      FooterLayoutTemplate.minimal => _buildMinimalFooter(
          scheme: scheme,
          pageNumber: pageNumber,
          pagesCount: pagesCount,
          font: font,
        ),
    };

    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: scheme.primaryColor, width: 2),
        ),
      ),
      child: content,
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  HEADER TEMPLATES
  // ══════════════════════════════════════════════════════════════════════

  /// Logo on one side, text blocks on the other (the classic layout).
  static pw.Widget _buildLogoSideTextSide({
    required PdfBrandingConfig config,
    required PdfVariableResolver resolver,
    required PdfColourSchemeV2 scheme,
    Uint8List? logoBytes,
    required bool logoOnLeft,
    pw.Font? font,
    pw.Font? boldFont,
    pw.Font? italicFont,
    pw.Font? boldItalicFont,
  }) {
    final logoWidget = _buildLogoWidget(logoBytes, config.logoSize.pixels);
    final textWidgets = _renderBlocks(
      config.headerLeftBlocks,
      resolver,
      scheme,
      font: font,
      boldFont: boldFont,
      italicFont: italicFont,
      boldItalicFont: boldItalicFont,
    );

    final leftChildren = <pw.Widget>[];
    final centreChildren = <pw.Widget>[];

    if (logoOnLeft && logoWidget != null) {
      leftChildren.add(logoWidget);
      leftChildren.add(pw.SizedBox(width: 10));
    }

    if (textWidgets.isNotEmpty) {
      leftChildren.add(
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: textWidgets,
          ),
        ),
      );
    } else if (leftChildren.isEmpty) {
      leftChildren.add(pw.Expanded(child: pw.SizedBox()));
    }

    if (!logoOnLeft && logoWidget != null) {
      // Logo goes in centre zone for "logo right" layout
      centreChildren.add(logoWidget);
    }

    // Centre zone blocks (if any)
    final centreBlocks = _renderBlocks(
      config.headerCentreBlocks,
      resolver,
      scheme,
      font: font,
      boldFont: boldFont,
      italicFont: italicFont,
      boldItalicFont: boldItalicFont,
    );
    if (centreBlocks.isNotEmpty) {
      centreChildren.add(
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: centreBlocks,
          ),
        ),
      );
    }

    final children = <pw.Widget>[
      pw.Expanded(
        flex: 3,
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: leftChildren,
        ),
      ),
    ];

    if (centreChildren.isNotEmpty) {
      children.add(pw.SizedBox(width: 12));
      children.add(
        pw.Expanded(
          flex: 2,
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: centreChildren,
          ),
        ),
      );
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: children,
    );
  }

  /// Logo centered above centered text.
  static pw.Widget _buildCenteredLogoAbove({
    required PdfBrandingConfig config,
    required PdfVariableResolver resolver,
    required PdfColourSchemeV2 scheme,
    Uint8List? logoBytes,
    pw.Font? font,
    pw.Font? boldFont,
    pw.Font? italicFont,
    pw.Font? boldItalicFont,
  }) {
    final children = <pw.Widget>[];

    final logoWidget = _buildLogoWidget(logoBytes, config.logoSize.pixels);
    if (logoWidget != null) {
      children.add(pw.Center(child: logoWidget));
      children.add(pw.SizedBox(height: 6));
    }

    final textWidgets = _renderBlocks(
      config.headerLeftBlocks,
      resolver,
      scheme,
      font: font,
      boldFont: boldFont,
      italicFont: italicFont,
      boldItalicFont: boldItalicFont,
    );
    children.addAll(textWidgets);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: children,
    );
  }

  /// Full-width text only (no logo zone).
  static pw.Widget _buildTextOnlyHeader({
    required PdfBrandingConfig config,
    required PdfVariableResolver resolver,
    required PdfColourSchemeV2 scheme,
    pw.Font? font,
    pw.Font? boldFont,
    pw.Font? italicFont,
    pw.Font? boldItalicFont,
  }) {
    final textWidgets = _renderBlocks(
      config.headerLeftBlocks,
      resolver,
      scheme,
      font: font,
      boldFont: boldFont,
      italicFont: italicFont,
      boldItalicFont: boldItalicFont,
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: textWidgets,
    );
  }

  /// Two-column layout: left blocks + right blocks.
  static pw.Widget _buildTwoColumnHeader({
    required PdfBrandingConfig config,
    required PdfVariableResolver resolver,
    required PdfColourSchemeV2 scheme,
    Uint8List? logoBytes,
    pw.Font? font,
    pw.Font? boldFont,
    pw.Font? italicFont,
    pw.Font? boldItalicFont,
  }) {
    final leftWidgets = <pw.Widget>[];

    final logoWidget = _buildLogoWidget(logoBytes, config.logoSize.pixels);
    if (logoWidget != null) {
      leftWidgets.add(logoWidget);
      leftWidgets.add(pw.SizedBox(height: 4));
    }

    leftWidgets.addAll(_renderBlocks(
      config.headerLeftBlocks,
      resolver,
      scheme,
      font: font,
      boldFont: boldFont,
      italicFont: italicFont,
      boldItalicFont: boldItalicFont,
    ));

    final rightWidgets = _renderBlocks(
      config.headerRightBlocks,
      resolver,
      scheme,
      font: font,
      boldFont: boldFont,
      italicFont: italicFont,
      boldItalicFont: boldItalicFont,
    );

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 3,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: leftWidgets,
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          flex: 2,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: rightWidgets,
          ),
        ),
      ],
    );
  }

  /// Minimal header: single centered company name line.
  static pw.Widget _buildMinimalHeader({
    required PdfBrandingConfig config,
    required PdfVariableResolver resolver,
    required PdfColourSchemeV2 scheme,
    pw.Font? font,
    pw.Font? boldFont,
    pw.Font? italicFont,
    pw.Font? boldItalicFont,
  }) {
    final textWidgets = _renderBlocks(
      config.headerLeftBlocks,
      resolver,
      scheme,
      font: font,
      boldFont: boldFont,
      italicFont: italicFont,
      boldItalicFont: boldItalicFont,
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: textWidgets.isEmpty
          ? [pw.SizedBox(height: 4)]
          : textWidgets,
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  FOOTER TEMPLATES
  // ══════════════════════════════════════════════════════════════════════

  /// Text left, page numbers right (the classic layout).
  static pw.Widget _buildLeftTextRightPagesFooter({
    required PdfBrandingConfig config,
    required PdfVariableResolver resolver,
    required PdfColourSchemeV2 scheme,
    required int pageNumber,
    required int pagesCount,
    pw.Font? font,
    pw.Font? boldFont,
    pw.Font? italicFont,
    pw.Font? boldItalicFont,
  }) {
    final leftWidgets = _renderBlocks(
      config.footerLeftBlocks,
      resolver,
      scheme,
      font: font,
      boldFont: boldFont,
      italicFont: italicFont,
      boldItalicFont: boldItalicFont,
    );

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 3,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: leftWidgets,
          ),
        ),
        pw.Text(
          'Page $pageNumber of $pagesCount',
          style: pw.TextStyle(fontSize: 8, color: _darkGray, font: font),
        ),
      ],
    );
  }

  /// Centered text with page numbers below.
  static pw.Widget _buildCenteredFooter({
    required PdfBrandingConfig config,
    required PdfVariableResolver resolver,
    required PdfColourSchemeV2 scheme,
    required int pageNumber,
    required int pagesCount,
    pw.Font? font,
    pw.Font? boldFont,
    pw.Font? italicFont,
    pw.Font? boldItalicFont,
  }) {
    final centreWidgets = _renderBlocks(
      config.footerLeftBlocks,
      resolver,
      scheme,
      font: font,
      boldFont: boldFont,
      italicFont: italicFont,
      boldItalicFont: boldItalicFont,
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        ...centreWidgets,
        pw.SizedBox(height: 2),
        pw.Text(
          'Page $pageNumber of $pagesCount',
          style: pw.TextStyle(fontSize: 8, color: _darkGray, font: font),
        ),
      ],
    );
  }

  /// Three-column footer: left, centre, right (with page numbers in right).
  static pw.Widget _buildThreeColumnFooter({
    required PdfBrandingConfig config,
    required PdfVariableResolver resolver,
    required PdfColourSchemeV2 scheme,
    required int pageNumber,
    required int pagesCount,
    pw.Font? font,
    pw.Font? boldFont,
    pw.Font? italicFont,
    pw.Font? boldItalicFont,
  }) {
    final leftWidgets = _renderBlocks(
      config.footerLeftBlocks,
      resolver,
      scheme,
      font: font,
      boldFont: boldFont,
      italicFont: italicFont,
      boldItalicFont: boldItalicFont,
    );
    final centreWidgets = _renderBlocks(
      config.footerCentreBlocks,
      resolver,
      scheme,
      font: font,
      boldFont: boldFont,
      italicFont: italicFont,
      boldItalicFont: boldItalicFont,
    );

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 3,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: leftWidgets,
          ),
        ),
        pw.Expanded(
          flex: 3,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: centreWidgets,
          ),
        ),
        pw.Text(
          'Page $pageNumber of $pagesCount',
          style: pw.TextStyle(fontSize: 8, color: _darkGray, font: font),
        ),
      ],
    );
  }

  /// Minimal footer: page numbers only.
  static pw.Widget _buildMinimalFooter({
    required PdfColourSchemeV2 scheme,
    required int pageNumber,
    required int pagesCount,
    pw.Font? font,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Text(
          'Page $pageNumber of $pagesCount',
          style: pw.TextStyle(fontSize: 8, color: _darkGray, font: font),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  BLOCK RENDERING
  // ══════════════════════════════════════════════════════════════════════

  /// Render a list of [ContentBlock]s into PDF widgets.
  static List<pw.Widget> _renderBlocks(
    List<ContentBlock> blocks,
    PdfVariableResolver resolver,
    PdfColourSchemeV2 scheme, {
    Uint8List? logoBytes,
    pw.Font? font,
    pw.Font? boldFont,
    pw.Font? italicFont,
    pw.Font? boldItalicFont,
  }) {
    final widgets = <pw.Widget>[];
    for (final block in blocks) {
      final widget = switch (block.type) {
        ContentBlockType.text => _renderTextBlock(
            block, resolver, scheme,
            font: font,
            boldFont: boldFont,
            italicFont: italicFont,
            boldItalicFont: boldItalicFont,
          ),
        ContentBlockType.logo => _renderLogoBlock(block, logoBytes),
        ContentBlockType.divider => _renderDividerBlock(block, scheme),
        ContentBlockType.spacer => pw.SizedBox(height: block.spacingAfter),
      };
      if (widget != null) widgets.add(widget);
    }
    return widgets;
  }

  static pw.Widget? _renderTextBlock(
    ContentBlock block,
    PdfVariableResolver resolver,
    PdfColourSchemeV2 scheme, {
    pw.Font? font,
    pw.Font? boldFont,
    pw.Font? italicFont,
    pw.Font? boldItalicFont,
  }) {
    // Resolve the text content
    String text;
    if (block.variable != null && block.variable != PdfVariable.custom) {
      text = resolver.resolve(block.variable!.token);
      // If the variable resolved to the token itself (not found), use custom text
      if (text == block.variable!.token && block.text != null) {
        text = resolver.resolve(block.text!);
      }
    } else {
      text = resolver.resolve(block.text ?? '');
    }

    if (text.isEmpty) return null;
    if (block.uppercase) text = text.toUpperCase();

    // Determine colour: per-block override → company name uses primary → default dark gray
    final color = block.colorValue != null
        ? PdfColor.fromInt(block.colorValue!)
        : (block.variable == PdfVariable.companyName
            ? scheme.primaryColor
            : _darkGray);

    // Determine font
    pw.Font? effectiveFont;
    if (block.bold && block.italic) {
      effectiveFont = boldItalicFont ?? boldFont ?? font;
    } else if (block.bold) {
      effectiveFont = boldFont ?? font;
    } else if (block.italic) {
      effectiveFont = italicFont ?? font;
    } else {
      effectiveFont = font;
    }

    // Map alignment
    final textAlign = switch (block.alignment) {
      TextAlignment.left => pw.TextAlign.left,
      TextAlignment.center => pw.TextAlign.center,
      TextAlignment.right => pw.TextAlign.right,
    };

    final textWidget = pw.Text(
      text,
      textAlign: textAlign,
      style: pw.TextStyle(
        fontSize: block.fontSize,
        fontWeight: block.bold ? pw.FontWeight.bold : null,
        fontStyle: block.italic ? pw.FontStyle.italic : null,
        color: color,
        font: effectiveFont,
        fontBold: boldFont,
        fontItalic: italicFont,
        fontBoldItalic: boldItalicFont,
      ),
    );

    if (block.spacingAfter > 0) {
      return pw.Padding(
        padding: pw.EdgeInsets.only(bottom: block.spacingAfter),
        child: textWidget,
      );
    }
    return textWidget;
  }

  static pw.Widget? _renderLogoBlock(ContentBlock block, Uint8List? logoBytes) {
    if (logoBytes == null) return null;

    final width = block.logoWidth ?? 60;
    final height = block.logoHeight ?? 60;

    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: block.spacingAfter),
      child: pw.Container(
        width: width,
        height: height,
        child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
      ),
    );
  }

  static pw.Widget _renderDividerBlock(
    ContentBlock block,
    PdfColourSchemeV2 scheme,
  ) {
    final color = block.dividerColorValue != null
        ? PdfColor.fromInt(block.dividerColorValue!)
        : scheme.primaryColor;

    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: block.spacingAfter),
      child: pw.Container(
        height: block.dividerThickness ?? 1,
        color: color,
      ),
    );
  }

  // ── Helpers ──

  static pw.Widget? _buildLogoWidget(Uint8List? logoBytes, double size) {
    if (logoBytes == null) return null;
    return pw.Container(
      width: size,
      height: size,
      child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
    );
  }
}
