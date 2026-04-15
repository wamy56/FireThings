import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/pdf_header_config.dart';
import '../../models/pdf_footer_config.dart';
import '../../models/pdf_colour_scheme.dart';
import '../../models/pdf_section_style_config.dart';
import '../../models/pdf_typography_config.dart';
import '../../services/company_pdf_config_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/keyboard_dismiss_wrapper.dart';
import '../../widgets/premium_toast.dart';
import '../../widgets/premium_dialog.dart';
import '../../widgets/adaptive_app_bar.dart';
import '../../widgets/animated_save_button.dart';
import '../../widgets/preset_colour_grid.dart';

class CompanyPdfDesignScreen extends StatefulWidget {
  final String companyId;

  const CompanyPdfDesignScreen({super.key, required this.companyId});

  @override
  State<CompanyPdfDesignScreen> createState() => _CompanyPdfDesignScreenState();
}

class _CompanyPdfDesignScreenState extends State<CompanyPdfDesignScreen> {
  final _service = CompanyPdfConfigService.instance;
  bool _isLoading = true;

  // Current configs for both doc types
  PdfHeaderConfig? _jobsheetHeader;
  PdfHeaderConfig? _invoiceHeader;
  PdfFooterConfig? _jobsheetFooter;
  PdfFooterConfig? _invoiceFooter;
  PdfColourScheme? _jobsheetColour;
  PdfColourScheme? _invoiceColour;
  PdfSectionStyleConfig? _jobsheetSectionStyle;
  PdfSectionStyleConfig? _invoiceSectionStyle;
  PdfTypographyConfig? _jobsheetTypography;
  PdfTypographyConfig? _invoiceTypography;

  @override
  void initState() {
    super.initState();
    _loadConfigs();
  }

  Future<void> _loadConfigs() async {
    final results = await Future.wait([
      _service.getHeaderConfig(widget.companyId, PdfDocumentType.jobsheet),
      _service.getHeaderConfig(widget.companyId, PdfDocumentType.invoice),
      _service.getFooterConfig(widget.companyId, PdfDocumentType.jobsheet),
      _service.getFooterConfig(widget.companyId, PdfDocumentType.invoice),
      _service.getColourScheme(widget.companyId, PdfDocumentType.jobsheet),
      _service.getColourScheme(widget.companyId, PdfDocumentType.invoice),
      _service.getSectionStyleConfig(widget.companyId, PdfDocumentType.jobsheet),
      _service.getSectionStyleConfig(widget.companyId, PdfDocumentType.invoice),
      _service.getTypographyConfig(widget.companyId, PdfDocumentType.jobsheet),
      _service.getTypographyConfig(widget.companyId, PdfDocumentType.invoice),
    ]);

    if (mounted) {
      setState(() {
        _jobsheetHeader = results[0] as PdfHeaderConfig?;
        _invoiceHeader = results[1] as PdfHeaderConfig?;
        _jobsheetFooter = results[2] as PdfFooterConfig?;
        _invoiceFooter = results[3] as PdfFooterConfig?;
        _jobsheetColour = results[4] as PdfColourScheme?;
        _invoiceColour = results[5] as PdfColourScheme?;
        _jobsheetSectionStyle = results[6] as PdfSectionStyleConfig?;
        _invoiceSectionStyle = results[7] as PdfSectionStyleConfig?;
        _jobsheetTypography = results[8] as PdfTypographyConfig?;
        _invoiceTypography = results[9] as PdfTypographyConfig?;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AdaptiveNavigationBar(title: 'Company PDF Branding'),
      body: KeyboardDismissWrapper(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 750),
            child: _isLoading
              ? const AdaptiveLoadingIndicator()
              : ListView(
                  padding: const EdgeInsets.all(AppTheme.screenPadding),
              children: [
                Text(
                  'Configure the PDF branding used for jobsheets and invoices created from dispatched jobs.',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                // Jobsheet section
                _buildSectionTitle('Jobsheet PDF', isDark),
                const SizedBox(height: 12),
                _buildConfigCard(
                  isDark,
                  'Header',
                  AppIcons.document,
                  _jobsheetHeader != null ? 'Configured' : 'Not set (uses personal)',
                  () => _editHeader(PdfDocumentType.jobsheet),
                ),
                const SizedBox(height: 8),
                _buildConfigCard(
                  isDark,
                  'Footer',
                  AppIcons.note,
                  _jobsheetFooter != null ? 'Configured' : 'Not set (uses personal)',
                  () => _editFooter(PdfDocumentType.jobsheet),
                ),
                const SizedBox(height: 8),
                _buildConfigCard(
                  isDark,
                  'Colour Scheme',
                  AppIcons.colorSwatch,
                  _jobsheetColour != null ? 'Configured' : 'Not set (uses personal)',
                  () => _editColourScheme(PdfDocumentType.jobsheet),
                ),
                const SizedBox(height: 8),
                _buildConfigCard(
                  isDark,
                  'Section Style',
                  AppIcons.layout,
                  _jobsheetSectionStyle != null ? 'Configured' : 'Not set (uses personal)',
                  () => _editSectionStyle(PdfDocumentType.jobsheet),
                ),
                const SizedBox(height: 8),
                _buildConfigCard(
                  isDark,
                  'Typography',
                  AppIcons.text,
                  _jobsheetTypography != null ? 'Configured' : 'Not set (uses personal)',
                  () => _editTypography(PdfDocumentType.jobsheet),
                ),

                const SizedBox(height: 32),

                // Invoice section
                _buildSectionTitle('Invoice PDF', isDark),
                const SizedBox(height: 12),
                _buildConfigCard(
                  isDark,
                  'Header',
                  AppIcons.document,
                  _invoiceHeader != null ? 'Configured' : 'Not set (uses personal)',
                  () => _editHeader(PdfDocumentType.invoice),
                ),
                const SizedBox(height: 8),
                _buildConfigCard(
                  isDark,
                  'Footer',
                  AppIcons.note,
                  _invoiceFooter != null ? 'Configured' : 'Not set (uses personal)',
                  () => _editFooter(PdfDocumentType.invoice),
                ),
                const SizedBox(height: 8),
                _buildConfigCard(
                  isDark,
                  'Colour Scheme',
                  AppIcons.colorSwatch,
                  _invoiceColour != null ? 'Configured' : 'Not set (uses personal)',
                  () => _editColourScheme(PdfDocumentType.invoice),
                ),
                const SizedBox(height: 8),
                _buildConfigCard(
                  isDark,
                  'Section Style',
                  AppIcons.layout,
                  _invoiceSectionStyle != null ? 'Configured' : 'Not set (uses personal)',
                  () => _editSectionStyle(PdfDocumentType.invoice),
                ),
                const SizedBox(height: 8),
                _buildConfigCard(
                  isDark,
                  'Typography',
                  AppIcons.text,
                  _invoiceTypography != null ? 'Configured' : 'Not set (uses personal)',
                  () => _editTypography(PdfDocumentType.invoice),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
      ),
    );
  }

  Widget _buildConfigCard(
    bool isDark,
    String title,
    IconData icon,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: isDark ? null : AppTheme.cardShadow,
      ),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primaryBlue),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: Icon(AppIcons.arrowRight),
        onTap: onTap,
      ),
    );
  }

  Future<void> _editHeader(PdfDocumentType type) async {
    final typeName = type == PdfDocumentType.jobsheet ? 'Jobsheet' : 'Invoice';
    final current = type == PdfDocumentType.jobsheet ? _jobsheetHeader : _invoiceHeader;
    final config = current ?? PdfHeaderConfig.defaults();

    await Navigator.push(
      context,
      adaptivePageRoute(
        builder: (_) => _CompanyHeaderEditorScreen(
          companyId: widget.companyId,
          docType: type,
          initialConfig: config,
          title: 'Company $typeName Header',
        ),
      ),
    );
    _loadConfigs();
  }

  Future<void> _editFooter(PdfDocumentType type) async {
    final typeName = type == PdfDocumentType.jobsheet ? 'Jobsheet' : 'Invoice';
    final current = type == PdfDocumentType.jobsheet ? _jobsheetFooter : _invoiceFooter;
    final config = current ?? PdfFooterConfig.defaults();

    await Navigator.push(
      context,
      adaptivePageRoute(
        builder: (_) => _CompanyFooterEditorScreen(
          companyId: widget.companyId,
          docType: type,
          initialConfig: config,
          title: 'Company $typeName Footer',
        ),
      ),
    );
    _loadConfigs();
  }

  Future<void> _editColourScheme(PdfDocumentType type) async {
    final typeName = type == PdfDocumentType.jobsheet ? 'Jobsheet' : 'Invoice';
    final current = type == PdfDocumentType.jobsheet ? _jobsheetColour : _invoiceColour;
    final config = current ?? PdfColourScheme.defaults();

    await Navigator.push(
      context,
      adaptivePageRoute(
        builder: (_) => _CompanyColourEditorScreen(
          companyId: widget.companyId,
          docType: type,
          initialScheme: config,
          title: 'Company $typeName Colours',
        ),
      ),
    );
    _loadConfigs();
  }

  Future<void> _editSectionStyle(PdfDocumentType type) async {
    final typeName = type == PdfDocumentType.jobsheet ? 'Jobsheet' : 'Invoice';
    final current = type == PdfDocumentType.jobsheet ? _jobsheetSectionStyle : _invoiceSectionStyle;
    final config = current ?? PdfSectionStyleConfig.defaults();

    await Navigator.push(
      context,
      adaptivePageRoute(
        builder: (_) => _CompanySectionStyleEditorScreen(
          companyId: widget.companyId,
          docType: type,
          initialConfig: config,
          title: 'Company $typeName Section Style',
        ),
      ),
    );
    _loadConfigs();
  }

  Future<void> _editTypography(PdfDocumentType type) async {
    final typeName = type == PdfDocumentType.jobsheet ? 'Jobsheet' : 'Invoice';
    final current = type == PdfDocumentType.jobsheet ? _jobsheetTypography : _invoiceTypography;
    final config = current ?? PdfTypographyConfig.defaults();

    await Navigator.push(
      context,
      adaptivePageRoute(
        builder: (_) => _CompanyTypographyEditorScreen(
          companyId: widget.companyId,
          docType: type,
          initialConfig: config,
          title: 'Company $typeName Typography',
        ),
      ),
    );
    _loadConfigs();
  }
}

// ═══════════════════════════════════════════════════════════════════
// HEADER EDITOR — with live preview, logo tab, zone tabs
// ═══════════════════════════════════════════════════════════════════

class _CompanyHeaderEditorScreen extends StatefulWidget {
  final String companyId;
  final PdfDocumentType docType;
  final PdfHeaderConfig initialConfig;
  final String title;

  const _CompanyHeaderEditorScreen({
    required this.companyId,
    required this.docType,
    required this.initialConfig,
    required this.title,
  });

  @override
  State<_CompanyHeaderEditorScreen> createState() => _CompanyHeaderEditorState();
}

class _CompanyHeaderEditorState extends State<_CompanyHeaderEditorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late PdfHeaderConfig _config;
  Uint8List? _logoBytes;
  bool _isLoadingLogo = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _config = widget.initialConfig;
    _loadLogo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLogo() async {
    final bytes = await CompanyPdfConfigService.instance
        .getCompanyLogoBytes(widget.companyId, widget.docType);
    if (mounted) {
      setState(() {
        _logoBytes = bytes;
        _isLoadingLogo = false;
      });
    }
  }

  Future<void> _save() async {
    await CompanyPdfConfigService.instance.saveHeaderConfig(
      widget.companyId,
      _config,
      widget.docType,
    );
    if (!mounted) return;
    context.showSuccessToast('Header saved');
    Navigator.pop(context);
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    ImageSource? source;

    await showAdaptiveActionSheet(
      context: context,
      title: 'Select Image Source',
      options: [
        ActionSheetOption(
          label: 'Camera',
          icon: AppIcons.gallery,
          onTap: () => source = ImageSource.camera,
        ),
        ActionSheetOption(
          label: 'Gallery',
          icon: AppIcons.gallery,
          onTap: () => source = ImageSource.gallery,
        ),
      ],
    );

    if (source == null) return;

    final picked = await picker.pickImage(
      source: source!,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    await CompanyPdfConfigService.instance
        .saveCompanyLogo(widget.companyId, bytes, widget.docType);
    setState(() => _logoBytes = bytes);

    if (mounted) context.showSuccessToast('Logo saved');
  }

  Future<void> _removeLogo() async {
    final confirm = await showAdaptiveAlertDialog<bool>(
      context: context,
      title: 'Remove Logo',
      message: 'Are you sure you want to remove the company logo?',
      confirmLabel: 'Remove',
      cancelLabel: 'Cancel',
      isDestructive: true,
    );

    if (confirm != true) return;

    await CompanyPdfConfigService.instance
        .removeCompanyLogo(widget.companyId, widget.docType);
    setState(() => _logoBytes = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdaptiveNavigationBar(
        title: widget.title,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: AnimatedSaveButton(
              label: 'Save',
              onPressed: _save,
              outlined: true,
            ),
          ),
        ],
      ),
      body: KeyboardDismissWrapper(
        child: Center(
        child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 750),
        child: Column(
          children: [
            _buildPreview(),
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(icon: Icon(AppIcons.image), text: 'Logo'),
                Tab(icon: Icon(AppIcons.noteText), text: 'Left Zone'),
                Tab(icon: Icon(AppIcons.noteText), text: 'Centre'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLogoTab(),
                  _buildZoneTab(isLeft: true),
                  _buildZoneTab(isLeft: false),
                ],
              ),
            ),
          ],
        ),
        ),
        ),
      ),
    );
  }

  // ─── LIVE PREVIEW ───────────────────────────────────────────

  Widget _buildPreview() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preview',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Color(0xFF1E3A5F),
                  width: 2,
                ),
              ),
            ),
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPreviewZone(isLeft: true),
                      if (_config.centreLines.isNotEmpty ||
                          _config.logoZone == LogoZone.centre) ...[
                        const SizedBox(width: 8),
                        _buildPreviewZone(isLeft: false),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'FORM TYPE\nREF: 001',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.bold,
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

  Widget _buildPreviewZone({required bool isLeft}) {
    final lines = isLeft ? _config.leftLines : _config.centreLines;
    final showLogo = _logoBytes != null &&
        ((isLeft && _config.logoZone == LogoZone.left) ||
            (!isLeft && _config.logoZone == LogoZone.centre));

    final previewSize = _config.logoSize.pixels * 0.5;

    final children = <Widget>[];
    if (showLogo) {
      children.add(
        Container(
          width: previewSize,
          height: previewSize,
          margin: const EdgeInsets.only(right: 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Image.memory(_logoBytes!, fit: BoxFit.contain),
          ),
        ),
      );
    }

    final textWidgets = <Widget>[];
    for (final line in lines) {
      final text = line.value.isNotEmpty ? line.value : '';
      if (text.isEmpty) continue;
      final isCompanyName = line.key == 'companyName';
      textWidgets.add(
        Text(
          isCompanyName ? text.toUpperCase() : text,
          style: TextStyle(
            fontSize: (line.fontSize * 0.55).clamp(5.0, 14.0),
            fontWeight: line.bold ? FontWeight.bold : FontWeight.normal,
            color: isCompanyName
                ? const Color(0xFF1E3A5F)
                : const Color(0xFF424242),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    if (textWidgets.isNotEmpty) {
      children.add(
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: textWidgets,
          ),
        ),
      );
    }

    if (children.isEmpty) return const SizedBox.shrink();

    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  // ─── LOGO TAB ──────────────────────────────────────────────

  Widget _buildLogoTab() {
    if (_isLoadingLogo) {
      return const Center(child: AdaptiveLoadingIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Logo preview / upload
        Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: _logoBytes != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Image.memory(_logoBytes!, fit: BoxFit.contain),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(AppIcons.image, size: 40, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text('No logo uploaded',
                        style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _pickLogo,
                icon: Icon(AppIcons.document, size: 18),
                label: Text(_logoBytes != null ? 'Change Logo' : 'Upload Logo'),
              ),
            ),
            if (_logoBytes != null) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _removeLogo,
                icon: Icon(AppIcons.trash, size: 18),
                label: const Text('Remove'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ],
        ),
        const SizedBox(height: 24),

        // Logo placement
        const Text('Logo Placement',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        SegmentedButton<LogoZone>(
          segments: const [
            ButtonSegment(value: LogoZone.left, label: Text('Left')),
            ButtonSegment(value: LogoZone.centre, label: Text('Centre')),
            ButtonSegment(value: LogoZone.none, label: Text('None')),
          ],
          selected: {_config.logoZone},
          onSelectionChanged: (selection) {
            setState(() {
              _config = _config.copyWith(logoZone: selection.first);
            });
          },
        ),
        const SizedBox(height: 24),

        // Logo size
        const Text('Logo Size',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        SegmentedButton<LogoSize>(
          segments: const [
            ButtonSegment(value: LogoSize.small, label: Text('Small (40px)')),
            ButtonSegment(value: LogoSize.medium, label: Text('Medium (60px)')),
            ButtonSegment(value: LogoSize.large, label: Text('Large (80px)')),
          ],
          selected: {_config.logoSize},
          onSelectionChanged: (selection) {
            setState(() {
              _config = _config.copyWith(logoSize: selection.first);
            });
          },
        ),
      ],
    );
  }

  // ─── ZONE TABS ─────────────────────────────────────────────

  Widget _buildZoneTab({required bool isLeft}) {
    final lines = isLeft ? _config.leftLines : _config.centreLines;

    return Column(
      children: [
        Expanded(
          child: lines.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(AppIcons.noteText, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          isLeft
                              ? 'No text lines configured.\nTap "Add Text Line" to start.'
                              : 'The centre zone is empty by default.\nAdd text lines here for a two-column header.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: lines.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final updated = List<HeaderTextLine>.from(lines);
                      final item = updated.removeAt(oldIndex);
                      updated.insert(newIndex, item);
                      _config = isLeft
                          ? _config.copyWith(leftLines: updated)
                          : _config.copyWith(centreLines: updated);
                    });
                  },
                  itemBuilder: (context, index) {
                    return _buildLineCard(
                      key: ValueKey('${isLeft ? "left" : "centre"}_$index'),
                      line: lines[index],
                      index: index,
                      isLeft: isLeft,
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _addLine(isLeft),
              icon: Icon(AppIcons.add),
              label: const Text('Add Text Line'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLineCard({
    required Key key,
    required HeaderTextLine line,
    required int index,
    required bool isLeft,
  }) {
    final lines = isLeft ? _config.leftLines : _config.centreLines;

    return Card(
      key: key,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(AppIcons.menu, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _labelForKey(line.key),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                IconButton(
                  icon: Icon(AppIcons.trash, size: 20),
                  color: Colors.red,
                  onPressed: () {
                    setState(() {
                      final updated = List<HeaderTextLine>.from(lines);
                      updated.removeAt(index);
                      _config = isLeft
                          ? _config.copyWith(leftLines: updated)
                          : _config.copyWith(centreLines: updated);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: line.value,
              decoration: const InputDecoration(
                labelText: 'Text',
                hintText: 'Enter text...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              textInputAction: TextInputAction.done,
              onChanged: (val) {
                final updated = List<HeaderTextLine>.from(lines);
                updated[index] = updated[index].copyWith(value: val);
                _config = isLeft
                    ? _config.copyWith(leftLines: updated)
                    : _config.copyWith(centreLines: updated);
                setState(() {});
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Size:', style: TextStyle(fontSize: 12)),
                Expanded(
                  child: AdaptiveSlider(
                    value: line.fontSize,
                    min: 8,
                    max: 24,
                    divisions: 16,
                    onChanged: (val) {
                      setState(() {
                        final updated = List<HeaderTextLine>.from(lines);
                        updated[index] = updated[index].copyWith(fontSize: val);
                        _config = isLeft
                            ? _config.copyWith(leftLines: updated)
                            : _config.copyWith(centreLines: updated);
                      });
                    },
                  ),
                ),
                Text('${line.fontSize.toInt()}',
                    style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 12),
                FilterChip(
                  label: const Text('B',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  selected: line.bold,
                  onSelected: (val) {
                    setState(() {
                      final updated = List<HeaderTextLine>.from(lines);
                      updated[index] = updated[index].copyWith(bold: val);
                      _config = isLeft
                          ? _config.copyWith(leftLines: updated)
                          : _config.copyWith(centreLines: updated);
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addLine(bool isLeft) {
    final options = <_LineOption>[
      const _LineOption('companyName', 'Company Name'),
      const _LineOption('tagline', 'Tagline'),
      const _LineOption('address', 'Address'),
      const _LineOption('phone', 'Phone'),
      const _LineOption('engineerName', 'Engineer Name'),
      const _LineOption('custom', 'Custom Text'),
    ];

    showAdaptiveActionSheet(
      context: context,
      title: 'Add Text Line',
      options: options.map((opt) {
        return ActionSheetOption(
          label: opt.label,
          onTap: () {
            setState(() {
              final newLine = HeaderTextLine(
                key: opt.key,
                fontSize: opt.key == 'companyName' ? 18 : 10,
                bold: opt.key == 'companyName' || opt.key == 'tagline',
              );
              final lines = isLeft
                  ? List<HeaderTextLine>.from(_config.leftLines)
                  : List<HeaderTextLine>.from(_config.centreLines);
              lines.add(newLine);
              _config = isLeft
                  ? _config.copyWith(leftLines: lines)
                  : _config.copyWith(centreLines: lines);
            });
          },
        );
      }).toList(),
    );
  }

  String _labelForKey(String key) {
    switch (key) {
      case 'companyName': return 'Company Name';
      case 'tagline': return 'Tagline';
      case 'address': return 'Address';
      case 'phone': return 'Phone';
      case 'engineerName': return 'Engineer Name';
      case 'custom': return 'Custom Text';
      default: return key;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// FOOTER EDITOR — with live preview + zone tabs
// ═══════════════════════════════════════════════════════════════════

class _CompanyFooterEditorScreen extends StatefulWidget {
  final String companyId;
  final PdfDocumentType docType;
  final PdfFooterConfig initialConfig;
  final String title;

  const _CompanyFooterEditorScreen({
    required this.companyId,
    required this.docType,
    required this.initialConfig,
    required this.title,
  });

  @override
  State<_CompanyFooterEditorScreen> createState() => _CompanyFooterEditorState();
}

class _CompanyFooterEditorState extends State<_CompanyFooterEditorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late PdfFooterConfig _config;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _config = widget.initialConfig;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await CompanyPdfConfigService.instance.saveFooterConfig(
      widget.companyId,
      _config,
      widget.docType,
    );
    if (!mounted) return;
    context.showSuccessToast('Footer saved');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdaptiveNavigationBar(
        title: widget.title,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: AnimatedSaveButton(
              label: 'Save',
              onPressed: _save,
              outlined: true,
            ),
          ),
        ],
      ),
      body: KeyboardDismissWrapper(
        child: Center(
        child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 750),
        child: Column(
          children: [
            _buildPreview(),
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(icon: Icon(AppIcons.noteText), text: 'Left Zone'),
                Tab(icon: Icon(AppIcons.noteText), text: 'Centre'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildZoneTab(isLeft: true),
                  _buildZoneTab(isLeft: false),
                ],
              ),
            ),
          ],
        ),
        ),
        ),
      ),
    );
  }

  // ─── LIVE PREVIEW ───────────────────────────────────────────

  Widget _buildPreview() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preview',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFFE0E0E0), width: 1),
              ),
            ),
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _buildPreviewZone(isLeft: true),
                ),
                if (_config.centreLines.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: _buildPreviewZone(isLeft: false),
                  ),
                ],
                const SizedBox(width: 8),
                Text(
                  'Page 1 of 1',
                  style: TextStyle(fontSize: 7, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewZone({required bool isLeft}) {
    final lines = isLeft ? _config.leftLines : _config.centreLines;
    final textWidgets = <Widget>[];
    for (final line in lines) {
      if (line.value.isEmpty) continue;
      textWidgets.add(
        Text(
          line.value,
          style: TextStyle(
            fontSize: (line.fontSize * 0.55).clamp(5.0, 14.0),
            fontWeight: line.bold ? FontWeight.bold : FontWeight.normal,
            color: const Color(0xFF424242),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
    if (textWidgets.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: textWidgets,
    );
  }

  // ─── ZONE TABS ─────────────────────────────────────────────

  Widget _buildZoneTab({required bool isLeft}) {
    final lines = isLeft ? _config.leftLines : _config.centreLines;

    return Column(
      children: [
        Expanded(
          child: lines.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(AppIcons.noteText, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          isLeft
                              ? 'No text lines configured.\nTap "Add Text Line" to start.'
                              : 'The centre zone is empty by default.\nAdd text lines here for a two-column footer.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: lines.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final updated = List<HeaderTextLine>.from(lines);
                      final item = updated.removeAt(oldIndex);
                      updated.insert(newIndex, item);
                      _config = isLeft
                          ? _config.copyWith(leftLines: updated)
                          : _config.copyWith(centreLines: updated);
                    });
                  },
                  itemBuilder: (context, index) {
                    return _buildLineCard(
                      key: ValueKey('${isLeft ? "left" : "centre"}_$index'),
                      line: lines[index],
                      index: index,
                      isLeft: isLeft,
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _addLine(isLeft),
              icon: Icon(AppIcons.add),
              label: const Text('Add Text Line'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLineCard({
    required Key key,
    required HeaderTextLine line,
    required int index,
    required bool isLeft,
  }) {
    final lines = isLeft ? _config.leftLines : _config.centreLines;

    return Card(
      key: key,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(AppIcons.menu, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _labelForKey(line.key),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                IconButton(
                  icon: Icon(AppIcons.trash, size: 20),
                  color: Colors.red,
                  onPressed: () {
                    setState(() {
                      final updated = List<HeaderTextLine>.from(lines);
                      updated.removeAt(index);
                      _config = isLeft
                          ? _config.copyWith(leftLines: updated)
                          : _config.copyWith(centreLines: updated);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: line.value,
              decoration: const InputDecoration(
                labelText: 'Text',
                hintText: 'Enter text...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              textInputAction: TextInputAction.done,
              onChanged: (val) {
                final updated = List<HeaderTextLine>.from(lines);
                updated[index] = updated[index].copyWith(value: val);
                _config = isLeft
                    ? _config.copyWith(leftLines: updated)
                    : _config.copyWith(centreLines: updated);
                setState(() {});
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Size:', style: TextStyle(fontSize: 12)),
                Expanded(
                  child: AdaptiveSlider(
                    value: line.fontSize,
                    min: 6,
                    max: 14,
                    divisions: 8,
                    onChanged: (val) {
                      setState(() {
                        final updated = List<HeaderTextLine>.from(lines);
                        updated[index] = updated[index].copyWith(fontSize: val);
                        _config = isLeft
                            ? _config.copyWith(leftLines: updated)
                            : _config.copyWith(centreLines: updated);
                      });
                    },
                  ),
                ),
                Text('${line.fontSize.toInt()}',
                    style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 12),
                FilterChip(
                  label: const Text('B',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  selected: line.bold,
                  onSelected: (val) {
                    setState(() {
                      final updated = List<HeaderTextLine>.from(lines);
                      updated[index] = updated[index].copyWith(bold: val);
                      _config = isLeft
                          ? _config.copyWith(leftLines: updated)
                          : _config.copyWith(centreLines: updated);
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addLine(bool isLeft) {
    final options = <_LineOption>[
      const _LineOption('companyDetails', 'Company Details'),
      const _LineOption('contactInfo', 'Contact Info'),
      const _LineOption('website', 'Website'),
      const _LineOption('email', 'Email'),
      const _LineOption('custom', 'Custom Text'),
    ];

    showAdaptiveActionSheet(
      context: context,
      title: 'Add Text Line',
      options: options.map((opt) {
        return ActionSheetOption(
          label: opt.label,
          onTap: () {
            setState(() {
              final newLine = HeaderTextLine(key: opt.key, fontSize: 7);
              final lines = isLeft
                  ? List<HeaderTextLine>.from(_config.leftLines)
                  : List<HeaderTextLine>.from(_config.centreLines);
              lines.add(newLine);
              _config = isLeft
                  ? _config.copyWith(leftLines: lines)
                  : _config.copyWith(centreLines: lines);
            });
          },
        );
      }).toList(),
    );
  }

  String _labelForKey(String key) {
    switch (key) {
      case 'companyDetails': return 'Company Details';
      case 'contactInfo': return 'Contact Info';
      case 'website': return 'Website';
      case 'email': return 'Email';
      case 'custom': return 'Custom Text';
      default: return key;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// COLOUR SCHEME EDITOR — preset grid, custom picker, rich preview
// ═══════════════════════════════════════════════════════════════════

class _CompanyColourEditorScreen extends StatefulWidget {
  final String companyId;
  final PdfDocumentType docType;
  final PdfColourScheme initialScheme;
  final String title;

  const _CompanyColourEditorScreen({
    required this.companyId,
    required this.docType,
    required this.initialScheme,
    required this.title,
  });

  @override
  State<_CompanyColourEditorScreen> createState() => _CompanyColourEditorState();
}

class _CompanyColourEditorState extends State<_CompanyColourEditorScreen> {
  late PdfColourScheme _scheme;

  @override
  void initState() {
    super.initState();
    _scheme = widget.initialScheme;
  }

  Color get _primaryFlutterColor => Color(_scheme.primaryColorValue);

  Color _lightTint(Color c) => Color.lerp(c, Colors.white, 0.9)!;

  Color _mediumTint(Color c) => Color.lerp(c, Colors.white, 0.6)!;

  void _selectPreset(PdfColourScheme scheme) {
    setState(() => _scheme = scheme);
  }

  void _openCustomPicker() {
    Color pickerColor = _primaryFlutterColor;
    showPremiumDialog(
      context: context,
      child: Builder(
        builder: (context) => AlertDialog(
          title: const Text('Pick a colour'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: pickerColor,
              onColorChanged: (color) => pickerColor = color,
              enableAlpha: false,
              labelTypes: const [],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _scheme = PdfColourScheme(
                    primaryColorValue: pickerColor.toARGB32(),
                  );
                });
                Navigator.pop(context);
              },
              child: const Text('Select'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    await CompanyPdfConfigService.instance.saveColourScheme(
      widget.companyId,
      _scheme,
      widget.docType,
    );
    if (!mounted) return;
    context.showSuccessToast('Colour scheme saved');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AdaptiveNavigationBar(
        title: widget.title,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: AnimatedSaveButton(
              label: 'Save',
              onPressed: _save,
              outlined: true,
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 750),
        child: ListView(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        children: [
          // Preview mockup
          widget.docType == PdfDocumentType.invoice
              ? _buildInvoicePreview()
              : _buildJobsheetPreview(),
          const SizedBox(height: 24),

          // Preset schemes
          Text(
            'Preset Schemes',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildPresetGrid(isDark),
          const SizedBox(height: 24),

          // Custom colour picker button
          OutlinedButton.icon(
            onPressed: _openCustomPicker,
            icon: Icon(AppIcons.colorSwatch),
            label: const Text('Custom Colour'),
          ),
        ],
      ),
      ),
      ),
    );
  }

  // ─── PREVIEWS ──────────────────────────────────────────────

  Widget _buildJobsheetPreview() {
    final primary = _primaryFlutterColor;
    final light = _lightTint(primary);
    final textColor = AppTheme.textPrimary;
    final subtleText = AppTheme.textSecondary;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: primary, width: 2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('YOUR COMPANY',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primary)),
                      const SizedBox(height: 2),
                      Text('Professional Services',
                          style: TextStyle(fontSize: 9, color: subtleText)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('JOBSHEET',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _mockSectionHeader('JOB INFORMATION', primary),
                _mockFieldRow('Date:', '14/03/2026', light, false),
                _mockFieldRow('Engineer:', 'John Smith', light, true),
                _mockFieldRow('Job No:', 'JS-001', light, false),
                const SizedBox(height: 10),
                _mockSectionHeader('WORK DETAILS', primary),
                _mockFieldRow('System Type:', 'Conventional', light, false),
                _mockFieldRow('Panels Tested:', 'Yes', light, true),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    border: Border(
                      left: BorderSide(color: primary, width: 4),
                      top: BorderSide(color: Colors.grey.shade300, width: 0.5),
                      right: BorderSide(color: Colors.grey.shade300, width: 0.5),
                      bottom: BorderSide(color: Colors.grey.shade300, width: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CERTIFICATION STATEMENT',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: textColor)),
                      const SizedBox(height: 2),
                      Text('Work carried out in accordance with BS 5839-1.',
                          style: TextStyle(fontSize: 8, color: subtleText)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _mockSignatureBox('Engineer', light)),
                    const SizedBox(width: 12),
                    Expanded(child: _mockSignatureBox('Customer', light)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoicePreview() {
    final primary = _primaryFlutterColor;
    final light = _lightTint(primary);
    final textColor = AppTheme.textPrimary;
    final subtleText = AppTheme.textSecondary;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: primary, width: 2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('YOUR COMPANY',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primary)),
                      const SizedBox(height: 2),
                      Text('Professional Services',
                          style: TextStyle(fontSize: 9, color: subtleText)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('INVOICE',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Invoice No: INV-001', style: TextStyle(fontSize: 9, color: textColor)),
                      Text('Date: 01/01/2025', style: TextStyle(fontSize: 9, color: textColor)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: _mediumTint(primary).withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: primary,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(3),
                            topRight: Radius.circular(3),
                          ),
                        ),
                        child: Row(
                          children: const [
                            Expanded(flex: 3, child: Text('Description', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white))),
                            Expanded(child: Text('Qty', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center)),
                            Expanded(child: Text('Total', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.right)),
                          ],
                        ),
                      ),
                      _mockTableRow('Service item one', '1', '\u00A3250.00', textColor),
                      _mockTableRow('Service item two', '2', '\u00A3500.00', textColor),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('TOTAL: \u00A3750.00',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primary)),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: light,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Payment Details',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primary)),
                      const SizedBox(height: 2),
                      Text('Bank: Example Bank | Sort Code: 12-34-56',
                          style: TextStyle(fontSize: 8, color: subtleText)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── PREVIEW HELPERS ───────────────────────────────────────

  Widget _mockSectionHeader(String title, Color primary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: primary,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(4),
        ),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _mockFieldRow(String label, String value, Color light, bool isAlternate) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: isAlternate ? light : null,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 75,
            child: Text(label,
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 9, color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _mockSignatureBox(String label, Color light) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        const SizedBox(height: 4),
        Container(
          height: 28,
          decoration: BoxDecoration(
            color: light,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Center(
            child: Text('Signature', style: TextStyle(fontSize: 7, color: Colors.grey.shade400)),
          ),
        ),
      ],
    );
  }

  Widget _mockTableRow(String desc, String qty, String total, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(desc, style: TextStyle(fontSize: 9, color: textColor))),
          Expanded(child: Text(qty, style: TextStyle(fontSize: 9, color: textColor), textAlign: TextAlign.center)),
          Expanded(child: Text(total, style: TextStyle(fontSize: 9, color: textColor), textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  // ─── PRESET GRID ───────────────────────────────────────────

  Widget _buildPresetGrid(bool isDark) {
    return PresetColourGrid(
      selectedPrimaryColorValue: _scheme.primaryColorValue,
      isDark: isDark,
      onPresetSelected: _selectPreset,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SECTION STYLE EDITOR
// ═══════════════════════════════════════════════════════════════════

class _CompanySectionStyleEditorScreen extends StatefulWidget {
  final String companyId;
  final PdfDocumentType docType;
  final PdfSectionStyleConfig initialConfig;
  final String title;

  const _CompanySectionStyleEditorScreen({
    required this.companyId,
    required this.docType,
    required this.initialConfig,
    required this.title,
  });

  @override
  State<_CompanySectionStyleEditorScreen> createState() =>
      _CompanySectionStyleEditorState();
}

class _CompanySectionStyleEditorState
    extends State<_CompanySectionStyleEditorScreen> {
  late PdfSectionStyleConfig _config;

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig;
  }

  Future<void> _save() async {
    await CompanyPdfConfigService.instance.saveSectionStyleConfig(
      widget.companyId,
      _config,
      widget.docType,
    );
    if (!mounted) return;
    context.showSuccessToast('Section style saved');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AdaptiveNavigationBar(
        title: widget.title,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: AnimatedSaveButton(
              label: 'Save',
              onPressed: _save,
              outlined: true,
            ),
          ),
        ],
      ),
      body: KeyboardDismissWrapper(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 750),
            child: ListView(
              padding: const EdgeInsets.all(AppTheme.screenPadding),
              children: [
                // Card Style
                _buildSectionTitle('CARD STYLE', isDark),
                const SizedBox(height: 8),
                _buildCardStyleSelector(isDark),

                const SizedBox(height: 24),

                // Corner Radius
                _buildSectionTitle('CORNER RADIUS', isDark),
                const SizedBox(height: 8),
                _buildCornerRadiusSelector(isDark),

                const SizedBox(height: 24),

                // Header Style
                _buildSectionTitle('HEADER STYLE', isDark),
                const SizedBox(height: 8),
                _buildHeaderStyleSelector(isDark),

                const SizedBox(height: 24),

                // Spacing
                _buildSectionTitle('SECTION SPACING', isDark),
                const SizedBox(height: 8),
                _buildSlider(
                  value: _config.sectionSpacing,
                  min: 6,
                  max: 24,
                  divisions: 6,
                  onChanged: (value) {
                    setState(() {
                      _config = _config.copyWith(sectionSpacing: value);
                    });
                  },
                ),

                const SizedBox(height: 24),

                // Inner Padding
                _buildSectionTitle('INNER PADDING', isDark),
                const SizedBox(height: 8),
                _buildSlider(
                  value: _config.innerPadding,
                  min: 8,
                  max: 20,
                  divisions: 6,
                  onChanged: (value) {
                    setState(() {
                      _config = _config.copyWith(innerPadding: value);
                    });
                  },
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildCardStyleSelector(bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: SectionCardStyle.values.map((style) {
        final isSelected = _config.cardStyle == style;
        return ChoiceChip(
          label: Text(_cardStyleLabel(style)),
          selected: isSelected,
          onSelected: (_) {
            setState(() {
              _config = _config.copyWith(cardStyle: style);
            });
          },
        );
      }).toList(),
    );
  }

  String _cardStyleLabel(SectionCardStyle style) {
    switch (style) {
      case SectionCardStyle.bordered:
        return 'Bordered';
      case SectionCardStyle.shadowed:
        return 'Shadowed';
      case SectionCardStyle.elevated:
        return 'Elevated';
      case SectionCardStyle.flat:
        return 'Flat';
    }
  }

  Widget _buildCornerRadiusSelector(bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: SectionCornerRadius.values.map((radius) {
        final isSelected = _config.cornerRadius == radius;
        return ChoiceChip(
          label: Text(_cornerRadiusLabel(radius)),
          selected: isSelected,
          onSelected: (_) {
            setState(() {
              _config = _config.copyWith(cornerRadius: radius);
            });
          },
        );
      }).toList(),
    );
  }

  String _cornerRadiusLabel(SectionCornerRadius radius) {
    switch (radius) {
      case SectionCornerRadius.small:
        return 'Small (${radius.pixels.toInt()}px)';
      case SectionCornerRadius.medium:
        return 'Medium (${radius.pixels.toInt()}px)';
      case SectionCornerRadius.large:
        return 'Large (${radius.pixels.toInt()}px)';
    }
  }

  Widget _buildHeaderStyleSelector(bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: SectionHeaderStyle.values.map((style) {
        final isSelected = _config.headerStyle == style;
        return ChoiceChip(
          label: Text(_headerStyleLabel(style)),
          selected: isSelected,
          onSelected: (_) {
            setState(() {
              _config = _config.copyWith(headerStyle: style);
            });
          },
        );
      }).toList(),
    );
  }

  String _headerStyleLabel(SectionHeaderStyle style) {
    switch (style) {
      case SectionHeaderStyle.fullWidth:
        return 'Full Width';
      case SectionHeaderStyle.leftAccent:
        return 'Left Accent';
      case SectionHeaderStyle.underlined:
        return 'Underlined';
    }
  }

  Widget _buildSlider({
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 50,
          child: Text(
            '${value.toInt()}px',
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TYPOGRAPHY EDITOR
// ═══════════════════════════════════════════════════════════════════

class _CompanyTypographyEditorScreen extends StatefulWidget {
  final String companyId;
  final PdfDocumentType docType;
  final PdfTypographyConfig initialConfig;
  final String title;

  const _CompanyTypographyEditorScreen({
    required this.companyId,
    required this.docType,
    required this.initialConfig,
    required this.title,
  });

  @override
  State<_CompanyTypographyEditorScreen> createState() =>
      _CompanyTypographyEditorState();
}

class _CompanyTypographyEditorState
    extends State<_CompanyTypographyEditorScreen> {
  late PdfTypographyConfig _config;

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig;
  }

  Future<void> _save() async {
    await CompanyPdfConfigService.instance.saveTypographyConfig(
      widget.companyId,
      _config,
      widget.docType,
    );
    if (!mounted) return;
    context.showSuccessToast('Typography settings saved');
    Navigator.pop(context);
  }

  void _resetToDefaults() {
    setState(() {
      _config = PdfTypographyConfig.defaults();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AdaptiveNavigationBar(
        title: widget.title,
        actions: [
          IconButton(
            icon: Icon(AppIcons.refresh),
            onPressed: _resetToDefaults,
            tooltip: 'Reset to defaults',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: AnimatedSaveButton(
              label: 'Save',
              onPressed: _save,
              outlined: true,
            ),
          ),
        ],
      ),
      body: KeyboardDismissWrapper(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 750),
            child: ListView(
              padding: const EdgeInsets.all(AppTheme.screenPadding),
              children: [
                Text(
                  'Adjust font sizes throughout your PDF documents.',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                _buildFontSizeSlider(
                  title: 'Section Headers',
                  value: _config.sectionHeaderSize,
                  min: 8,
                  max: 16,
                  onChanged: (value) {
                    setState(() {
                      _config = _config.copyWith(sectionHeaderSize: value);
                    });
                  },
                ),

                _buildFontSizeSlider(
                  title: 'Field Labels',
                  value: _config.fieldLabelSize,
                  min: 6,
                  max: 12,
                  onChanged: (value) {
                    setState(() {
                      _config = _config.copyWith(fieldLabelSize: value);
                    });
                  },
                ),

                _buildFontSizeSlider(
                  title: 'Field Values',
                  value: _config.fieldValueSize,
                  min: 8,
                  max: 14,
                  onChanged: (value) {
                    setState(() {
                      _config = _config.copyWith(fieldValueSize: value);
                    });
                  },
                ),

                _buildFontSizeSlider(
                  title: 'Table Headers',
                  value: _config.tableHeaderSize,
                  min: 7,
                  max: 12,
                  onChanged: (value) {
                    setState(() {
                      _config = _config.copyWith(tableHeaderSize: value);
                    });
                  },
                ),

                _buildFontSizeSlider(
                  title: 'Table Body',
                  value: _config.tableBodySize,
                  min: 7,
                  max: 12,
                  onChanged: (value) {
                    setState(() {
                      _config = _config.copyWith(tableBodySize: value);
                    });
                  },
                ),

                _buildFontSizeSlider(
                  title: 'Footer Text',
                  value: _config.footerSize,
                  min: 6,
                  max: 10,
                  onChanged: (value) {
                    setState(() {
                      _config = _config.copyWith(footerSize: value);
                    });
                  },
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFontSizeSlider({
    required String title,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color:
                      isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                ),
              ),
              Text(
                '${value.toInt()}pt',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).toInt(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _LineOption {
  final String key;
  final String label;
  const _LineOption(this.key, this.label);
}
