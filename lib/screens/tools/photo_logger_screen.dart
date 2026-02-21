import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/adaptive_app_bar.dart';
import '../../widgets/premium_toast.dart';

// Conditional imports handled via platform checks at runtime
import 'package:geolocator/geolocator.dart';
import 'package:gal/gal.dart';
import 'package:intl/intl.dart';

class PhotoLoggerScreen extends StatefulWidget {
  const PhotoLoggerScreen({super.key});

  @override
  State<PhotoLoggerScreen> createState() => _PhotoLoggerScreenState();
}

class _PhotoLoggerScreenState extends State<PhotoLoggerScreen> {
  final _picker = ImagePicker();

  bool _isProcessing = false;
  Uint8List? _processedImageBytes;
  String? _lastTimestamp;
  String? _lastCoords;

  bool get _isMobile =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: AdaptiveNavigationBar(title: 'Photo Logger'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(AppIcons.camera, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'Photo Logger is not supported on web.',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Please use the mobile or desktop app.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AdaptiveNavigationBar(title: 'Photo Logger'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 24),
            _buildCaptureButton(),
            if (_isProcessing) ...[
              const SizedBox(height: 24),
              Center(
                child: Column(
                  children: [
                    const AdaptiveLoadingIndicator(),
                    const SizedBox(height: 12),
                    Text(
                      'Processing photo...',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
            if (_processedImageBytes != null && !_isProcessing) ...[
              const SizedBox(height: 24),
              _buildPreviewCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 2,
      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  AppIcons.camera,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Timestamped Photo Logger',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _isMobile
                  ? 'Take a photo and automatically watermark it with the date, time, and GPS coordinates. The photo is saved to your device gallery.'
                  : 'Take a photo and automatically watermark it with the date and time. The photo is saved to your device.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptureButton() {
    return SizedBox(
      height: 120,
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _capturePhoto,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepOrange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(AppIcons.camera, size: 40),
            const SizedBox(height: 8),
            const Text(
              'Take Photo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(AppIcons.tickCircle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Photo Saved to Gallery',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                _processedImageBytes!,
                fit: BoxFit.contain,
              ),
            ),
            if (_lastTimestamp != null || _lastCoords != null) ...[
              const SizedBox(height: 12),
              if (_lastTimestamp != null)
                Text(
                  'Time: $_lastTimestamp',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              if (_lastCoords != null)
                Text(
                  'Location: $_lastCoords',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _capturePhoto,
                icon: Icon(AppIcons.camera),
                label: const Text('Take Another'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Capture Flow ────────────────────────────────────────────────────────

  Future<void> _capturePhoto() async {
    // Request camera permission
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      if (mounted) {
        context.showWarningToast('Camera permission is required');
      }
      return;
    }

    // Pick image from camera
    final XFile? photo;
    try {
      photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
    } catch (e) {
      if (mounted) {
        context.showErrorToast('Failed to open camera: $e');
      }
      return;
    }

    if (photo == null) return; // User cancelled

    setState(() => _isProcessing = true);

    try {
      // Get timestamp
      final now = DateTime.now();
      final timestamp = DateFormat('dd/MM/yyyy HH:mm:ss').format(now);

      // Get GPS (mobile only, graceful fallback)
      String? coords;
      if (_isMobile) {
        coords = await _getGpsCoords();
      }

      // Read original image bytes
      final originalBytes = await photo.readAsBytes();

      // Watermark the image
      final watermarked = await _watermarkImage(
        originalBytes,
        timestamp,
        coords,
      );

      // Save to gallery
      await Gal.putImageBytes(watermarked, name: 'FireThings_${now.millisecondsSinceEpoch}');

      setState(() {
        _processedImageBytes = watermarked;
        _lastTimestamp = timestamp;
        _lastCoords = coords;
        _isProcessing = false;
      });

      if (mounted) {
        context.showSuccessToast('Photo saved to gallery');
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        context.showErrorToast('Failed to process photo: $e');
      }
    }
  }

  Future<String?> _getGpsCoords() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      return '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
    } catch (e) {
      debugPrint('GPS error: $e');
      return null;
    }
  }

  Future<Uint8List> _watermarkImage(
    Uint8List imageBytes,
    String timestamp,
    String? coords,
  ) async {
    // Decode image
    final codec = await ui.instantiateImageCodec(imageBytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final imgWidth = image.width.toDouble();
    final imgHeight = image.height.toDouble();

    // Create a picture recorder
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw original image
    canvas.drawImage(image, Offset.zero, Paint());

    // Semi-transparent bar at bottom (8% of image height)
    final barHeight = imgHeight * 0.08;
    final barRect = Rect.fromLTWH(0, imgHeight - barHeight, imgWidth, barHeight);
    canvas.drawRect(
      barRect,
      Paint()..color = Colors.black.withValues(alpha: 0.6),
    );

    // Font size scaled to image (~2.5% of height)
    final fontSize = imgHeight * 0.025;
    final textY = imgHeight - barHeight + (barHeight - fontSize) / 2;

    // Left: timestamp
    final timestampParagraph = _buildTextParagraph(
      timestamp,
      fontSize,
      imgWidth * 0.6,
      TextAlign.left,
    );
    canvas.drawParagraph(
      timestampParagraph,
      Offset(imgWidth * 0.02, textY),
    );

    // Right: GPS coordinates (if available)
    if (coords != null) {
      final coordsParagraph = _buildTextParagraph(
        coords,
        fontSize,
        imgWidth * 0.5,
        TextAlign.right,
      );
      canvas.drawParagraph(
        coordsParagraph,
        Offset(imgWidth * 0.48, textY),
      );
    }

    // Convert to image
    final picture = recorder.endRecording();
    final outputImage = await picture.toImage(
      image.width,
      image.height,
    );

    final byteData = await outputImage.toByteData(
      format: ui.ImageByteFormat.png,
    );

    image.dispose();
    outputImage.dispose();

    return byteData!.buffer.asUint8List();
  }

  ui.Paragraph _buildTextParagraph(
    String text,
    double fontSize,
    double maxWidth,
    TextAlign align,
  ) {
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: align,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
      ),
    )
      ..pushStyle(ui.TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
      ))
      ..addText(text);

    final paragraph = builder.build();
    paragraph.layout(ui.ParagraphConstraints(width: maxWidth));
    return paragraph;
  }
}
