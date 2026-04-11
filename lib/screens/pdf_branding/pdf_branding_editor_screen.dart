import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/pdf_branding_config.dart';
import '../../models/pdf_colour_scheme_v2.dart';
import '../../models/pdf_content_block.dart';
import '../../models/pdf_font_config.dart';
import '../../models/pdf_header_config.dart' show LogoSize, PdfDocumentType;
import '../../models/pdf_layout_template.dart';
import '../../models/pdf_variable.dart';
import '../../services/branding_service.dart';
import '../../services/pdf_branding_editor_adapter.dart';
import '../../utils/adaptive_widgets.dart';
import '../../utils/icon_map.dart';
import '../../utils/theme.dart';
import '../../widgets/adaptive_app_bar.dart';
import '../../widgets/animated_save_button.dart';
import '../../widgets/keyboard_dismiss_wrapper.dart';
import '../../widgets/premium_dialog.dart';
import '../../widgets/premium_toast.dart';
import 'branding_live_preview.dart';
import 'content_block_editor_card.dart';
import 'template_preset_selector.dart';

/// Unified PDF branding editor screen.
///
/// Takes a [PdfBrandingEditorAdapter] so the same UI works for both
/// personal and company configs. Replaces the old header/footer/colour
/// designer screens with a single unified editor.
class PdfBrandingEditorScreen extends StatefulWidget {
  final PdfBrandingEditorAdapter adapter;
  final PdfDocumentType docType;

  const PdfBrandingEditorScreen({
    super.key,
    required this.adapter,
    required this.docType,
  });

  @override
  State<PdfBrandingEditorScreen> createState() =>
      _PdfBrandingEditorScreenState();
}

class _PdfBrandingEditorScreenState extends State<PdfBrandingEditorScreen> {
  late PdfBrandingConfig _config;
  Uint8List? _logoBytes;
  bool _isLoading = true;
  String? _expandedBlockId;

  @override
  void initState() {
    super.initState();
    _config = PdfBrandingConfig.defaults();
    _loadData();
  }

  Future<void> _loadData() async {
    final config = await widget.adapter.loadConfig(widget.docType);
    final logo = await widget.adapter.loadLogo(widget.docType);
    if (mounted) {
      setState(() {
        _config = config;
        _logoBytes = logo;
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    try {
      await widget.adapter.saveConfig(_config, widget.docType);
      if (mounted) context.showSuccessToast('Branding saved');
    } catch (e) {
      if (mounted) context.showErrorToast('Error saving: $e');
    }
  }

  void _updateConfig(PdfBrandingConfig config) {
    setState(() => _config = config);
  }

  // ── Logo handling ──

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

    final picked =
        await picker.pickImage(source: source!, maxWidth: 512, maxHeight: 512);
    if (picked == null) return;

    // For personal adapter, use BrandingService directly (needs file path)
    if (widget.adapter is PersonalBrandingAdapter) {
      await BrandingService.saveLogo(picked.path, widget.docType);
      final bytes = await BrandingService.getLogoBytes(widget.docType);
      setState(() => _logoBytes = bytes);
    } else {
      // Company adapter: read bytes and save via adapter
      final bytes = await picked.readAsBytes();
      await widget.adapter.saveLogo(bytes, widget.docType);
      setState(() => _logoBytes = bytes);
    }

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

    await widget.adapter.removeLogo(widget.docType);
    setState(() => _logoBytes = null);
  }

  // ── Preset application ──

  void _applyPreset(PdfBrandingConfig preset) {
    // If user has custom blocks, ask before overwriting
    final hasCustomContent = _config.headerLeftBlocks.isNotEmpty ||
        _config.headerRightBlocks.isNotEmpty ||
        _config.footerLeftBlocks.isNotEmpty;

    if (hasCustomContent) {
      showAdaptiveAlertDialog<String>(
        context: context,
        title: 'Apply Template',
        message:
            'Apply layout structure only, or reset all content to the template defaults?',
        confirmLabel: 'Reset All',
        cancelLabel: 'Layout Only',
      ).then((result) {
        if (result == null) return;
        setState(() {
          _config = preset.copyWith(
            // Preserve existing logo size if only changing layout
          );
        });
      });
    } else {
      setState(() => _config = preset);
    }
  }

  // ── Block management ──

  void _addBlock(String zone) {
    _showBlockTypePicker((type) {
      final block = switch (type) {
        ContentBlockType.text => ContentBlock.variable(
            variable: PdfVariable.custom,
            fontSize: 10,
          ),
        ContentBlockType.divider => ContentBlock.divider(),
        ContentBlockType.spacer => ContentBlock.spacer(),
        ContentBlockType.logo => ContentBlock.logo(),
      };

      setState(() {
        _config = _updateZoneBlocks(zone, [..._getZoneBlocks(zone), block]);
        _expandedBlockId = block.id;
      });
    });
  }

  void _showBlockTypePicker(ValueChanged<ContentBlockType> onSelected) {
    showAdaptiveActionSheet(
      context: context,
      title: 'Add Block',
      options: [
        ActionSheetOption(
          label: 'Text',
          icon: AppIcons.editNote,
          onTap: () => onSelected(ContentBlockType.text),
        ),
        ActionSheetOption(
          label: 'Divider',
          icon: Icons.horizontal_rule,
          onTap: () => onSelected(ContentBlockType.divider),
        ),
        ActionSheetOption(
          label: 'Spacer',
          icon: AppIcons.arrowDown,
          onTap: () => onSelected(ContentBlockType.spacer),
        ),
      ],
    );
  }

  List<ContentBlock> _getZoneBlocks(String zone) => switch (zone) {
        'headerLeft' => _config.headerLeftBlocks,
        'headerCentre' => _config.headerCentreBlocks,
        'headerRight' => _config.headerRightBlocks,
        'footerLeft' => _config.footerLeftBlocks,
        'footerCentre' => _config.footerCentreBlocks,
        'footerRight' => _config.footerRightBlocks,
        _ => [],
      };

  PdfBrandingConfig _updateZoneBlocks(String zone, List<ContentBlock> blocks) =>
      switch (zone) {
        'headerLeft' => _config.copyWith(headerLeftBlocks: blocks),
        'headerCentre' => _config.copyWith(headerCentreBlocks: blocks),
        'headerRight' => _config.copyWith(headerRightBlocks: blocks),
        'footerLeft' => _config.copyWith(footerLeftBlocks: blocks),
        'footerCentre' => _config.copyWith(footerCentreBlocks: blocks),
        'footerRight' => _config.copyWith(footerRightBlocks: blocks),
        _ => _config,
      };

  void _onBlockChanged(String zone, int index, ContentBlock updated) {
    final blocks = List<ContentBlock>.from(_getZoneBlocks(zone));
    blocks[index] = updated;
    setState(() => _config = _updateZoneBlocks(zone, blocks));
  }

  void _onBlockDeleted(String zone, int index) {
    final blocks = List<ContentBlock>.from(_getZoneBlocks(zone));
    blocks.removeAt(index);
    setState(() => _config = _updateZoneBlocks(zone, blocks));
  }

  void _onBlocksReordered(String zone, int oldIndex, int newIndex) {
    final blocks = List<ContentBlock>.from(_getZoneBlocks(zone));
    if (newIndex > oldIndex) newIndex--;
    final block = blocks.removeAt(oldIndex);
    blocks.insert(newIndex, block);
    setState(() => _config = _updateZoneBlocks(zone, blocks));
  }

  // ── Colour picker ──

  void _openColourPicker({required bool isPrimary}) {
    final currentColor = isPrimary
        ? Color(_config.colourScheme.primaryColorValue)
        : (_config.colourScheme.hasSecondary
            ? Color(_config.colourScheme.secondaryColorValue!)
            : Color(_config.colourScheme.primaryColorValue));

    Color pickerColor = currentColor;
    showPremiumDialog(
      context: context,
      child: Builder(
        builder: (ctx) => AlertDialog(
          title: Text(isPrimary ? 'Primary Colour' : 'Secondary Colour'),
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
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            if (!isPrimary)
              TextButton(
                onPressed: () {
                  _updateConfig(_config.copyWith(
                    colourScheme: _config.colourScheme.copyWith(
                      clearSecondary: true,
                    ),
                  ));
                  Navigator.pop(ctx);
                },
                child: const Text('Remove'),
              ),
            ElevatedButton(
              onPressed: () {
                final scheme = isPrimary
                    ? _config.colourScheme.copyWith(
                        primaryColorValue: pickerColor.toARGB32(),
                      )
                    : _config.colourScheme.copyWith(
                        secondaryColorValue: pickerColor.toARGB32(),
                      );
                _updateConfig(_config.copyWith(colourScheme: scheme));
                Navigator.pop(ctx);
              },
              child: const Text('Select'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AdaptiveNavigationBar(title: widget.adapter.title),
        body: const Center(child: AdaptiveLoadingIndicator()),
      );
    }

    return KeyboardDismissWrapper(
      child: Scaffold(
        appBar: AdaptiveNavigationBar(
          title: widget.adapter.title,
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
        body: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            // ── Live Preview ──
            BrandingLivePreview(
              config: _config,
              docType: widget.docType,
              logoBytes: _logoBytes,
            ),

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.screenPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Template Presets ──
                  _buildSectionLabel('Template', isDark),
                  const SizedBox(height: 8),
                  TemplatePresetSelector(
                    currentConfig: _config,
                    onSelected: _applyPreset,
                  ),
                  const SizedBox(height: 24),

                  // ── Header Layout ──
                  _buildSectionLabel('Header Layout', isDark),
                  const SizedBox(height: 8),
                  _buildLayoutPicker(isDark),
                  const SizedBox(height: 16),

                  // ── Header Blocks ──
                  _buildHeaderBlocksSection(isDark),
                  const SizedBox(height: 24),

                  // ── Footer Layout ──
                  _buildSectionLabel('Footer Layout', isDark),
                  const SizedBox(height: 8),
                  _buildFooterLayoutPicker(isDark),
                  const SizedBox(height: 16),

                  // ── Footer Blocks ──
                  _buildFooterBlocksSection(isDark),
                  const SizedBox(height: 24),

                  // ── Colour Scheme ──
                  _buildSectionLabel('Colour Scheme', isDark),
                  const SizedBox(height: 8),
                  _buildColourSchemeSection(isDark),
                  const SizedBox(height: 24),

                  // ── Font Selection ──
                  _buildSectionLabel('Font', isDark),
                  const SizedBox(height: 8),
                  _buildFontSelector(isDark),
                  const SizedBox(height: 24),

                  // ── Logo ──
                  _buildSectionLabel('Logo', isDark),
                  const SizedBox(height: 8),
                  _buildLogoSection(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section helpers ──

  Widget _buildSectionLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
      ),
    );
  }

  // ── Header layout picker ──

  Widget _buildLayoutPicker(bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: HeaderLayoutTemplate.values.map((template) {
        final isSelected = _config.headerTemplate == template;
        return ChoiceChip(
          label: Text(template.displayName),
          selected: isSelected,
          onSelected: (_) {
            _updateConfig(_config.copyWith(headerTemplate: template));
          },
          selectedColor: AppTheme.primaryBlue.withValues(alpha: 0.15),
          labelStyle: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected
                ? AppTheme.primaryBlue
                : isDark
                    ? AppTheme.darkTextPrimary
                    : AppTheme.textPrimary,
          ),
        );
      }).toList(),
    );
  }

  // ── Footer layout picker ──

  Widget _buildFooterLayoutPicker(bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: FooterLayoutTemplate.values.map((template) {
        final isSelected = _config.footerTemplate == template;
        return ChoiceChip(
          label: Text(template.displayName),
          selected: isSelected,
          onSelected: (_) {
            _updateConfig(_config.copyWith(footerTemplate: template));
          },
          selectedColor: AppTheme.primaryBlue.withValues(alpha: 0.15),
          labelStyle: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected
                ? AppTheme.primaryBlue
                : isDark
                    ? AppTheme.darkTextPrimary
                    : AppTheme.textPrimary,
          ),
        );
      }).toList(),
    );
  }

  // ── Header blocks ──

  Widget _buildHeaderBlocksSection(bool isDark) {
    final zones = <(String label, String key)>[
      ('Left / Main', 'headerLeft'),
    ];

    if (_config.headerTemplate.hasTwoColumns) {
      zones.add(('Right', 'headerRight'));
    }
    if (_config.headerTemplate.isCentered) {
      // Centered templates use headerLeft as the main content zone
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: zones
          .map((zone) => _buildBlockZone(
                label: 'Header — ${zone.$1}',
                zoneKey: zone.$2,
                isDark: isDark,
              ))
          .toList(),
    );
  }

  // ── Footer blocks ──

  Widget _buildFooterBlocksSection(bool isDark) {
    final zones = <(String label, String key)>[
      ('Left / Main', 'footerLeft'),
    ];

    if (_config.footerTemplate.hasCentre) {
      zones.add(('Centre', 'footerCentre'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: zones
          .map((zone) => _buildBlockZone(
                label: 'Footer — ${zone.$1}',
                zoneKey: zone.$2,
                isDark: isDark,
              ))
          .toList(),
    );
  }

  Widget _buildBlockZone({
    required String label,
    required String zoneKey,
    required bool isDark,
  }) {
    final blocks = _getZoneBlocks(zoneKey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
              ),
            ),
            TextButton.icon(
              onPressed: () => _addBlock(zoneKey),
              icon: Icon(AppIcons.add, size: 16),
              label: const Text('Add'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        if (blocks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No blocks. Tap + to add.',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: isDark ? AppTheme.darkTextHint : AppTheme.textHint,
              ),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: blocks.length,
            onReorder: (oldIndex, newIndex) =>
                _onBlocksReordered(zoneKey, oldIndex, newIndex),
            itemBuilder: (context, index) {
              final block = blocks[index];
              return ReorderableDragStartListener(
                key: ValueKey(block.id),
                index: index,
                child: ContentBlockEditorCard(
                  block: block,
                  docType: widget.docType,
                  isExpanded: _expandedBlockId == block.id,
                  onChanged: (updated) =>
                      _onBlockChanged(zoneKey, index, updated),
                  onDelete: () => _onBlockDeleted(zoneKey, index),
                  onTap: () {
                    setState(() {
                      _expandedBlockId = _expandedBlockId == block.id
                          ? null
                          : block.id;
                    });
                  },
                ),
              );
            },
          ),
        const SizedBox(height: 12),
      ],
    );
  }

  // ── Colour Scheme ──

  Widget _buildColourSchemeSection(bool isDark) {
    final primary = Color(_config.colourScheme.primaryColorValue);
    final secondary = _config.colourScheme.hasSecondary
        ? Color(_config.colourScheme.secondaryColorValue!)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Preset grid
        _buildColourPresetGrid(isDark),
        const SizedBox(height: 16),
        // Primary + secondary colour indicators
        Row(
          children: [
            _buildColourChip(
              label: 'Primary',
              color: primary,
              onTap: () => _openColourPicker(isPrimary: true),
            ),
            const SizedBox(width: 12),
            _buildColourChip(
              label: secondary != null ? 'Secondary' : 'Add Secondary',
              color: secondary,
              onTap: () => _openColourPicker(isPrimary: false),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildColourPresetGrid(bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: PdfColourSchemeV2.presets.map((preset) {
        final color = Color(preset.scheme.primaryColorValue);
        final isSelected = _config.colourScheme.primaryColorValue ==
            preset.scheme.primaryColorValue;

        return GestureDetector(
          onTap: () {
            _updateConfig(_config.copyWith(colourScheme: preset.scheme));
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(
                          color: isDark ? Colors.white : AppTheme.textPrimary,
                          width: 2.5,
                        )
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: isSelected
                    ? Icon(AppIcons.tickCircle, color: Colors.white, size: 18)
                    : null,
              ),
              const SizedBox(height: 4),
              Text(
                preset.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildColourChip({
    required String label,
    required Color? color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurfaceElevated : Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? AppTheme.darkDivider : AppTheme.lightGrey,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: color ?? Colors.grey[300],
                shape: BoxShape.circle,
                border: color == null
                    ? Border.all(
                        color: isDark
                            ? AppTheme.darkTextHint
                            : AppTheme.textHint,
                        style: BorderStyle.solid,
                      )
                    : null,
              ),
              child: color == null
                  ? Icon(AppIcons.add, size: 12, color: AppTheme.textHint)
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Font Selector ──

  Widget _buildFontSelector(bool isDark) {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: PdfFontFamily.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final family = PdfFontFamily.values[index];
          final isSelected = _config.fontConfig.family == family;

          return GestureDetector(
            onTap: () {
              _updateConfig(
                _config.copyWith(fontConfig: PdfFontConfig(family: family)),
              );
            },
            child: AnimatedContainer(
              duration: AppTheme.fastAnimation,
              width: 100,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryBlue
                      : isDark
                          ? AppTheme.darkDivider
                          : AppTheme.lightGrey,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Aa',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      fontFamily: family.isSerif ? 'Georgia' : null,
                      color: isSelected
                          ? AppTheme.primaryBlue
                          : isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    family.displayName,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? AppTheme.primaryBlue
                          : isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Logo Section ──

  Widget _buildLogoSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logo preview + buttons
        Row(
          children: [
            // Logo thumbnail
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurfaceElevated : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? AppTheme.darkDivider : AppTheme.lightGrey,
                ),
              ),
              child: _logoBytes != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Image.memory(
                        _logoBytes!,
                        fit: BoxFit.contain,
                      ),
                    )
                  : Icon(
                      AppIcons.image,
                      size: 24,
                      color: isDark
                          ? AppTheme.darkTextHint
                          : AppTheme.textHint,
                    ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickLogo,
                  icon: Icon(AppIcons.gallery, size: 16),
                  label: Text(
                      _logoBytes != null ? 'Change Logo' : 'Upload Logo'),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                if (_logoBytes != null) ...[
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: _removeLogo,
                    icon: Icon(AppIcons.trash, size: 14, color: AppTheme.errorRed),
                    label: Text(
                      'Remove',
                      style: TextStyle(color: AppTheme.errorRed, fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Logo size
        if (_config.headerTemplate.hasLogo) ...[
          Text(
            'Logo Size',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          SegmentedButton<LogoSize>(
            segments: LogoSize.values
                .map((s) => ButtonSegment(
                      value: s,
                      label: Text(s.name[0].toUpperCase() + s.name.substring(1)),
                    ))
                .toList(),
            selected: {_config.logoSize},
            onSelectionChanged: (v) {
              _updateConfig(_config.copyWith(logoSize: v.first));
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ],
    );
  }
}
