import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/pdf_header_config.dart';
import '../../services/pdf_header_config_service.dart';
import '../../services/branding_service.dart';
import '../../services/auth_service.dart';
import '../../utils/icon_map.dart';
import '../../widgets/premium_toast.dart';
import '../../widgets/animated_save_button.dart';
import '../../widgets/adaptive_app_bar.dart';
import '../../widgets/premium_dialog.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/keyboard_dismiss_wrapper.dart';

class PdfHeaderDesignerScreen extends StatefulWidget {
  const PdfHeaderDesignerScreen({super.key});

  @override
  State<PdfHeaderDesignerScreen> createState() =>
      _PdfHeaderDesignerScreenState();
}

class _PdfHeaderDesignerScreenState extends State<PdfHeaderDesignerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  PdfHeaderConfig _config = PdfHeaderConfig.defaults();
  String? _logoPath;
  bool _isLoading = true;
  PdfDocumentType _selectedDocType = PdfDocumentType.jobsheet;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final config = await PdfHeaderConfigService.getConfig(_selectedDocType);
    final logoPath = await BrandingService.getLogoPath();
    setState(() {
      _config = config;
      _logoPath = logoPath;
      _isLoading = false;
    });
  }

  Future<void> _switchDocType(PdfDocumentType type) async {
    if (type == _selectedDocType) return;
    // Save current config before switching
    await PdfHeaderConfigService.saveConfig(_config, _selectedDocType);
    _selectedDocType = type;
    setState(() => _isLoading = true);
    final config = await PdfHeaderConfigService.getConfig(type);
    setState(() {
      _config = config;
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    try {
      await PdfHeaderConfigService.saveConfig(_config, _selectedDocType);
      if (!mounted) return;
      context.showSuccessToast('Header settings saved');
    } catch (e) {
      if (!mounted) return;
      context.showErrorToast('Error saving: $e');
      rethrow;
    }
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

    final picked =
        await picker.pickImage(source: source!, maxWidth: 512, maxHeight: 512);
    if (picked == null) return;

    // Evict old cached image before overwriting the file
    if (_logoPath != null) {
      imageCache.evict(FileImage(File(_logoPath!)));
    }

    await BrandingService.saveLogo(picked.path);
    final newPath = await BrandingService.getLogoPath();
    setState(() => _logoPath = newPath);

    if (mounted) {
      context.showSuccessToast('Logo saved');
    }
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

    // Evict cached image before removing
    if (_logoPath != null) {
      imageCache.evict(FileImage(File(_logoPath!)));
    }

    await BrandingService.removeLogo();
    setState(() => _logoPath = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdaptiveNavigationBar(
        title: 'PDF Header Designer',
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
      body: KeyboardDismissWrapper(child: _isLoading
          ? const Center(child: AdaptiveLoadingIndicator())
          : Column(
              children: [
                // Document type toggle
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: SegmentedButton<PdfDocumentType>(
                    segments: [
                      ButtonSegment(
                        value: PdfDocumentType.jobsheet,
                        label: const Text('Jobsheet'),
                        icon: Icon(AppIcons.document),
                      ),
                      ButtonSegment(
                        value: PdfDocumentType.invoice,
                        label: const Text('Invoice'),
                        icon: Icon(AppIcons.receipt),
                      ),
                    ],
                    selected: {_selectedDocType},
                    onSelectionChanged: (selection) => _switchDocType(selection.first),
                  ),
                ),
                // Live Preview
                _buildPreview(),
                // Tabs
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
            )),
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
                // Left + Centre zones
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
                // Right zone placeholder
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
    final showLogo = _logoPath != null &&
        ((isLeft && _config.logoZone == LogoZone.left) ||
            (!isLeft && _config.logoZone == LogoZone.centre));

    final previewSize = _config.logoSize.pixels * 0.5; // Scale down for preview

    final children = <Widget>[];
    if (showLogo) {
      children.add(
        Container(
          width: previewSize,
          height: previewSize,
          margin: const EdgeInsets.only(right: 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Image.file(File(_logoPath!), fit: BoxFit.contain),
          ),
        ),
      );
    }

    final textWidgets = <Widget>[];
    for (final line in lines) {
      final text = line.value.isNotEmpty ? line.value : _fallbackForKey(line.key);
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

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  String _fallbackForKey(String key) {
    switch (key) {
      case 'companyName':
        return AuthService().currentUser?.displayName ?? '';
      case 'engineerName':
        return AuthService().currentUser?.displayName ?? '';
      default:
        return '';
    }
  }

  // ─── LOGO TAB ──────────────────────────────────────────────

  Widget _buildLogoTab() {
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
          child: _logoPath != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Image.file(File(_logoPath!), fit: BoxFit.contain),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(AppIcons.image,
                        size: 40, color: Colors.grey[400]),
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
                label:
                    Text(_logoPath != null ? 'Change Logo' : 'Upload Logo'),
              ),
            ),
            if (_logoPath != null) ...[
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
            ButtonSegment(
                value: LogoSize.small, label: Text('Small (40px)')),
            ButtonSegment(
                value: LogoSize.medium, label: Text('Medium (60px)')),
            ButtonSegment(
                value: LogoSize.large, label: Text('Large (80px)')),
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
                        Icon(AppIcons.noteText,
                            size: 48, color: Colors.grey[400]),
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
        // Add line button
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
            // Top row: drag handle, label, delete
            Row(
              children: [
                Icon(AppIcons.menu, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _labelForKey(line.key),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
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
            // Text value
            TextFormField(
              initialValue: line.value,
              decoration: InputDecoration(
                labelText: 'Text',
                hintText: _fallbackForKey(line.key).isNotEmpty
                    ? 'Default: ${_fallbackForKey(line.key)}'
                    : 'Enter text...',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              textInputAction: TextInputAction.done,
              onChanged: (val) {
                final updated = List<HeaderTextLine>.from(lines);
                updated[index] = updated[index].copyWith(value: val);
                _config = isLeft
                    ? _config.copyWith(leftLines: updated)
                    : _config.copyWith(centreLines: updated);
                // Rebuild preview without full setState on every keystroke
                setState(() {});
              },
            ),
            const SizedBox(height: 8),
            // Font size slider + bold toggle
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
                        updated[index] =
                            updated[index].copyWith(fontSize: val);
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
                      updated[index] =
                          updated[index].copyWith(bold: val);
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
    _showAddLineDialog(isLeft);
  }

  void _showAddLineDialog(bool isLeft) {
    final options = <_LineOption>[
      _LineOption('companyName', 'Company Name'),
      _LineOption('tagline', 'Tagline'),
      _LineOption('address', 'Address'),
      _LineOption('phone', 'Phone'),
      _LineOption('engineerName', 'Engineer Name'),
      _LineOption('custom', 'Custom Text'),
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
      case 'custom':
        return 'Custom Text';
      default:
        return key;
    }
  }
}

class _LineOption {
  final String key;
  final String label;
  const _LineOption(this.key, this.label);
}
