import 'package:flutter/material.dart';
import '../../models/pdf_typography_config.dart';
import '../../models/pdf_header_config.dart' show PdfDocumentType;
import '../../services/pdf_typography_service.dart';
import '../../utils/icon_map.dart';
import '../../utils/theme.dart';
import '../../widgets/animated_save_button.dart';
import '../../widgets/premium_toast.dart';
import '../../widgets/adaptive_app_bar.dart';

class PdfTypographyScreen extends StatefulWidget {
  final PdfDocumentType? docType;

  const PdfTypographyScreen({super.key, this.docType});

  @override
  State<PdfTypographyScreen> createState() => _PdfTypographyScreenState();
}

class _PdfTypographyScreenState extends State<PdfTypographyScreen> {
  PdfTypographyConfig _config = PdfTypographyConfig.defaults();
  bool _isLoading = true;
  late PdfDocumentType _selectedDocType;

  @override
  void initState() {
    super.initState();
    _selectedDocType = widget.docType ?? PdfDocumentType.jobsheet;
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await PdfTypographyService.getConfig(_selectedDocType);
    setState(() {
      _config = config;
      _isLoading = false;
    });
  }

  Future<void> _switchDocType(PdfDocumentType type) async {
    if (type == _selectedDocType) return;
    await PdfTypographyService.saveConfig(_config, _selectedDocType);
    _selectedDocType = type;
    setState(() => _isLoading = true);
    final config = await PdfTypographyService.getConfig(type);
    setState(() {
      _config = config;
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    await PdfTypographyService.saveConfig(_config, _selectedDocType);
    if (!mounted) return;
    context.showSuccessToast('Typography settings saved');
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
        title: 'Typography',
        actions: [
          IconButton(
            icon: Icon(AppIcons.refresh),
            onPressed: _resetToDefaults,
            tooltip: 'Reset to defaults',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppTheme.screenPadding),
              children: [
                // Document type selector (if not passed in)
                if (widget.docType == null) ...[
                  SegmentedButton<PdfDocumentType>(
                    segments: const [
                      ButtonSegment(
                        value: PdfDocumentType.jobsheet,
                        label: Text('Jobsheet'),
                      ),
                      ButtonSegment(
                        value: PdfDocumentType.invoice,
                        label: Text('Invoice'),
                      ),
                    ],
                    selected: {_selectedDocType},
                    onSelectionChanged: (selected) =>
                        _switchDocType(selected.first),
                  ),
                  const SizedBox(height: 24),
                ],

                Text(
                  'Adjust font sizes throughout your PDF documents.',
                  style: TextStyle(
                    fontSize: 14,
                    color:
                        isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
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

                const SizedBox(height: 24),

                // Save button
                AnimatedSaveButton(onPressed: _save),
              ],
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
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
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
