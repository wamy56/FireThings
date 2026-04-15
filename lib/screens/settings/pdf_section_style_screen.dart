import 'package:flutter/material.dart';
import '../../models/pdf_section_style_config.dart';
import '../../models/pdf_header_config.dart' show PdfDocumentType;
import '../../services/pdf_section_style_service.dart';
import '../../utils/theme.dart';
import '../../widgets/animated_save_button.dart';
import '../../widgets/premium_toast.dart';
import '../../widgets/adaptive_app_bar.dart';

class PdfSectionStyleScreen extends StatefulWidget {
  final PdfDocumentType? docType;

  const PdfSectionStyleScreen({super.key, this.docType});

  @override
  State<PdfSectionStyleScreen> createState() => _PdfSectionStyleScreenState();
}

class _PdfSectionStyleScreenState extends State<PdfSectionStyleScreen> {
  PdfSectionStyleConfig _config = PdfSectionStyleConfig.defaults();
  bool _isLoading = true;
  late PdfDocumentType _selectedDocType;

  @override
  void initState() {
    super.initState();
    _selectedDocType = widget.docType ?? PdfDocumentType.jobsheet;
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await PdfSectionStyleService.getConfig(_selectedDocType);
    setState(() {
      _config = config;
      _isLoading = false;
    });
  }

  Future<void> _switchDocType(PdfDocumentType type) async {
    if (type == _selectedDocType) return;
    await PdfSectionStyleService.saveConfig(_config, _selectedDocType);
    _selectedDocType = type;
    setState(() => _isLoading = true);
    final config = await PdfSectionStyleService.getConfig(type);
    setState(() {
      _config = config;
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    await PdfSectionStyleService.saveConfig(_config, _selectedDocType);
    if (!mounted) return;
    context.showSuccessToast('Section style saved');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AdaptiveNavigationBar(title: 'Section Style'),
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

                const SizedBox(height: 32),

                // Save button
                AnimatedSaveButton(onPressed: _save),
              ],
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
