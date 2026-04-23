import 'package:flutter/material.dart';

import '../../../../models/pdf_branding.dart';
import '../../../../theme/web_theme.dart';
import 'branding_colour_picker.dart';

class PdfPreviewBuilders {
  final PdfBranding branding;
  final BrandingDocType selectedDocType;

  PdfPreviewBuilders({required this.branding, required this.selectedDocType});

  Color get primary => hexToColor(branding.primaryColour);
  Color get accent => hexToColor(branding.accentColour);

  // ── Cover ──

  Widget buildCover({
    required String defaultEyebrow,
    required String defaultTitle,
    required String defaultSubtitle,
    required List<({String label, String value})> metaItems,
  }) {
    final style = branding.coverStyle;
    final onDark = style == CoverStyle.bold;
    final bg = onDark ? primary : Colors.white;
    final fg = onDark ? Colors.white : primary;

    final coverText = branding.coverTextFor(selectedDocType);
    final eyebrow = coverText?.eyebrow ?? defaultEyebrow;
    final title = coverText?.title ?? defaultTitle;
    final subtitle = coverText?.subtitle ?? defaultSubtitle;

    final padding = switch (style) {
      CoverStyle.bold => const EdgeInsets.fromLTRB(56, 64, 56, 48),
      CoverStyle.minimal => const EdgeInsets.fromLTRB(56, 80, 56, 56),
      CoverStyle.bordered => const EdgeInsets.all(56),
    };

    final border = style == CoverStyle.bordered
        ? Border(
            top: BorderSide(color: primary, width: 8),
            bottom: BorderSide(color: primary, width: 8),
          )
        : null;

    return Container(
      padding: padding,
      decoration: BoxDecoration(color: bg, border: border),
      child: Stack(
        children: [
          if (style == CoverStyle.bold)
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 360,
                height: 360,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [accent.withValues(alpha: 0.18), Colors.transparent],
                    stops: const [0, 0.7],
                  ),
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: FtText.inter(
                  size: 10,
                  weight: FontWeight.w700,
                  color: onDark
                      ? Colors.white.withValues(alpha: 0.6)
                      : accent,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text('F',
                          style: FtText.outfit(
                              size: 22, weight: FontWeight.w800, color: primary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'FireThings Demo Co.',
                    style: FtText.inter(size: 20, weight: FontWeight.w800, color: fg),
                  ),
                ],
              ),
              const SizedBox(height: 56),
              if (style == CoverStyle.minimal)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Container(width: 56, height: 4, color: accent),
                ),
              Text(
                title,
                style: FtText.outfit(
                  size: 42,
                  weight: FontWeight.w800,
                  color: fg,
                  height: 1.05,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                style: FtText.inter(
                  size: 16,
                  weight: FontWeight.w500,
                  color: onDark
                      ? Colors.white.withValues(alpha: 0.75)
                      : FtColors.fg2,
                ),
              ),
              const SizedBox(height: 56),
              Container(
                padding: const EdgeInsets.only(top: 24),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: onDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : const Color(0xFFE8E5DE),
                    ),
                  ),
                ),
                child: Wrap(
                  spacing: 32,
                  runSpacing: 16,
                  children: metaItems
                      .map((m) => buildCoverMeta(m.label, m.value, onDark: onDark))
                      .toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildCoverMeta(String label, String value, {required bool onDark}) {
    return SizedBox(
      width: 280,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: FtText.inter(
              size: 10,
              weight: FontWeight.w700,
              color: onDark
                  ? Colors.white.withValues(alpha: 0.5)
                  : FtColors.fg2,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: FtText.inter(
              size: 14,
              weight: FontWeight.w600,
              color: onDark ? Colors.white : FtColors.fg1,
            ),
          ),
        ],
      ),
    );
  }

  // ── Page header ──

  Widget buildPageHeader({required String metaText}) {
    final style = branding.headerStyle;
    final onDark = style == HeaderStyle.solid;
    final bg = onDark ? primary : Colors.white;
    final fg = onDark ? Colors.white : primary;

    final border = switch (style) {
      HeaderStyle.solid => null,
      HeaderStyle.minimal => Border(bottom: BorderSide(color: accent, width: 2)),
      HeaderStyle.bordered =>
        const Border(bottom: BorderSide(color: Color(0xFFE8E5DE))),
    };

    final metaColour = switch (style) {
      HeaderStyle.solid => Colors.white.withValues(alpha: 0.7),
      HeaderStyle.minimal => primary.withValues(alpha: 0.7),
      HeaderStyle.bordered => FtColors.fg2,
    };

    final showName = branding.headerShowCompanyName;
    final showDoc = branding.headerShowDocNumber;

    if (!showName && !showDoc) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 56,
        vertical: style == HeaderStyle.solid ? 16 : 14,
      ),
      decoration: BoxDecoration(color: bg, border: border),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (showName)
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Center(
                    child: Text('F',
                        style: FtText.outfit(
                            size: 14, weight: FontWeight.w800, color: primary)),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'FireThings Demo Co.',
                  style: FtText.inter(size: 14, weight: FontWeight.w700, color: fg),
                ),
              ],
            )
          else
            const SizedBox.shrink(),
          if (showDoc)
            Text(
              metaText,
              style: FtText.inter(
                  size: 11, weight: FontWeight.w500, color: metaColour),
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }

  // ── Section header ──

  Widget buildSectionHeader({
    required String eyebrow,
    required String title,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: FtText.inter(
            size: 10,
            weight: FontWeight.w700,
            color: accent,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: FtText.outfit(
            size: 26,
            weight: FontWeight.w800,
            color: primary,
            letterSpacing: -0.6,
          ),
        ),
      ],
    );
  }

  // ── Footer ──

  Widget buildFooter({
    required String defaultLeftText,
    String defaultPageText = 'Page 1 of 14',
  }) {
    final style = branding.footerStyle;
    final onDark = style == FooterStyle.coloured;

    final bg = switch (style) {
      FooterStyle.light => FtColors.bgAlt,
      FooterStyle.minimal => Colors.white,
      FooterStyle.coloured => primary,
    };

    final border = style == FooterStyle.minimal
        ? const Border(top: BorderSide(color: Color(0xFFE8E5DE)))
        : null;

    final textColour =
        onDark ? Colors.white.withValues(alpha: 0.6) : FtColors.fg2;

    final brandColour = onDark ? accent : primary;

    final leftText = branding.footerText.isNotEmpty
        ? branding.footerText
        : defaultLeftText;

    final showName = branding.footerShowCompanyName;
    final showPages = branding.footerShowPageNumbers;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 18),
      decoration: BoxDecoration(color: bg, border: border),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            leftText,
            style: FtText.inter(
              size: 10,
              weight: FontWeight.w500,
              color: textColour,
              letterSpacing: 0.3,
            ),
          ),
          if (showName || showPages)
            Text.rich(
              TextSpan(
                children: [
                  if (showName)
                    TextSpan(
                      text: 'FireThings Demo Co.',
                      style: FtText.inter(
                          size: 10, weight: FontWeight.w600, color: brandColour),
                    ),
                  if (showName && showPages)
                    TextSpan(
                      text: ' · ',
                      style: FtText.inter(
                          size: 10, weight: FontWeight.w500, color: textColour),
                    ),
                  if (showPages)
                    TextSpan(
                      text: defaultPageText,
                      style: FtText.inter(
                          size: 10, weight: FontWeight.w500, color: textColour),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
