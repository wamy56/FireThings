import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/asset_service.dart';
import '../../services/analytics_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../widgets/custom_text_field.dart';
import 'asset_detail_screen.dart';
import 'add_edit_asset_screen.dart';

/// Modes the scanner can operate in.
enum ScannerMode {
  /// Look up an asset by barcode — navigates to detail or offers to create.
  lookup,

  /// Capture a barcode value and return it via Navigator.pop.
  capture,
}

class BarcodeScannerScreen extends StatefulWidget {
  final String basePath;
  final String siteId;
  final ScannerMode mode;

  const BarcodeScannerScreen({
    super.key,
    required this.basePath,
    required this.siteId,
    this.mode = ScannerMode.lookup,
  });

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  MobileScannerController? _controller;
  bool _isProcessing = false;
  final _manualController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _manualController.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty || barcodes.first.rawValue == null) return;

    final value = barcodes.first.rawValue!;
    setState(() => _isProcessing = true);
    await _controller?.stop();

    await _handleBarcode(value);
  }

  Future<void> _handleBarcode(String barcode) async {
    if (widget.mode == ScannerMode.capture) {
      if (mounted) Navigator.of(context).pop(barcode);
      return;
    }

    // Lookup mode
    final asset = await AssetService.instance
        .findByBarcode(widget.basePath, widget.siteId, barcode);

    AnalyticsService.instance.logBarcodeScan(
      result: asset != null ? 'found' : 'not_found',
      siteId: widget.siteId,
    );

    if (!mounted) return;

    if (asset != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AssetDetailScreen(
            basePath: widget.basePath,
            siteId: widget.siteId,
            assetId: asset.id,
          ),
        ),
      );
    } else {
      _showNotFoundSheet(barcode);
    }
  }

  void _showNotFoundSheet(String barcode) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(AppIcons.scanner,
                    color: AppTheme.accentOrange, size: 28),
              ),
              const SizedBox(height: 16),
              const Text(
                'Asset Not Found',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'No asset with barcode "$barcode" was found at this site.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => AddEditAssetScreen(
                          basePath: widget.basePath,
                          siteId: widget.siteId,
                          prefilledBarcode: barcode,
                        ),
                      ),
                    );
                  },
                  icon: Icon(AppIcons.add),
                  label: const Text('Create New Asset'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _resumeScanning();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Scan Again'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    ).whenComplete(() {
      // If sheet dismissed without action, resume scanning
      if (mounted && _isProcessing) _resumeScanning();
    });
  }

  void _resumeScanning() {
    setState(() => _isProcessing = false);
    _controller?.start();
  }

  void _handleManualEntry() {
    final barcode = _manualController.text.trim();
    if (barcode.isEmpty) return;
    _handleBarcode(barcode);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mode == ScannerMode.capture
            ? 'Scan Barcode'
            : 'Scan Asset'),
        actions: [
          if (!kIsWeb && _controller != null) ...[
            IconButton(
              icon: const Icon(AppIcons.flash),
              onPressed: () => _controller!.toggleTorch(),
            ),
            IconButton(
              icon: const Icon(AppIcons.refresh),
              onPressed: () => _controller!.switchCamera(),
            ),
          ],
        ],
      ),
      body: kIsWeb ? _buildWebFallback(isDark) : _buildCameraView(isDark),
    );
  }

  Widget _buildCameraView(bool isDark) {
    return Stack(
      children: [
        // Camera preview
        MobileScanner(
          controller: _controller!,
          onDetect: _onDetect,
        ),
        // Scan overlay
        Center(
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.accentOrange, width: 3),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        // Processing indicator
        if (_isProcessing)
          Container(
            color: Colors.black54,
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.accentOrange),
            ),
          ),
        // Bottom hint
        Positioned(
          bottom: 48,
          left: 0,
          right: 0,
          child: Text(
            'Point camera at a QR code or barcode',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWebFallback(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(AppIcons.scanner,
              size: 64,
              color:
                  isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
          const SizedBox(height: 16),
          Text(
            'Camera scanning is not available on web',
            style: TextStyle(
              fontSize: 16,
              color:
                  isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 400,
            child: CustomTextField(
              controller: _manualController,
              label: 'Enter barcode manually',
              prefixIcon: Icon(AppIcons.scanner),
              onSubmitted: (_) => _handleManualEntry(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _handleManualEntry,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentOrange,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(widget.mode == ScannerMode.capture
                ? 'Use Barcode'
                : 'Look Up'),
          ),
        ],
      ),
    );
  }
}
