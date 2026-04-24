import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../models/branding_preset.dart';
import '../../../models/pdf_branding.dart';
import '../../../services/compliance_report_service.dart';
import '../../../services/pdf_branding_service.dart';
import '../../../utils/adaptive_widgets.dart';
import '../../../utils/icon_map.dart';
import '../../../utils/theme.dart';
import '../../../widgets/adaptive_app_bar.dart' show AdaptiveNavigationBar;
import '../../common/pdf_preview_screen.dart';
import 'widgets/branding_logo_mobile.dart';
import 'widgets/cover_style_picker.dart';
import 'widgets/mini_cover_preview.dart';
import 'widgets/primary_colour_tweaker.dart';

class PersonalBrandingScreen extends StatefulWidget {
  const PersonalBrandingScreen({super.key});

  @override
  State<PersonalBrandingScreen> createState() => _PersonalBrandingScreenState();
}

class _PersonalBrandingScreenState extends State<PersonalBrandingScreen> {
  PdfBranding? _branding;
  String? _selectedPresetId;
  bool _loading = true;
  bool _uploading = false;
  bool _generating = false;
  bool _showCustomise = false;
  Timer? _colourDebounce;

  @override
  void initState() {
    super.initState();
    _loadBranding();
  }

  @override
  void dispose() {
    _colourDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadBranding() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final b = await PdfBrandingService.instance.getPersonalBranding(uid);
      if (!mounted) return;
      setState(() {
        _branding = b;
        _selectedPresetId = _detectPreset(b);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String? _detectPreset(PdfBranding branding) {
    for (final preset in BrandingPreset.all) {
      if (preset.primaryColour.toLowerCase() ==
              branding.primaryColour.toLowerCase() &&
          preset.accentColour.toLowerCase() ==
              branding.accentColour.toLowerCase()) {
        return preset.id;
      }
    }
    return null;
  }

  Future<void> _selectPreset(BrandingPreset preset) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final updated = (_branding ?? PdfBranding.defaultBranding()).copyWith(
      primaryColour: preset.primaryColour,
      accentColour: preset.accentColour,
      coverStyle: preset.suggestedCoverStyle,
      headerStyle: HeaderStyle.minimal,
    );

    setState(() {
      _branding = updated;
      _selectedPresetId = preset.id;
    });

    try {
      await PdfBrandingService.instance.savePersonalBranding(uid, updated);
    } catch (e) {
      debugPrint('Failed to save personal branding: $e');
    }
  }

  Future<void> _onLogoPicked(({String name, Uint8List bytes}) file) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _uploading = true);
    try {
      final url = await PdfBrandingService.instance.uploadPersonalLogo(
        userId: uid,
        bytes: file.bytes,
        fileName: file.name,
      );
      final updated = (_branding ?? PdfBranding.defaultBranding()).copyWith(
        logoUrl: url,
      );
      await PdfBrandingService.instance.savePersonalBranding(uid, updated);
      if (!mounted) return;
      setState(() {
        _branding = updated;
        _uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload logo: $e')),
      );
    }
  }

  Future<void> _onLogoRemoved() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final oldUrl = _branding?.logoUrl;
    final updated = (_branding ?? PdfBranding.defaultBranding()).copyWith(
      clearLogoUrl: true,
    );

    setState(() => _branding = updated);

    try {
      if (oldUrl != null) {
        PdfBrandingService.instance.deletePersonalLogo(uid, oldUrl);
      }
      await PdfBrandingService.instance.savePersonalBranding(uid, updated);
    } catch (e) {
      debugPrint('Failed to remove logo: $e');
    }
  }

  Future<void> _onCoverStyleChanged(CoverStyle style) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final updated = (_branding ?? PdfBranding.defaultBranding()).copyWith(
      coverStyle: style,
    );

    setState(() {
      _branding = updated;
      _selectedPresetId = _detectPreset(updated);
    });

    try {
      await PdfBrandingService.instance.savePersonalBranding(uid, updated);
    } catch (e) {
      debugPrint('Failed to save cover style: $e');
    }
  }

  void _onPrimaryColourChanged(Color color) {
    final hex = '#${(color.r * 255).round().toRadixString(16).padLeft(2, '0')}'
        '${(color.g * 255).round().toRadixString(16).padLeft(2, '0')}'
        '${(color.b * 255).round().toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();

    final updated = (_branding ?? PdfBranding.defaultBranding()).copyWith(
      primaryColour: hex,
    );

    setState(() {
      _branding = updated;
      _selectedPresetId = _detectPreset(updated);
    });

    _colourDebounce?.cancel();
    _colourDebounce = Timer(const Duration(milliseconds: 500), () async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      try {
        await PdfBrandingService.instance.savePersonalBranding(uid, updated);
      } catch (e) {
        debugPrint('Failed to save colour: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AdaptiveNavigationBar(title: 'Personal Branding'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.all(AppTheme.screenPadding),
              children: [
                _buildExplainer(isDark),
                const SizedBox(height: 24),
                MiniCoverPreview(
                  coverStyle: _branding?.coverStyle ?? CoverStyle.bold,
                  primaryColor: _hexToColor(
                      _branding?.primaryColour ?? '#1A1A2E'),
                  accentColor: _hexToColor(
                      _branding?.accentColour ?? '#FFB020'),
                  logoUrl: _branding?.logoUrl,
                ),
                const SizedBox(height: 32),
                _buildPresetPicker(isDark),
                const SizedBox(height: 24),
                _buildCustomiseToggle(isDark),
                if (_showCustomise) ...[
                  const SizedBox(height: 24),
                  CoverStylePicker(
                    selected: _branding?.coverStyle ?? CoverStyle.bold,
                    primaryColor: _hexToColor(
                        _branding?.primaryColour ?? '#1A1A2E'),
                    accentColor: _hexToColor(
                        _branding?.accentColour ?? '#FFB020'),
                    onChanged: _onCoverStyleChanged,
                  ),
                  const SizedBox(height: 24),
                  PrimaryColourTweaker(
                    currentColor: _hexToColor(
                        _branding?.primaryColour ?? '#1A1A2E'),
                    onChanged: _onPrimaryColourChanged,
                  ),
                ],
                const SizedBox(height: 32),
                BrandingLogoMobile(
                  logoUrl: _branding?.logoUrl,
                  uploading: _uploading,
                  onPicked: _onLogoPicked,
                  onRemoved: _onLogoRemoved,
                ),
                const SizedBox(height: 32),
                _buildTestPdfButton(),
              ],
            ),
    );
  }

  Widget _buildExplainer(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: isDark ? null : AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Icon(
            AppIcons.infoCircle,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Personal branding appears on all your PDFs. '
              'Pick a preset to get started.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textSecondary,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetPicker(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Choose a preset',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        ...BrandingPreset.all.map((preset) => _buildPresetCard(preset, isDark)),
      ],
    );
  }

  Widget _buildPresetCard(BrandingPreset preset, bool isDark) {
    final isSelected = _selectedPresetId == preset.id;
    final primaryColor = _hexToColor(preset.primaryColour);
    final accentColor = _hexToColor(preset.accentColour);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectPreset(preset),
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          child: AnimatedContainer(
            duration: AppTheme.normalAnimation,
            curve: AppTheme.defaultCurve,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite,
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              border: Border.all(
                color: isSelected
                    ? accentColor
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06)),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isDark ? null : AppTheme.cardShadow,
            ),
            child: Row(
              children: [
                // Colour swatches
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preset.name,
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        preset.description,
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: isDark
                                      ? AppTheme.darkTextSecondary
                                      : AppTheme.textSecondary,
                                ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    AppIcons.tickCircle,
                    color: accentColor,
                    size: 22,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomiseToggle(bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _showCustomise = !_showCustomise),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: AnimatedContainer(
          duration: AppTheme.normalAnimation,
          curve: AppTheme.defaultCurve,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite,
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
            boxShadow: isDark ? null : AppTheme.cardShadow,
          ),
          child: Row(
            children: [
              Icon(
                AppIcons.setting,
                size: 20,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Customise further',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
              AnimatedRotation(
                turns: _showCustomise ? 0.5 : 0,
                duration: AppTheme.normalAnimation,
                curve: AppTheme.defaultCurve,
                child: Icon(
                  AppIcons.arrowDown,
                  size: 20,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generateTestPdf() async {
    final branding = _branding ?? PdfBranding.defaultBranding();
    setState(() => _generating = true);
    try {
      final pdfBytes =
          await ComplianceReportService.generateBrandingPreview(branding);
      if (!mounted) return;
      setState(() => _generating = false);
      Navigator.push(
        context,
        adaptivePageRoute(
          builder: (_) => PdfPreviewScreen(
            pdfBytes: pdfBytes,
            title: 'Branding Preview',
            fileName: 'Branding_Preview.pdf',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _generating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate PDF: $e')),
      );
    }
  }

  Widget _buildTestPdfButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _generating ? null : _generateTestPdf,
        icon: _generating
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(AppIcons.document),
        label: Text(_generating ? 'Generating...' : 'Generate Test PDF'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Color _hexToColor(String hex) {
    final clean = hex.replaceFirst('#', '');
    return Color(0xFF000000 | int.parse(clean, radix: 16));
  }
}
