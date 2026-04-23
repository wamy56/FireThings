import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../../models/pdf_branding.dart';
import '../../../../theme/web_theme.dart';
import '../../../../utils/icon_map.dart';
import 'branding_apply_to_section.dart';
import 'branding_colour_picker.dart';
import 'branding_logo_upload.dart';
import 'branding_style_toggle_group.dart';

class BrandingControlsPanel extends StatefulWidget {
  final int selectedTab;
  final ValueChanged<int> onTabChanged;
  final PdfBranding branding;
  final ValueChanged<PdfBranding> onBrandingChanged;
  final BrandingDocType selectedDocType;
  final String? logoFileName;
  final int? logoFileSize;
  final void Function(({String name, int size, Uint8List bytes})) onLogoPicked;
  final VoidCallback onLogoRemoved;

  const BrandingControlsPanel({
    super.key,
    required this.selectedTab,
    required this.onTabChanged,
    required this.branding,
    required this.onBrandingChanged,
    required this.selectedDocType,
    this.logoFileName,
    this.logoFileSize,
    required this.onLogoPicked,
    required this.onLogoRemoved,
  });

  static const _tabs = [
    (icon: IconsaxPlusLinear.color_swatch, label: 'Brand'),
    (icon: IconsaxPlusLinear.text, label: 'Type'),
    (icon: IconsaxPlusLinear.element_3, label: 'Layout'),
    (icon: IconsaxPlusLinear.book, label: 'Content'),
  ];

  @override
  State<BrandingControlsPanel> createState() => _BrandingControlsPanelState();
}

class _BrandingControlsPanelState extends State<BrandingControlsPanel> {
  late TextEditingController _eyebrowController;
  late TextEditingController _titleController;
  late TextEditingController _subtitleController;
  late TextEditingController _footerTextController;

  BrandingDocType? _lastDocType;

  @override
  void initState() {
    super.initState();
    final ct = widget.branding.coverTextFor(widget.selectedDocType);
    _eyebrowController = TextEditingController(text: ct?.eyebrow ?? '');
    _titleController = TextEditingController(text: ct?.title ?? '');
    _subtitleController = TextEditingController(text: ct?.subtitle ?? '');
    _footerTextController = TextEditingController(text: widget.branding.footerText);
    _lastDocType = widget.selectedDocType;
  }

  @override
  void didUpdateWidget(BrandingControlsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.selectedDocType != _lastDocType) {
      _lastDocType = widget.selectedDocType;
      final ct = widget.branding.coverTextFor(widget.selectedDocType);
      _eyebrowController.text = ct?.eyebrow ?? '';
      _titleController.text = ct?.title ?? '';
      _subtitleController.text = ct?.subtitle ?? '';
    }

    if (oldWidget.branding.footerText != widget.branding.footerText &&
        _footerTextController.text != widget.branding.footerText) {
      _footerTextController.text = widget.branding.footerText;
    }
  }

  @override
  void dispose() {
    _eyebrowController.dispose();
    _titleController.dispose();
    _subtitleController.dispose();
    _footerTextController.dispose();
    super.dispose();
  }

  void _update(PdfBranding Function(PdfBranding) fn) {
    widget.onBrandingChanged(fn(widget.branding));
  }

  void _updateCoverText() {
    final ct = BrandingCoverText(
      eyebrow: _eyebrowController.text.isEmpty ? null : _eyebrowController.text,
      title: _titleController.text.isEmpty ? null : _titleController.text,
      subtitle: _subtitleController.text.isEmpty ? null : _subtitleController.text,
    );
    final allNull = ct.eyebrow == null && ct.title == null && ct.subtitle == null;
    switch (widget.selectedDocType) {
      case BrandingDocType.report:
        _update((b) => allNull ? b.copyWith(clearCoverTextReport: true) : b.copyWith(coverTextReport: ct));
      case BrandingDocType.quote:
        _update((b) => allNull ? b.copyWith(clearCoverTextQuote: true) : b.copyWith(coverTextQuote: ct));
      case BrandingDocType.invoice:
        _update((b) => allNull ? b.copyWith(clearCoverTextInvoice: true) : b.copyWith(coverTextInvoice: ct));
      case BrandingDocType.jobsheet:
        _update((b) => allNull ? b.copyWith(clearCoverTextJobsheet: true) : b.copyWith(coverTextJobsheet: ct));
    }
  }

  static const _primaryPresets = [
    Color(0xFF1A1A2E), Color(0xFF0F172A), Color(0xFF1E40AF), Color(0xFF047857),
    Color(0xFFB91C1C), Color(0xFF7C2D12), Color(0xFF4C1D95), Color(0xFF18181B),
  ];

  static const _accentPresets = [
    Color(0xFFFFB020), Color(0xFFDC2626), Color(0xFF2563EB), Color(0xFF4CAF50),
    Color(0xFFEC4899), Color(0xFF06B6D4), Color(0xFFF97316), Color(0xFF65A30D),
  ];

  static const _docTypeLabels = {
    BrandingDocType.report: 'Compliance Report',
    BrandingDocType.quote: 'Quote',
    BrandingDocType.invoice: 'Invoice',
    BrandingDocType.jobsheet: 'Job Sheet',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: FtColors.bg,
        border: Border(right: BorderSide(color: FtColors.border)),
      ),
      child: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: widget.selectedTab == 0
                ? _buildBrandTab()
                : _buildPlaceholderTab(BrandingControlsPanel._tabs[widget.selectedTab].label),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        color: FtColors.bg,
        border: Border(bottom: BorderSide(color: FtColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: List.generate(BrandingControlsPanel._tabs.length, (i) {
          final active = i == widget.selectedTab;
          final tab = BrandingControlsPanel._tabs[i];
          return Expanded(
            child: InkWell(
              onTap: () => widget.onTabChanged(i),
              child: AnimatedContainer(
                duration: FtMotion.fast,
                curve: FtMotion.standardCurve,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: active ? FtColors.accent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(tab.icon, size: 14, color: active ? FtColors.primary : FtColors.fg2),
                    const SizedBox(width: 6),
                    Text(
                      tab.label,
                      style: FtText.inter(
                        size: 12,
                        weight: FontWeight.w600,
                        color: active ? FtColors.primary : FtColors.fg2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBrandTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSection(
            title: 'Apply branding to',
            helper: 'Pick which document types use this branding. Most companies want all four.',
            child: BrandingApplyToSection(
              appliesTo: widget.branding.appliesTo,
              onChanged: (s) => _update((b) => b.copyWith(appliesTo: s)),
            ),
          ),
          _buildSection(
            title: 'Logo',
            helper: 'PNG or SVG. Appears on the cover page and in every page header.',
            child: BrandingLogoUpload(
              logoFileName: widget.logoFileName,
              logoFileSize: widget.logoFileSize,
              onLogoPicked: widget.onLogoPicked,
              onLogoRemoved: widget.onLogoRemoved,
            ),
          ),
          _buildSection(
            title: 'Brand colours',
            helper: 'Used for cover page, headers, accent details and section titles throughout the report.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BrandingColourPicker(
                  label: 'Primary colour',
                  hexValue: widget.branding.primaryColour,
                  presets: _primaryPresets,
                  onChanged: (hex) => _update((b) => b.copyWith(primaryColour: hex)),
                ),
                const SizedBox(height: 14),
                BrandingColourPicker(
                  label: 'Accent colour',
                  hexValue: widget.branding.accentColour,
                  presets: _accentPresets,
                  onChanged: (hex) => _update((b) => b.copyWith(accentColour: hex)),
                ),
              ],
            ),
          ),
          _buildSection(
            title: 'Cover page style',
            helper: 'Three layout treatments. Pick the one that fits your brand.',
            child: BrandingStyleToggleGroup(
              labels: const ['Bold', 'Minimal', 'Bordered'],
              selectedIndex: widget.branding.coverStyle.index,
              onChanged: (i) => _update((b) => b.copyWith(coverStyle: CoverStyle.values[i])),
            ),
          ),
          _buildCoverTextSection(),
          _buildHeaderSection(),
          _buildFooterSection(),
          _buildSyncCallout(),
        ],
      ),
    );
  }

  // ── Cover text ──

  Widget _buildCoverTextSection() {
    return _buildSection(
      title: 'Cover page text',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: FtColors.accentSoft,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Editing for: ${_docTypeLabels[widget.selectedDocType]}',
              style: FtText.inter(size: 11, weight: FontWeight.w600, color: FtColors.accentHover),
            ),
          ),
          const SizedBox(height: 14),
          _labelledField('Eyebrow line', _eyebrowController, onChanged: (_) => _updateCoverText()),
          const SizedBox(height: 14),
          _labelledField(
            'Title',
            _titleController,
            onChanged: (_) => _updateCoverText(),
            helper: 'Tip: use {{report_type}} to auto-fill',
          ),
          const SizedBox(height: 14),
          _labelledField('Subtitle', _subtitleController, onChanged: (_) => _updateCoverText()),
        ],
      ),
    );
  }

  // ── Header ──

  Widget _buildHeaderSection() {
    return _buildSection(
      title: 'Page header',
      helper: 'Repeats on every page after the cover.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Style', style: FtText.inter(size: 12, weight: FontWeight.w600, color: FtColors.fg2)),
          const SizedBox(height: 6),
          BrandingStyleToggleGroup(
            labels: const ['Solid', 'Minimal', 'Bordered'],
            selectedIndex: widget.branding.headerStyle.index,
            onChanged: (i) => _update((b) => b.copyWith(headerStyle: HeaderStyle.values[i])),
          ),
          const SizedBox(height: 8),
          _switchRow(
            'Show company name',
            widget.branding.headerShowCompanyName,
            (v) => _update((b) => b.copyWith(headerShowCompanyName: v)),
          ),
          _switchRow(
            'Show certificate number',
            widget.branding.headerShowDocNumber,
            (v) => _update((b) => b.copyWith(headerShowDocNumber: v)),
          ),
        ],
      ),
    );
  }

  // ── Footer ──

  Widget _buildFooterSection() {
    return _buildSection(
      title: 'Page footer',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Style', style: FtText.inter(size: 12, weight: FontWeight.w600, color: FtColors.fg2)),
          const SizedBox(height: 6),
          BrandingStyleToggleGroup(
            labels: const ['Light', 'Minimal', 'Coloured'],
            selectedIndex: widget.branding.footerStyle.index,
            onChanged: (i) => _update((b) => b.copyWith(footerStyle: FooterStyle.values[i])),
          ),
          const SizedBox(height: 14),
          _labelledField(
            'Footer text',
            _footerTextController,
            onChanged: (v) => _update((b) => b.copyWith(footerText: v)),
            helper: 'Page numbers are added automatically',
          ),
          const SizedBox(height: 8),
          _switchRow(
            'Show company name',
            widget.branding.footerShowCompanyName,
            (v) => _update((b) => b.copyWith(footerShowCompanyName: v)),
          ),
        ],
      ),
    );
  }

  // ── Sync callout ──

  Widget _buildSyncCallout() {
    return Container(
      color: FtColors.bgAlt,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: FtColors.successSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.check_circle_outline, size: 14, color: FtColors.success),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Live on mobile', style: FtText.inter(size: 12, weight: FontWeight.w700, color: FtColors.fg1)),
                const SizedBox(height: 2),
                Text(
                  'Engineers will see your branding the next time they generate any report. No app update needed.',
                  style: FtText.inter(size: 12, weight: FontWeight.w500, color: FtColors.fg2, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared helpers ──

  Widget _buildSection({required String title, String? helper, required Widget child}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: FtColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: FtText.inter(size: 11, weight: FontWeight.w700, color: FtColors.fg2, letterSpacing: 0.4),
          ),
          if (helper != null) ...[
            const SizedBox(height: 4),
            Text(helper, style: FtText.inter(size: 12, color: FtColors.hint, height: 1.5)),
            const SizedBox(height: 16),
          ] else
            const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: FtText.inter(size: 13, weight: FontWeight.w500, color: FtColors.fg1)),
          GestureDetector(
            onTap: () => onChanged(!value),
            child: AnimatedContainer(
              duration: FtMotion.fast,
              width: 36,
              height: 20,
              decoration: BoxDecoration(
                color: value ? FtColors.success : FtColors.border,
                borderRadius: BorderRadius.circular(100),
              ),
              child: AnimatedAlign(
                duration: FtMotion.fast,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 16,
                  height: 16,
                  margin: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Color(0x33000000), offset: Offset(0, 1), blurRadius: 3)],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _labelledField(
    String label,
    TextEditingController controller, {
    ValueChanged<String>? onChanged,
    String? helper,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: FtText.inter(size: 12, weight: FontWeight.w600, color: FtColors.fg2)),
        const SizedBox(height: 6),
        SizedBox(
          height: 36,
          child: TextField(
            controller: controller,
            style: FtText.inter(size: 13, color: FtColors.fg1),
            onChanged: onChanged,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: FtColors.border, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: FtColors.border, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: FtColors.primary, width: 1.5),
              ),
            ),
          ),
        ),
        if (helper != null) ...[
          const SizedBox(height: 5),
          Text(helper, style: FtText.inter(size: 11, color: FtColors.hint)),
        ],
      ],
    );
  }

  Widget _buildPlaceholderTab(String tabName) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.brush, size: 32, color: FtColors.hint),
          const SizedBox(height: 12),
          Text(
            '$tabName controls',
            style: FtText.inter(size: 14, weight: FontWeight.w600, color: FtColors.fg2),
          ),
          const SizedBox(height: 4),
          Text('Coming soon', style: FtText.helper),
        ],
      ),
    );
  }
}
