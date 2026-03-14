import 'package:flutter/material.dart';
import '../../models/pdf_header_config.dart';
import '../../models/pdf_footer_config.dart';
import '../../services/pdf_footer_config_service.dart';
import '../../utils/icon_map.dart';
import '../../widgets/premium_toast.dart';
import '../../widgets/animated_save_button.dart';
import '../../widgets/adaptive_app_bar.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/premium_dialog.dart';
import '../../widgets/keyboard_dismiss_wrapper.dart';

class PdfFooterDesignerScreen extends StatefulWidget {
  const PdfFooterDesignerScreen({super.key});

  @override
  State<PdfFooterDesignerScreen> createState() =>
      _PdfFooterDesignerScreenState();
}

class _PdfFooterDesignerScreenState extends State<PdfFooterDesignerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  PdfFooterConfig _config = PdfFooterConfig.defaults();
  bool _isLoading = true;
  PdfDocumentType _selectedDocType = PdfDocumentType.jobsheet;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final config = await PdfFooterConfigService.getConfig(_selectedDocType);
    setState(() {
      _config = config;
      _isLoading = false;
    });
  }

  Future<void> _switchDocType(PdfDocumentType type) async {
    if (type == _selectedDocType) return;
    await PdfFooterConfigService.saveConfig(_config, _selectedDocType);
    _selectedDocType = type;
    setState(() => _isLoading = true);
    final config = await PdfFooterConfigService.getConfig(type);
    setState(() {
      _config = config;
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    try {
      await PdfFooterConfigService.saveConfig(_config, _selectedDocType);
      if (!mounted) return;
      context.showSuccessToast('Footer settings saved');
    } catch (e) {
      if (!mounted) return;
      context.showErrorToast('Error saving: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdaptiveNavigationBar(
        title: 'PDF Footer Designer',
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
                top: BorderSide(
                  color: Color(0xFFE0E0E0),
                  width: 1,
                ),
              ),
            ),
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left zone
                Expanded(
                  flex: 3,
                  child: _buildPreviewZone(isLeft: true),
                ),
                // Centre zone
                if (_config.centreLines.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: _buildPreviewZone(isLeft: false),
                  ),
                ],
                const SizedBox(width: 8),
                // Page numbers
                Text(
                  'Page 1 of 1',
                  style: TextStyle(
                    fontSize: 7,
                    color: Colors.grey[600],
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

    final textWidgets = <Widget>[];
    for (final line in lines) {
      final text = line.value;
      if (text.isEmpty) continue;
      textWidgets.add(
        Text(
          text,
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

    if (textWidgets.isEmpty) {
      return const SizedBox.shrink();
    }

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
                        Icon(AppIcons.noteText,
                            size: 48, color: Colors.grey[400]),
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
              decoration: const InputDecoration(
                labelText: 'Text',
                hintText: 'Enter text...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              textInputAction: TextInputAction.done,
              keyboardAppearance: Theme.of(context).brightness,
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
            // Font size slider + bold toggle
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
      _LineOption('companyDetails', 'Company Details'),
      _LineOption('contactInfo', 'Contact Info'),
      _LineOption('website', 'Website'),
      _LineOption('email', 'Email'),
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
                fontSize: 7,
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
      case 'companyDetails':
        return 'Company Details';
      case 'contactInfo':
        return 'Contact Info';
      case 'website':
        return 'Website';
      case 'email':
        return 'Email';
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
