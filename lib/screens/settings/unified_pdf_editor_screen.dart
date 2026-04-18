import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/pdf_header_config.dart';
import '../../models/pdf_footer_config.dart';
import '../../models/pdf_colour_scheme.dart';
import '../../models/pdf_section_style_config.dart';
import '../../models/pdf_typography_config.dart';
import '../../models/pdf_style_preset.dart';
import '../../services/pdf_header_config_service.dart';
import '../../services/pdf_footer_config_service.dart';
import '../../services/pdf_colour_scheme_service.dart';
import '../../services/pdf_section_style_service.dart';
import '../../services/pdf_typography_service.dart';
import '../../services/branding_service.dart';
import '../../services/company_pdf_config_service.dart';
import '../../utils/icon_map.dart';
import '../../utils/theme.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/unified_pdf_preview.dart';
import '../../widgets/animated_save_button.dart';
import '../../widgets/premium_toast.dart';
import '../../widgets/premium_dialog.dart';
import '../../widgets/adaptive_app_bar.dart';
import '../../widgets/keyboard_dismiss_wrapper.dart';
import '../../widgets/preset_colour_grid.dart';

/// Unified PDF editor screen with Template, Header, and Footer tabs.
class UnifiedPdfEditorScreen extends StatefulWidget {
  final PdfDocumentType docType;
  final bool isCompany;
  final String? companyId;

  const UnifiedPdfEditorScreen({
    super.key,
    required this.docType,
    this.isCompany = false,
    this.companyId,
  }) : assert(!isCompany || companyId != null,
            'companyId is required when isCompany is true');

  @override
  State<UnifiedPdfEditorScreen> createState() => _UnifiedPdfEditorScreenState();
}

class _UnifiedPdfEditorScreenState extends State<UnifiedPdfEditorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // All configs
  PdfHeaderConfig _headerConfig = PdfHeaderConfig.defaults();
  PdfFooterConfig _footerConfig = PdfFooterConfig.defaults();
  PdfColourScheme _colourScheme = PdfColourScheme.defaults();
  PdfSectionStyleConfig _sectionStyle = PdfSectionStyleConfig.defaults();
  PdfTypographyConfig _typography = PdfTypographyConfig.defaults();

  // Logo
  String? _logoPath;
  Uint8List? _logoBytes;

  // Selected template preset
  PdfStylePreset? _selectedPreset;

  bool _isLoading = true;

  String get _title {
    final docName =
        widget.docType == PdfDocumentType.jobsheet ? 'Jobsheet' : 'Invoice';
    return widget.isCompany ? 'Company $docName PDF' : '$docName PDF Design';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllConfigs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllConfigs() async {
    try {
      if (widget.isCompany) {
        await _loadCompanyConfigs();
      } else {
        await _loadPersonalConfigs();
      }

      // Detect which preset matches the current configs
      _selectedPreset = PdfStylePresetExtension.matchFromConfigs(
        header: _headerConfig,
        sectionStyle: _sectionStyle,
        typography: _typography,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadPersonalConfigs() async {
    final results = await Future.wait([
      PdfHeaderConfigService.getConfig(widget.docType),
      PdfFooterConfigService.getConfig(widget.docType),
      PdfColourSchemeService.getScheme(widget.docType),
      PdfSectionStyleService.getConfig(widget.docType),
      PdfTypographyService.getConfig(widget.docType),
      BrandingService.getLogoPath(widget.docType),
    ]);

    _headerConfig = results[0] as PdfHeaderConfig;
    _footerConfig = results[1] as PdfFooterConfig;
    _colourScheme = results[2] as PdfColourScheme;
    _sectionStyle = results[3] as PdfSectionStyleConfig;
    _typography = results[4] as PdfTypographyConfig;
    _logoPath = results[5] as String?;

    // Load logo bytes for preview
    if (_logoPath != null && !kIsWeb) {
      final file = File(_logoPath!);
      if (await file.exists()) {
        _logoBytes = await file.readAsBytes();
      }
    }
  }

  Future<void> _loadCompanyConfigs() async {
    final service = CompanyPdfConfigService.instance;
    final companyId = widget.companyId!;

    final results = await Future.wait([
      service.getHeaderConfig(companyId, widget.docType),
      service.getFooterConfig(companyId, widget.docType),
      service.getColourScheme(companyId, widget.docType),
      service.getSectionStyleConfig(companyId, widget.docType),
      service.getTypographyConfig(companyId, widget.docType),
      service.getCompanyLogoBytes(companyId, widget.docType),
    ]);

    _headerConfig =
        (results[0] as PdfHeaderConfig?) ?? PdfHeaderConfig.defaults();
    _footerConfig =
        (results[1] as PdfFooterConfig?) ?? PdfFooterConfig.defaults();
    _colourScheme =
        (results[2] as PdfColourScheme?) ?? PdfColourScheme.defaults();
    _sectionStyle = (results[3] as PdfSectionStyleConfig?) ??
        PdfSectionStyleConfig.defaults();
    _typography =
        (results[4] as PdfTypographyConfig?) ?? PdfTypographyConfig.defaults();
    _logoBytes = results[5] as Uint8List?;
  }

  Future<void> _saveAll() async {
    try {
      if (widget.isCompany) {
        await _saveCompanyConfigs();
      } else {
        await _savePersonalConfigs();
      }

      if (!mounted) return;
      context.showSuccessToast('PDF design saved');
    } catch (e) {
      if (!mounted) return;
      context.showErrorToast('Error saving: $e');
    }
  }

  Future<void> _savePersonalConfigs() async {
    await Future.wait([
      PdfHeaderConfigService.saveConfig(_headerConfig, widget.docType),
      PdfFooterConfigService.saveConfig(_footerConfig, widget.docType),
      PdfColourSchemeService.saveScheme(_colourScheme, widget.docType),
      PdfSectionStyleService.saveConfig(_sectionStyle, widget.docType),
      PdfTypographyService.saveConfig(_typography, widget.docType),
    ]);
  }

  Future<void> _saveCompanyConfigs() async {
    final service = CompanyPdfConfigService.instance;
    final companyId = widget.companyId!;

    await Future.wait([
      service.saveHeaderConfig(companyId, _headerConfig, widget.docType),
      service.saveFooterConfig(companyId, _footerConfig, widget.docType),
      service.saveColourScheme(companyId, _colourScheme, widget.docType),
      service.saveSectionStyleConfig(
          companyId, _sectionStyle, widget.docType),
      service.saveTypographyConfig(companyId, _typography, widget.docType),
    ]);
  }

  void _applyPreset(PdfStylePreset preset) {
    setState(() {
      _selectedPreset = preset;
      _headerConfig = preset.applyToHeaderConfig(_headerConfig);
      _sectionStyle = preset.sectionStyleConfig;
      _typography = preset.typographyConfig;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AdaptiveNavigationBar(
        title: _title,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: AnimatedSaveButton(
              label: 'Save',
              onPressed: _saveAll,
              outlined: true,
            ),
          ),
        ],
      ),
      body: KeyboardDismissWrapper(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: _isLoading
                ? const AdaptiveLoadingIndicator()
                : Column(
                children: [
                  // Preview section (40% of available height)
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: UnifiedPdfPreview(
                        docType: widget.docType,
                        headerConfig: _headerConfig,
                        footerConfig: _footerConfig,
                        colourScheme: _colourScheme,
                        sectionStyle: _sectionStyle,
                        typography: _typography,
                        logoBytes: _logoBytes,
                      ),
                    ),
                  ),

                  // Tab bar
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.darkSurfaceElevated
                          : Colors.grey.shade100,
                      border: Border(
                        top: BorderSide(
                            color: Colors.grey.shade300, width: 0.5),
                        bottom: BorderSide(
                            color: Colors.grey.shade300, width: 0.5),
                      ),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      tabs: const [
                        Tab(text: 'Template'),
                        Tab(text: 'Header'),
                        Tab(text: 'Footer'),
                      ],
                    ),
                  ),

                  // Tab content (60% of available height)
                  Expanded(
                    flex: 6,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTemplateTab(isDark),
                        _buildHeaderTab(isDark),
                        _buildFooterTab(isDark),
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

  // ═══════════════════════════════════════════════════════════════════
  // TEMPLATE TAB
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildTemplateTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionLabel('TEMPLATE STYLE', isDark),
        const SizedBox(height: 8),
        _buildPresetGrid(isDark),

        const SizedBox(height: 24),

        _buildSectionLabel('COLOUR SCHEME', isDark),
        const SizedBox(height: 8),
        PresetColourGrid(
          selectedPrimaryColorValue: _colourScheme.primaryColorValue,
          isDark: isDark,
          onPresetSelected: (scheme) {
            setState(() => _colourScheme = scheme);
          },
        ),

        const SizedBox(height: 16),

        OutlinedButton.icon(
          onPressed: _openColourPicker,
          icon: Icon(AppIcons.colorSwatch),
          label: const Text('Pick Custom Colour'),
        ),

        const SizedBox(height: 12),

        // Current colour preview
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(_colourScheme.primaryColorValue),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade400),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Primary: #${_colourScheme.primaryColorValue.toRadixString(16).substring(2).toUpperCase()}',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color:
                      isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPresetGrid(bool isDark) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: PdfStylePreset.values.map((preset) {
        final isSelected = _selectedPreset == preset;
        return _buildPresetCard(preset, isSelected, isDark);
      }).toList(),
    );
  }

  Widget _buildPresetCard(
      PdfStylePreset preset, bool isSelected, bool isDark) {
    final primaryColor = Color(_colourScheme.primaryColorValue);

    return GestureDetector(
      onTap: () => _applyPreset(preset),
      child: AnimatedContainer(
        duration: AppTheme.fastAnimation,
        curve: AppTheme.defaultCurve,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      preset.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? primaryColor
                            : isDark
                                ? AppTheme.darkTextPrimary
                                : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(AppIcons.tickCircle, color: primaryColor, size: 20),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                preset.description,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              _buildPresetMiniPreview(preset, isDark),
            ],
          ),
        ),
      ),
    );
  }

  /// A small visual indicator showing the preset's card/header style
  Widget _buildPresetMiniPreview(PdfStylePreset preset, bool isDark) {
    final primaryColor = Color(_colourScheme.primaryColorValue);
    final config = preset.sectionStyleConfig;

    return SizedBox(
      height: 20,
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(config.cornerRadius.pixels * 0.5),
                border: config.cardStyle == SectionCardStyle.bordered
                    ? Border.all(color: Colors.grey.shade300, width: 1)
                    : null,
                boxShadow: config.cardStyle == SectionCardStyle.shadowed ||
                        config.cardStyle == SectionCardStyle.elevated
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 2,
                        ),
                      ]
                    : null,
                color: config.cardStyle == SectionCardStyle.flat
                    ? primaryColor.withValues(alpha: 0.1)
                    : isDark
                        ? AppTheme.darkSurfaceElevated
                        : Colors.white,
              ),
              child: Row(
                children: [
                  if (config.headerStyle == SectionHeaderStyle.fullWidth)
                    Container(
                      width: 40,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(
                              config.cornerRadius.pixels * 0.5),
                          bottomLeft: Radius.circular(
                              config.cornerRadius.pixels * 0.5),
                        ),
                      ),
                    ),
                  if (config.headerStyle == SectionHeaderStyle.leftAccent)
                    Container(
                      width: 3,
                      color: primaryColor,
                    ),
                  if (config.headerStyle == SectionHeaderStyle.underlined)
                    Container(
                      width: 40,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: primaryColor, width: 1),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openColourPicker() {
    Color pickerColor = Color(_colourScheme.primaryColorValue);

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
                  _colourScheme = PdfColourScheme(
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

  // ═══════════════════════════════════════════════════════════════════
  // HEADER TAB
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildHeaderTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Logo section
        _buildSectionLabel('LOGO', isDark),
        const SizedBox(height: 8),
        _buildLogoUploader(isDark),
        const SizedBox(height: 16),

        // Logo placement
        _buildSectionLabel('LOGO PLACEMENT', isDark),
        const SizedBox(height: 8),
        SegmentedButton<LogoZone>(
          segments: const [
            ButtonSegment(value: LogoZone.left, label: Text('Left')),
            ButtonSegment(value: LogoZone.centre, label: Text('Centre')),
            ButtonSegment(value: LogoZone.none, label: Text('None')),
          ],
          selected: {_headerConfig.logoZone},
          onSelectionChanged: (selection) {
            setState(() {
              _headerConfig =
                  _headerConfig.copyWith(logoZone: selection.first);
            });
          },
        ),
        const SizedBox(height: 16),

        // Logo size
        _buildSectionLabel('LOGO SIZE', isDark),
        const SizedBox(height: 8),
        SegmentedButton<LogoSize>(
          segments: const [
            ButtonSegment(value: LogoSize.small, label: Text('Small')),
            ButtonSegment(value: LogoSize.medium, label: Text('Medium')),
            ButtonSegment(value: LogoSize.large, label: Text('Large')),
          ],
          selected: {_headerConfig.logoSize},
          onSelectionChanged: (selection) {
            setState(() {
              _headerConfig =
                  _headerConfig.copyWith(logoSize: selection.first);
            });
          },
        ),
        const SizedBox(height: 24),

        // Header text - Left Zone
        _buildSectionLabel('HEADER TEXT \u2014 LEFT ZONE', isDark),
        const SizedBox(height: 8),
        _buildHeaderLinesList(isLeft: true, isDark: isDark),
        const SizedBox(height: 8),
        _buildAddHeaderLineButton(isLeft: true),

        const SizedBox(height: 24),

        // Header text - Centre Zone
        _buildSectionLabel('HEADER TEXT \u2014 CENTRE ZONE (OPTIONAL)', isDark),
        const SizedBox(height: 8),
        _buildHeaderLinesList(isLeft: false, isDark: isDark),
        const SizedBox(height: 8),
        _buildAddHeaderLineButton(isLeft: false),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildHeaderLinesList({required bool isLeft, required bool isDark}) {
    final lines =
        isLeft ? _headerConfig.leftLines : _headerConfig.centreLines;

    if (lines.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            'No lines added',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ),
      );
    }

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: lines.length,
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex--;
        final updated = List<HeaderTextLine>.from(lines);
        final item = updated.removeAt(oldIndex);
        updated.insert(newIndex, item);
        setState(() {
          _headerConfig = isLeft
              ? _headerConfig.copyWith(leftLines: updated)
              : _headerConfig.copyWith(centreLines: updated);
        });
      },
      itemBuilder: (context, index) {
        final line = lines[index];
        return _buildHeaderLineCard(
          key: ValueKey('${isLeft ? 'left' : 'centre'}_$index'),
          line: line,
          index: index,
          isLeft: isLeft,
          isDark: isDark,
        );
      },
    );
  }

  Widget _buildHeaderLineCard({
    required Key key,
    required HeaderTextLine line,
    required int index,
    required bool isLeft,
    required bool isDark,
  }) {
    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(AppIcons.menu, size: 18, color: Colors.grey.shade400),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _labelForLineKey(line.key),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    initialValue: line.value,
                    decoration: InputDecoration(
                      hintText: _hintForLineKey(line.key),
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                    ),
                    style: const TextStyle(fontSize: 14),
                    onChanged: (val) =>
                        _updateHeaderLine(index, isLeft, val),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(AppIcons.trash, size: 18),
              color: Colors.red,
              onPressed: () => _removeHeaderLine(index, isLeft),
            ),
          ],
        ),
      ),
    );
  }

  void _updateHeaderLine(int index, bool isLeft, String value) {
    final lines =
        isLeft ? _headerConfig.leftLines : _headerConfig.centreLines;
    final updated = List<HeaderTextLine>.from(lines);
    updated[index] = updated[index].copyWith(value: value);
    setState(() {
      _headerConfig = isLeft
          ? _headerConfig.copyWith(leftLines: updated)
          : _headerConfig.copyWith(centreLines: updated);
    });
  }

  void _removeHeaderLine(int index, bool isLeft) {
    final lines =
        isLeft ? _headerConfig.leftLines : _headerConfig.centreLines;
    final updated = List<HeaderTextLine>.from(lines);
    updated.removeAt(index);
    setState(() {
      _headerConfig = isLeft
          ? _headerConfig.copyWith(leftLines: updated)
          : _headerConfig.copyWith(centreLines: updated);
    });
  }

  Widget _buildAddHeaderLineButton({required bool isLeft}) {
    return OutlinedButton.icon(
      onPressed: () => _addHeaderLine(isLeft),
      icon: Icon(AppIcons.add),
      label: const Text('Add Text Line'),
    );
  }

  void _addHeaderLine(bool isLeft) {
    final options = [
      ('companyName', 'Company Name', 18.0, true),
      ('tagline', 'Tagline', 10.0, true),
      ('address', 'Address', 9.0, false),
      ('phone', 'Phone', 9.0, false),
      ('engineerName', 'Engineer Name', 10.0, false),
      ('custom', 'Custom Text', 9.0, false),
    ];

    showAdaptiveActionSheet(
      context: context,
      title: 'Add Header Line',
      options: options.map((opt) {
        return ActionSheetOption(
          label: opt.$2,
          onTap: () {
            final newLine = HeaderTextLine(
              key: opt.$1,
              fontSize: opt.$3,
              bold: opt.$4,
            );
            final lines = isLeft
                ? _headerConfig.leftLines
                : _headerConfig.centreLines;
            final updated = List<HeaderTextLine>.from(lines)..add(newLine);
            setState(() {
              _headerConfig = isLeft
                  ? _headerConfig.copyWith(leftLines: updated)
                  : _headerConfig.copyWith(centreLines: updated);
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildLogoUploader(bool isDark) {
    final hasLogo = _logoBytes != null || _logoPath != null;

    return Container(
      height: 100,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
        ),
      ),
      child: hasLogo
          ? Stack(
              children: [
                Center(
                  child: _logoBytes != null
                      ? Image.memory(_logoBytes!, fit: BoxFit.contain)
                      : (_logoPath != null && !kIsWeb)
                          ? Image.file(File(_logoPath!),
                              fit: BoxFit.contain)
                          : const SizedBox.shrink(),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton.filled(
                    onPressed: _removeLogo,
                    icon: Icon(AppIcons.trash, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            )
          : InkWell(
              onTap: _pickLogo,
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(AppIcons.image, size: 32, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to upload logo',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
    );
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

    if (widget.isCompany) {
      await CompanyPdfConfigService.instance
          .saveCompanyLogo(widget.companyId!, bytes, widget.docType);
    } else {
      // Clear cached image before saving
      if (_logoPath != null && !kIsWeb) {
        imageCache.evict(FileImage(File(_logoPath!)));
      }
      await BrandingService.saveLogo(picked.path, widget.docType);
      _logoPath = await BrandingService.getLogoPath(widget.docType);
    }

    setState(() => _logoBytes = bytes);

    if (mounted) context.showSuccessToast('Logo saved');
  }

  Future<void> _removeLogo() async {
    final confirm = await showAdaptiveAlertDialog<bool>(
      context: context,
      title: 'Remove Logo',
      message: 'Are you sure you want to remove the logo?',
      confirmLabel: 'Remove',
      cancelLabel: 'Cancel',
      isDestructive: true,
    );

    if (confirm != true) return;

    if (widget.isCompany) {
      await CompanyPdfConfigService.instance
          .removeCompanyLogo(widget.companyId!, widget.docType);
    } else {
      if (_logoPath != null && !kIsWeb) {
        imageCache.evict(FileImage(File(_logoPath!)));
      }
      await BrandingService.removeLogo(widget.docType);
      _logoPath = null;
    }

    setState(() => _logoBytes = null);
  }

  // ═══════════════════════════════════════════════════════════════════
  // FOOTER TAB
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildFooterTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Footer text appears at the bottom of every page.',
          style: TextStyle(
            fontSize: 14,
            color:
                isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 16),

        _buildSectionLabel('LEFT ZONE', isDark),
        const SizedBox(height: 8),
        _buildFooterLinesList(isLeft: true, isDark: isDark),
        const SizedBox(height: 8),
        _buildAddFooterLineButton(isLeft: true),

        const SizedBox(height: 24),

        _buildSectionLabel('CENTRE ZONE', isDark),
        const SizedBox(height: 8),
        _buildFooterLinesList(isLeft: false, isDark: isDark),
        const SizedBox(height: 8),
        _buildAddFooterLineButton(isLeft: false),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildFooterLinesList({required bool isLeft, required bool isDark}) {
    final lines =
        isLeft ? _footerConfig.leftLines : _footerConfig.centreLines;

    if (lines.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            'No lines added',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ),
      );
    }

    return Column(
      children: lines.asMap().entries.map((entry) {
        final index = entry.key;
        final line = entry.value;
        return _buildFooterLineCard(
          line: line,
          index: index,
          isLeft: isLeft,
          isDark: isDark,
        );
      }).toList(),
    );
  }

  Widget _buildFooterLineCard({
    required HeaderTextLine line,
    required int index,
    required bool isLeft,
    required bool isDark,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _labelForLineKey(line.key),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: Icon(AppIcons.trash, size: 18),
                  color: Colors.red,
                  onPressed: () => _removeFooterLine(index, isLeft),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: line.value,
              decoration: const InputDecoration(
                labelText: 'Text',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (val) => _updateFooterLine(index, isLeft, val),
            ),
          ],
        ),
      ),
    );
  }

  void _updateFooterLine(int index, bool isLeft, String value) {
    final lines =
        isLeft ? _footerConfig.leftLines : _footerConfig.centreLines;
    final updated = List<HeaderTextLine>.from(lines);
    updated[index] = updated[index].copyWith(value: value);
    setState(() {
      _footerConfig = isLeft
          ? _footerConfig.copyWith(leftLines: updated)
          : _footerConfig.copyWith(centreLines: updated);
    });
  }

  void _removeFooterLine(int index, bool isLeft) {
    final lines =
        isLeft ? _footerConfig.leftLines : _footerConfig.centreLines;
    final updated = List<HeaderTextLine>.from(lines);
    updated.removeAt(index);
    setState(() {
      _footerConfig = isLeft
          ? _footerConfig.copyWith(leftLines: updated)
          : _footerConfig.copyWith(centreLines: updated);
    });
  }

  Widget _buildAddFooterLineButton({required bool isLeft}) {
    return OutlinedButton.icon(
      onPressed: () => _addFooterLine(isLeft),
      icon: Icon(AppIcons.add),
      label: const Text('Add Line'),
    );
  }

  void _addFooterLine(bool isLeft) {
    final options = [
      ('companyDetails', 'Company Details'),
      ('custom', 'Custom Text'),
    ];

    showAdaptiveActionSheet(
      context: context,
      title: 'Add Footer Line',
      options: options.map((opt) {
        return ActionSheetOption(
          label: opt.$2,
          onTap: () {
            final newLine = HeaderTextLine(key: opt.$1, fontSize: 7);
            final lines =
                isLeft ? _footerConfig.leftLines : _footerConfig.centreLines;
            final updated = List<HeaderTextLine>.from(lines)..add(newLine);
            setState(() {
              _footerConfig = isLeft
                  ? _footerConfig.copyWith(leftLines: updated)
                  : _footerConfig.copyWith(centreLines: updated);
            });
          },
        );
      }).toList(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // HELPER WIDGETS
  // ═══════════════════════════════════════════════════════════════════

  String _labelForLineKey(String key) {
    switch (key) {
      case 'companyName':
        return 'Company Name';
      case 'tagline':
        return 'Tagline';
      case 'address':
        return 'Address';
      case 'phone':
        return 'Phone';
      case 'engineerName':
        return 'Engineer Name';
      case 'companyDetails':
        return 'Company Details';
      case 'custom':
        return 'Custom Text';
      default:
        return key;
    }
  }

  String _hintForLineKey(String key) {
    switch (key) {
      case 'companyName':
        return 'Your Company Name';
      case 'tagline':
        return 'Your tagline or slogan';
      case 'address':
        return '123 Example Street, City';
      case 'phone':
        return '01234 567 890';
      case 'engineerName':
        return 'Auto-filled from profile';
      case 'custom':
        return 'Enter custom text';
      default:
        return '';
    }
  }

  Widget _buildSectionLabel(String title, bool isDark) {
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
}
