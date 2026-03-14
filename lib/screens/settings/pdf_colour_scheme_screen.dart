import 'package:flutter/material.dart';
import '../../widgets/premium_dialog.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../models/pdf_colour_scheme.dart';
import '../../models/pdf_header_config.dart' show PdfDocumentType;
import '../../services/pdf_colour_scheme_service.dart';
import '../../utils/icon_map.dart';
import '../../utils/theme.dart';
import '../../widgets/animated_save_button.dart';
import '../../widgets/premium_toast.dart';
import '../../widgets/adaptive_app_bar.dart';
import '../../utils/adaptive_widgets.dart';

class PdfColourSchemeScreen extends StatefulWidget {
  const PdfColourSchemeScreen({super.key});

  @override
  State<PdfColourSchemeScreen> createState() => _PdfColourSchemeScreenState();
}

class _PdfColourSchemeScreenState extends State<PdfColourSchemeScreen> {
  PdfColourScheme _scheme = PdfColourScheme.defaults();
  bool _isLoading = true;
  PdfDocumentType _selectedDocType = PdfDocumentType.jobsheet;

  @override
  void initState() {
    super.initState();
    _loadScheme();
  }

  Future<void> _loadScheme() async {
    final scheme = await PdfColourSchemeService.getScheme(_selectedDocType);
    setState(() {
      _scheme = scheme;
      _isLoading = false;
    });
  }

  Future<void> _switchDocType(PdfDocumentType type) async {
    if (type == _selectedDocType) return;
    await PdfColourSchemeService.saveScheme(_scheme, _selectedDocType);
    _selectedDocType = type;
    setState(() => _isLoading = true);
    final scheme = await PdfColourSchemeService.getScheme(type);
    setState(() {
      _scheme = scheme;
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    await PdfColourSchemeService.saveScheme(_scheme, _selectedDocType);
    if (!mounted) return;
    context.showSuccessToast('Colour scheme saved');
  }

  Color get _primaryFlutterColor => Color(_scheme.primaryColorValue);

  Color _lightTint(Color c) {
    return Color.lerp(c, Colors.white, 0.9)!;
  }

  Color _mediumTint(Color c) {
    return Color.lerp(c, Colors.white, 0.6)!;
  }

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
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AdaptiveNavigationBar(
        title: 'Colour Scheme',
        actions: [
          if (!_isLoading)
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
      body: _isLoading
          ? const Center(child: AdaptiveLoadingIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppTheme.screenPadding),
              children: [
                // Document type toggle
                SegmentedButton<PdfDocumentType>(
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
                const SizedBox(height: 16),
                // Preview mockup
                _selectedDocType == PdfDocumentType.invoice
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
          // Header bar with bottom border
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: primary, width: 2),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'YOUR COMPANY',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Professional Services',
                        style: TextStyle(fontSize: 9, color: subtleText),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'INVOICE',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info row mockup
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

                // Table mockup
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: _mediumTint(primary).withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    children: [
                      // Table header
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
                          children: [
                            Expanded(flex: 3, child: Text('Description', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white))),
                            Expanded(child: Text('Qty', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center)),
                            Expanded(child: Text('Total', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.right)),
                          ],
                        ),
                      ),
                      // Table rows
                      _mockTableRow('Service item one', '1', '\u00A3250.00', textColor),
                      _mockTableRow('Service item two', '2', '\u00A3500.00', textColor),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Totals
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'TOTAL: \u00A3750.00',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: primary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Payment details mockup
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
                      Text(
                        'Payment Details',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primary),
                      ),
                      const SizedBox(height: 2),
                      Text('Bank: Example Bank | Sort Code: 12-34-56', style: TextStyle(fontSize: 8, color: subtleText)),
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
          // Header bar with bottom border
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: primary, width: 2),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'YOUR COMPANY',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Professional Services',
                        style: TextStyle(fontSize: 9, color: subtleText),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'JOBSHEET',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Job Information section
                _mockSectionHeader('JOB INFORMATION', primary),
                _mockFieldRow('Date:', '14/03/2026', light, false),
                _mockFieldRow('Engineer:', 'John Smith', light, true),
                _mockFieldRow('Job No:', 'JS-001', light, false),
                const SizedBox(height: 10),

                // Work Details section
                _mockSectionHeader('WORK DETAILS', primary),
                _mockFieldRow('System Type:', 'Conventional', light, false),
                _mockFieldRow('Panels Tested:', 'Yes', light, true),
                const SizedBox(height: 10),

                // Certification box
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
                      Text(
                        'CERTIFICATION STATEMENT',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: textColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Work carried out in accordance with BS 5839-1.',
                        style: TextStyle(fontSize: 8, color: subtleText),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Signatures
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Engineer', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: textColor)),
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
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Customer', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: textColor)),
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
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
            child: Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 9, color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetGrid(bool isDark) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: PdfColourScheme.presets.length,
      itemBuilder: (context, index) {
        final preset = PdfColourScheme.presets[index];
        final color = Color(preset.scheme.primaryColorValue);
        final isSelected = _scheme.primaryColorValue == preset.scheme.primaryColorValue;

        return GestureDetector(
          onTap: () => _selectPreset(preset.scheme),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(
                          color: isDark ? Colors.white : AppTheme.textPrimary,
                          width: 3,
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
                    ? Icon(AppIcons.tickCircle, color: Colors.white, size: 22)
                    : null,
              ),
              const SizedBox(height: 6),
              Text(
                preset.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}
