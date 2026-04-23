import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/pdf_branding.dart';
import '../../services/pdf_branding_service.dart';
import '../../services/user_profile_service.dart';
import '../../theme/web_theme.dart';
import '../../utils/icon_map.dart';
import '../../widgets/premium_toast.dart';
import 'widgets/branding/branding_controls_panel.dart';
import 'widgets/branding/branding_preview_canvas.dart';

enum _SaveStatus { loading, saved, saving, unsaved, error }

class WebBrandingScreen extends StatefulWidget {
  const WebBrandingScreen({super.key});

  @override
  State<WebBrandingScreen> createState() => _WebBrandingScreenState();
}

class _WebBrandingScreenState extends State<WebBrandingScreen> {
  int _selectedTab = 0;
  BrandingDocType _selectedDocType = BrandingDocType.report;

  PdfBranding? _branding;
  StreamSubscription<PdfBranding>? _subscription;
  Timer? _saveDebounce;
  _SaveStatus _saveStatus = _SaveStatus.loading;
  bool _hasPendingSave = false;
  String? _logoFileName;
  int? _logoFileSize;

  String? get _companyId => UserProfileService.instance.companyId;

  @override
  void initState() {
    super.initState();
    final companyId = _companyId;
    if (companyId != null) {
      _subscription =
          PdfBrandingService.instance.watchBranding(companyId).listen((b) {
        if (!_hasPendingSave && mounted) {
          setState(() {
            _branding = b;
            _saveStatus = _SaveStatus.saved;
            if (b.logoUrl != null && _logoFileName == null) {
              _logoFileName = _extractFileName(b.logoUrl!);
            }
            if (b.logoUrl == null) {
              _logoFileName = null;
              _logoFileSize = null;
            }
          });
        }
      });
    }
  }

  String _extractFileName(String url) {
    try {
      final segments = Uri.parse(url).pathSegments;
      if (segments.isNotEmpty) {
        final encoded = segments.last;
        final decoded = Uri.decodeComponent(encoded);
        final parts = decoded.split('/');
        return parts.last;
      }
    } catch (_) {}
    return 'Company logo';
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  void _onBrandingChanged(PdfBranding b) {
    setState(() {
      _branding = b;
      _saveStatus = _SaveStatus.unsaved;
      _hasPendingSave = true;
    });
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), _saveBranding);
  }

  Future<void> _saveBranding() async {
    final companyId = _companyId;
    if (companyId == null || _branding == null) return;

    setState(() => _saveStatus = _SaveStatus.saving);

    try {
      await PdfBrandingService.instance.saveBranding(companyId, _branding!);
      if (mounted) {
        setState(() {
          _saveStatus = _SaveStatus.saved;
          _hasPendingSave = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saveStatus = _SaveStatus.error);
      }
    }
  }

  Future<void> _onLogoPicked(
      ({String name, int size, Uint8List bytes}) file) async {
    final companyId = _companyId;
    if (companyId == null || _branding == null) return;

    setState(() {
      _logoFileName = file.name;
      _logoFileSize = file.size;
      _saveStatus = _SaveStatus.saving;
    });

    try {
      final url = await PdfBrandingService.instance.uploadLogo(
        companyId: companyId,
        bytes: file.bytes,
        fileName: file.name,
      );
      _branding = _branding!.copyWith(logoUrl: url);
      await PdfBrandingService.instance.saveBranding(companyId, _branding!);
      if (mounted) {
        setState(() {
          _saveStatus = _SaveStatus.saved;
          _hasPendingSave = false;
        });
      }
    } on FormatException catch (e) {
      if (mounted) {
        context.showErrorToast(e.message);
        setState(() => _saveStatus = _SaveStatus.saved);
      }
    } catch (_) {
      if (mounted) {
        context.showErrorToast('Failed to upload logo');
        setState(() => _saveStatus = _SaveStatus.saved);
      }
    }
  }

  Future<void> _onLogoRemoved() async {
    final companyId = _companyId;
    if (companyId == null || _branding == null) return;

    final oldUrl = _branding!.logoUrl;
    if (oldUrl != null) {
      PdfBrandingService.instance.deleteLogo(companyId, oldUrl);
    }

    setState(() {
      _branding = _branding!.copyWith(clearLogoUrl: true);
      _logoFileName = null;
      _logoFileSize = null;
    });
    await _saveBranding();
  }

  Future<void> _resetToDefaults() async {
    setState(() {
      _branding = PdfBranding.defaultBranding();
      _logoFileName = null;
      _logoFileSize = null;
    });
    await _saveBranding();
    if (mounted) {
      context.showSuccessToast('Branding reset to defaults');
    }
  }

  void _onGenerateTestPdf() {
    context.showWarningToast(
      'Generate a compliance report from any site\'s asset register to preview your branding',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_branding == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: FtColors.accent),
            SizedBox(height: 16),
            Text('Loading branding...', style: TextStyle(color: FtColors.fg2)),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildToolbar(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BrandingControlsPanel(
                selectedTab: _selectedTab,
                onTabChanged: (i) => setState(() => _selectedTab = i),
                branding: _branding!,
                onBrandingChanged: _onBrandingChanged,
                selectedDocType: _selectedDocType,
                logoFileName: _logoFileName,
                logoFileSize: _logoFileSize,
                onLogoPicked: _onLogoPicked,
                onLogoRemoved: _onLogoRemoved,
              ),
              Expanded(
                child: BrandingPreviewCanvas(
                  branding: _branding!,
                  selectedDocType: _selectedDocType,
                  onDocTypeChanged: (t) =>
                      setState(() => _selectedDocType = t),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: FtColors.bg,
        border: Border(bottom: BorderSide(color: FtColors.border)),
      ),
      child: Row(
        children: [
          _buildTitle(),
          const Spacer(),
          _buildSaveStatus(),
          const Spacer(),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: FtColors.accentSoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(AppIcons.colorSwatch,
              size: 16, color: FtColors.accentHover),
        ),
        const SizedBox(width: 12),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reports',
              style: FtText.inter(
                  size: 11, weight: FontWeight.w500, color: FtColors.fg2),
            ),
            Text(
              'Brand & styling',
              style: FtText.inter(
                  size: 14, weight: FontWeight.w700, color: FtColors.fg1),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSaveStatus() {
    final (Color bg, Color fg, Color dot, String text) = switch (_saveStatus) {
      _SaveStatus.loading => (
          FtColors.bgAlt,
          FtColors.fg2,
          FtColors.hint,
          'Loading...',
        ),
      _SaveStatus.saved => (
          FtColors.successSoft,
          const Color(0xFF2F7D32),
          const Color(0xFF2F7D32),
          'Saved · changes apply to all reports',
        ),
      _SaveStatus.saving => (
          FtColors.accentSoft,
          FtColors.accentHover,
          FtColors.accent,
          'Saving...',
        ),
      _SaveStatus.unsaved => (
          FtColors.accentSoft,
          FtColors.accentHover,
          FtColors.accent,
          'Unsaved changes',
        ),
      _SaveStatus.error => (
          FtColors.dangerSoft,
          FtColors.danger,
          FtColors.danger,
          'Save failed · tap to retry',
        ),
    };

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: FtText.inter(size: 12, weight: FontWeight.w600, color: fg),
          ),
        ],
      ),
    );

    if (_saveStatus == _SaveStatus.error) {
      return GestureDetector(onTap: _saveBranding, child: pill);
    }
    return pill;
  }

  Widget _buildActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          onPressed: _branding != null ? _resetToDefaults : null,
          icon: const Icon(AppIcons.undo, size: 14),
          label: const Text('Reset'),
          style: TextButton.styleFrom(
            foregroundColor: FtColors.fg2,
            textStyle: FtText.button,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            shape: RoundedRectangleBorder(borderRadius: FtRadii.mdAll),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _onGenerateTestPdf,
          icon: const Icon(AppIcons.document, size: 14),
          label: const Text('Generate test PDF'),
          style: OutlinedButton.styleFrom(
            foregroundColor: FtColors.primary,
            textStyle: FtText.button,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            side: const BorderSide(color: FtColors.border, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: FtRadii.mdAll),
          ),
        ),
        const SizedBox(width: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: FtRadii.mdAll,
            boxShadow: FtShadows.amber,
          ),
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(AppIcons.tickCircle, size: 14),
            label: const Text('Apply to all'),
            style: ElevatedButton.styleFrom(
              backgroundColor: FtColors.accent,
              foregroundColor: Colors.white,
              textStyle: FtText.button,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 9),
              elevation: 0,
              shape:
                  RoundedRectangleBorder(borderRadius: FtRadii.mdAll),
            ),
          ),
        ),
      ],
    );
  }
}
