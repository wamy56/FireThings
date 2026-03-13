import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../utils/icon_map.dart';
import '../../../utils/adaptive_widgets.dart';
import '../../../widgets/premium_toast.dart';
import '../../../services/analytics_service.dart';
import '../../../services/location_service.dart';
import '../../../services/timestamp_camera_service.dart';
import 'camera_overlay_painter.dart';
import 'overlay_settings_sheet.dart';
import 'video_processing_screen.dart';

enum CameraMode { photo, video }

/// Full-screen timestamp camera with per-corner overlay, photo capture,
/// video recording, and configurable metadata overlays.
class TimestampCameraScreen extends StatefulWidget {
  const TimestampCameraScreen({super.key});

  @override
  State<TimestampCameraScreen> createState() => _TimestampCameraScreenState();
}

class _TimestampCameraScreenState extends State<TimestampCameraScreen>
    with WidgetsBindingObserver {
  // Camera
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  List<CameraDescription> _backCameras = [];
  List<CameraDescription> _frontCameras = [];
  CameraDescription? _mainBackCamera;
  CameraDescription? _ultraWideCamera;
  int _currentCameraIndex = 0;
  bool _isCameraInitialized = false;
  bool _isUsingUltraWide = false;
  bool _hasUltraWide = false;
  bool _isUsingFrontCamera = false;
  String? _cameraError;

  // Mode & state
  CameraMode _mode = CameraMode.photo;
  FlashMode _flashMode = FlashMode.auto;
  bool _isRecording = false;
  bool _isProcessing = false;
  bool _isFlipping = false;
  DateTime? _recordingStart;
  Duration _recordingDuration = Duration.zero;

  // Overlay
  OverlaySettings _overlaySettings = const OverlaySettings();

  // Location
  final _locationService = LocationService.instance;
  bool _gpsAvailable = false;

  // Zoom
  final ValueNotifier<double> _zoomNotifier = ValueNotifier(1.0);
  double _minZoom = 1.0;
  double _maxZoom = 1.0;

  // Focus
  Offset? _focusPoint;
  bool _showFocusIndicator = false;

  // Recording duration timer
  Timer? _durationTimer;

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS);

  bool get _isUnsupported =>
      kIsWeb || defaultTargetPlatform == TargetPlatform.linux;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _init();
  }

  Future<void> _init() async {
    _overlaySettings = await TimestampCameraService.instance.loadSettings();
    await _requestPermissions();
    await _initCamera();
    _startLocationTracking();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _durationTimer?.cancel();
    _zoomNotifier.dispose();
    _locationService.stopTracking();
    SystemChrome.setPreferredOrientations([]);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      if (_controller != null && _isCameraInitialized) {
        _handleInactive();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (!_isCameraInitialized) {
        _initCamera();
      }
    }
  }

  Future<void> _handleInactive() async {
    if (_isRecording) await _stopRecording();
    final controller = _controller;
    _controller = null;
    if (mounted) setState(() => _isCameraInitialized = false);
    await controller?.dispose();
  }

  // ─── Permissions ───────────────────────────────────────────────────

  Future<void> _requestPermissions() async {
    await Permission.camera.request();
    if (_isMobile) await Permission.microphone.request();
  }

  // ─── Camera Init ───────────────────────────────────────────────────

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _cameraError = 'No cameras found on this device');
        return;
      }

      _backCameras = _cameras
          .where((c) => c.lensDirection == CameraLensDirection.back)
          .toList();
      _frontCameras = _cameras
          .where((c) => c.lensDirection == CameraLensDirection.front)
          .toList();

      // Detect ultra-wide camera with 3-pass heuristic
      _mainBackCamera = null;
      _ultraWideCamera = null;

      for (final cam in _backCameras) {
        debugPrint('Back camera: name="${cam.name}", direction=${cam.lensDirection}');
      }

      // Pass 1 — name-based (works on Android)
      for (final cam in _backCameras) {
        final nameLower = cam.name.toLowerCase();
        if (nameLower.contains('ultra') || nameLower.contains('wide')) {
          _ultraWideCamera ??= cam;
        } else {
          _mainBackCamera ??= cam;
        }
      }

      // Pass 2 — iOS ID suffix-based
      if (_ultraWideCamera == null &&
          _backCameras.length >= 2 &&
          defaultTargetPlatform == TargetPlatform.iOS) {
        final parsed = <CameraDescription, int>{};
        final suffixRegex = RegExp(r':(\d+)$');
        for (final cam in _backCameras) {
          final match = suffixRegex.firstMatch(cam.name);
          if (match != null) {
            parsed[cam] = int.parse(match.group(1)!);
          }
        }
        if (parsed.length >= 2) {
          final sorted = parsed.entries.toList()
            ..sort((a, b) => a.value.compareTo(b.value));
          _ultraWideCamera = sorted.first.key;
          _mainBackCamera = sorted[1].key;
          debugPrint('iOS camera assignment: ultra-wide="${_ultraWideCamera!.name}", main="${_mainBackCamera!.name}"');
        }
      }

      // Pass 3 — generic fallback
      if (_ultraWideCamera == null && _backCameras.length >= 2) {
        _mainBackCamera ??= _backCameras.first;
        for (final cam in _backCameras) {
          if (cam != _mainBackCamera) {
            _ultraWideCamera = cam;
            debugPrint('Fallback ultra-wide: "${cam.name}"');
            break;
          }
        }
      }

      _mainBackCamera ??= _backCameras.isNotEmpty ? _backCameras.first : null;
      _hasUltraWide = _ultraWideCamera != null;
      debugPrint('Ultra-wide detected: $_hasUltraWide');

      _isUsingFrontCamera = _cameras[_currentCameraIndex].lensDirection ==
          CameraLensDirection.front;

      await _setupController(_cameras[_currentCameraIndex]);
    } catch (e) {
      setState(() => _cameraError = 'Failed to initialise camera: $e');
    }
  }

  Future<void> _setupController(CameraDescription camera) async {
    final prevController = _controller;
    final resolutionPreset = _resolutionFromSettings();

    final controller = CameraController(
      camera,
      resolutionPreset,
      enableAudio: _isMobile,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    _controller = controller;

    try {
      await controller.initialize();
      await controller.setFlashMode(_flashMode);

      _minZoom = await controller.getMinZoomLevel();
      _maxZoom = (await controller.getMaxZoomLevel()).clamp(1.0, 20.0);
      _zoomNotifier.value = _minZoom;

      await prevController?.dispose();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _cameraError = null;
        });
      }
    } catch (e) {
      setState(() => _cameraError = 'Camera error: $e');
    }
  }

  ResolutionPreset _resolutionFromSettings() {
    switch (_overlaySettings.resolution) {
      case 'low':
        return ResolutionPreset.medium;
      case 'medium':
        return ResolutionPreset.high;
      case 'high':
      default:
        return ResolutionPreset.veryHigh;
    }
  }

  // ─── Location ──────────────────────────────────────────────────────

  Future<void> _startLocationTracking() async {
    if (!_isMobile && !_isDesktop) return;
    final ok = await _locationService.startTracking();
    if (mounted) setState(() => _gpsAvailable = ok);
  }

  // ─── Camera Controls ──────────────────────────────────────────────

  Future<void> _flipCamera() async {
    if (_isRecording || _isFlipping) return;
    if (_frontCameras.isEmpty || _backCameras.isEmpty) return;
    setState(() => _isFlipping = true);
    try {
      _isUsingFrontCamera = !_isUsingFrontCamera;
      _isUsingUltraWide = false;
      final camera = _isUsingFrontCamera
          ? _frontCameras.first
          : (_mainBackCamera ?? _backCameras.first);
      _currentCameraIndex = _cameras.indexOf(camera);
      await _setupController(camera);
    } catch (e) {
      debugPrint('Flip camera error: $e');
    } finally {
      if (mounted) setState(() => _isFlipping = false);
    }
  }

  Future<void> _switchToUltraWide(bool useUltraWide) async {
    if (_isRecording || _isFlipping || !_hasUltraWide) return;
    if (useUltraWide == _isUsingUltraWide) return;
    setState(() => _isFlipping = true);
    try {
      final camera = useUltraWide
          ? _ultraWideCamera!
          : (_mainBackCamera ?? _backCameras.first);
      _currentCameraIndex = _cameras.indexOf(camera);
      _isUsingUltraWide = useUltraWide;
      _isUsingFrontCamera = false;
      await _setupController(camera);
    } catch (e) {
      debugPrint('Switch ultra-wide error: $e');
    } finally {
      if (mounted) setState(() => _isFlipping = false);
    }
  }

  Future<void> _cycleFlash() async {
    if (_controller == null) return;
    final modes = [FlashMode.auto, FlashMode.always, FlashMode.off];
    final currentIndex = modes.indexOf(_flashMode);
    _flashMode = modes[(currentIndex + 1) % modes.length];
    try {
      await _controller!.setFlashMode(_flashMode);
    } catch (_) {}
    setState(() {});
  }

  void _setZoom(double zoom) {
    if (_hasUltraWide && !_isUsingFrontCamera) {
      if (zoom < 1.0 && !_isUsingUltraWide) {
        _switchToUltraWide(true);
        return;
      } else if (zoom >= 1.0 && _isUsingUltraWide) {
        _switchToUltraWide(false).then((_) {
          if (zoom > 1.0) {
            final clamped = zoom.clamp(_minZoom, _maxZoom);
            _zoomNotifier.value = clamped;
            try {
              _controller?.setZoomLevel(clamped);
            } catch (_) {}
          }
        });
        return;
      }
    }

    final clamped = zoom.clamp(_minZoom, _maxZoom);
    _zoomNotifier.value = clamped;
    try {
      _controller?.setZoomLevel(clamped);
    } catch (_) {}
  }

  // ─── Capture ──────────────────────────────────────────────────────

  Future<void> _onCaptureTap() async {
    if (_mode == CameraMode.photo) {
      await _capturePhoto();
    } else {
      if (_isRecording) {
        await _stopRecording();
      } else {
        await _startRecording();
      }
    }
  }

  Future<void> _capturePhoto() async {
    if (_controller == null || _isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final xFile = await _controller!.takePicture();
      final bytes = await xFile.readAsBytes();
      final now = DateTime.now();

      final cornerTexts = _overlaySettings.buildCornerTexts(
        coords: _locationService.currentCoords,
        address: _locationService.currentAddress,
        dateTime: now,
      );

      final watermarked =
          await TimestampCameraService.instance.watermarkPhoto(bytes, cornerTexts);

      await Gal.putImageBytes(
        watermarked,
        name: 'FireThings_${now.millisecondsSinceEpoch}',
      );

      AnalyticsService.instance.logPhotoCaptured();
      if (mounted) context.showSuccessToast('Photo saved to gallery');

      try {
        await File(xFile.path).delete();
      } catch (_) {}
    } catch (e) {
      if (mounted) context.showErrorToast('Failed to capture photo: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _startRecording() async {
    if (_controller == null || _isRecording) return;

    try {
      await _controller!.startVideoRecording();
      AnalyticsService.instance.logVideoRecordingStarted();
      setState(() {
        _isRecording = true;
        _recordingStart = DateTime.now();
        _recordingDuration = Duration.zero;
      });
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_isRecording && _recordingStart != null) {
          setState(() {
            _recordingDuration = DateTime.now().difference(_recordingStart!);
          });
        }
      });
    } catch (e) {
      if (mounted) context.showErrorToast('Failed to start recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (_controller == null || !_isRecording) return;

    _durationTimer?.cancel();
    _durationTimer = null;

    try {
      final xFile = await _controller!.stopVideoRecording();
      AnalyticsService.instance.logVideoRecordingCompleted();
      final durationMs = _recordingDuration.inMilliseconds;
      final recordingStartTime = _recordingStart;

      setState(() {
        _isRecording = false;
        _recordingStart = null;
        _recordingDuration = Duration.zero;
      });

      if (_isMobile && _overlaySettings.hasAnyOverlay) {
        // Extract bundled font to temp file for FFmpeg drawtext
        String? fontPath;
        try {
          final fontData =
              await rootBundle.load('assets/fonts/Inter-Bold.ttf');
          final tempDir = await getTemporaryDirectory();
          final fontFile = File('${tempDir.path}/Inter-Bold.ttf');
          await fontFile.writeAsBytes(fontData.buffer.asUint8List());
          fontPath = fontFile.path;
        } catch (_) {}

        final filter = TimestampCameraService.instance.buildFfmpegFilter(
          settings: _overlaySettings,
          recordingStartTime: recordingStartTime ?? DateTime.now(),
          durationMs: durationMs,
          coords: _locationService.currentCoords,
          address: _locationService.currentAddress,
          fontPath: fontPath,
        );

        if (mounted) {
          Navigator.push(
            context,
            adaptivePageRoute(
              builder: (_) => VideoProcessingScreen(
                inputPath: xFile.path,
                ffmpegFilter: filter,
                totalDurationMs: durationMs,
                recordingStartTime: recordingStartTime,
                fontPath: fontPath,
                settings: _overlaySettings,
                coords: _locationService.currentCoords,
                address: _locationService.currentAddress,
              ),
            ),
          );
        }
      } else {
        await Gal.putVideo(xFile.path);
        if (mounted) context.showSuccessToast('Video saved to gallery');
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
        _recordingStart = null;
      });
      if (mounted) context.showErrorToast('Failed to save video: $e');
    }
  }

  // ─── Focus ─────────────────────────────────────────────────────────

  Future<void> _handleTapToFocus(
    Offset localPosition,
    BoxConstraints constraints,
  ) async {
    final controller = _controller;
    if (controller == null) return;

    setState(() {
      _focusPoint = localPosition;
      _showFocusIndicator = true;
    });

    final x = localPosition.dx / constraints.maxWidth;
    final y = localPosition.dy / constraints.maxHeight;
    final point = Offset(x.clamp(0.0, 1.0), y.clamp(0.0, 1.0));

    try {
      await controller.setFocusPoint(point);
      await controller.setExposurePoint(point);
      await controller.setFocusMode(FocusMode.auto);
    } catch (_) {}
  }

  // ─── Settings ─────────────────────────────────────────────────────

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OverlaySettingsSheet(
        settings: _overlaySettings,
        gpsAvailable: _gpsAvailable,
        onSettingsChanged: (newSettings) {
          final resolutionChanged =
              newSettings.resolution != _overlaySettings.resolution;
          setState(() => _overlaySettings = newSettings);
          if (resolutionChanged) {
            _setupController(_cameras[_currentCameraIndex]);
          }
        },
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isUnsupported) return _buildUnsupportedScreen();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview + overlay
          if (_isFlipping)
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          else if (_isCameraInitialized && _controller != null)
            Center(
              child: AspectRatio(
                aspectRatio: 1 / _controller!.value.aspectRatio,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CameraPreview(_controller!),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: RepaintBoundary(
                          child: Builder(
                            builder: (context) {
                              final screenHeight = MediaQuery.of(context).size.height;
                              final screenWidth = MediaQuery.of(context).size.width;
                              final previewAspect = 1 / _controller!.value.aspectRatio;
                              final previewHeight = screenWidth / previewAspect;
                              final previewTopOffset = (screenHeight - previewHeight) / 2;
                              final safeAreaTop = (MediaQuery.of(context).padding.top - previewTopOffset)
                                  .clamp(0.0, double.infinity);
                              return OverlayWidget(
                                settings: _overlaySettings,
                                locationService: _locationService,
                                safeAreaTop: safeAreaTop,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_cameraError != null)
            _buildErrorView()
          else
            const Center(child: AdaptiveLoadingIndicator()),

          // Tap to focus + pinch to zoom
          if (_isCameraInitialized && _controller != null)
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTapDown: (details) {
                      _handleTapToFocus(details.localPosition, constraints);
                    },
                    onScaleUpdate: (details) {
                      if (details.pointerCount >= 2) {
                        final newZoom = _zoomNotifier.value * details.scale;
                        _setZoom(newZoom);
                      }
                    },
                  );
                },
              ),
            ),

          // Focus indicator
          if (_showFocusIndicator && _focusPoint != null)
            _FocusIndicator(
              position: _focusPoint!,
              onAnimationComplete: () {
                if (mounted) setState(() => _showFocusIndicator = false);
              },
            ),

          // Top bar
          _buildTopBar(),

          // Lens selector
          if (_isCameraInitialized && (_maxZoom > _minZoom || _hasUltraWide))
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 180,
              left: 0,
              right: 0,
              child: ValueListenableBuilder<double>(
                valueListenable: _zoomNotifier,
                builder: (context, zoom, _) {
                  return _LensSelectorWidget(
                    currentZoom: _isUsingUltraWide ? 0.5 : zoom,
                    minZoom: _minZoom,
                    maxZoom: _maxZoom,
                    hasUltraWide: _hasUltraWide && !_isUsingFrontCamera,
                    onZoomChanged: _setZoom,
                  );
                },
              ),
            ),

          // Processing overlay
          if (_isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AdaptiveLoadingIndicator(),
                    SizedBox(height: 12),
                    Text(
                      'Processing...',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom controls
          if (_isCameraInitialized)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomControls(),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 8,
          right: 8,
          bottom: 8,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.4),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: Icon(AppIcons.arrowLeft, color: Colors.white),
              onPressed: () async {
                if (_isRecording) await _stopRecording();
                if (mounted) Navigator.of(context).pop();
              },
            ),
            const Spacer(),
            if (_isRecording) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatDuration(_recordingDuration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
            if (!_isRecording) const Spacer(),
            IconButton(
              icon: Icon(AppIcons.settingOutline, color: Colors.white),
              onPressed: _isRecording ? null : _openSettings,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: Colors.black.withValues(alpha: 0.3),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mode toggle (hidden while recording)
            if (!_isRecording)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildModeToggle(),
              ),
            // Controls row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCircleButton(
                  icon: _flashIcon(),
                  onTap: _isRecording ? null : _cycleFlash,
                  size: 48,
                ),
                _buildShutterButton(),
                _buildCircleButton(
                  icon: AppIcons.rotateRight,
                  onTap: (_cameras.length > 1 && !_isRecording) ? _flipCamera : null,
                  size: 48,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModeChip(CameraMode.photo, 'Photo', AppIcons.camera),
          const SizedBox(width: 4),
          _buildModeChip(CameraMode.video, 'Video', AppIcons.video),
        ],
      ),
    );
  }

  Widget _buildModeChip(CameraMode chipMode, String label, IconData icon) {
    final isSelected = _mode == chipMode;
    return GestureDetector(
      onTap: () => setState(() => _mode = chipMode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withValues(alpha: 0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShutterButton() {
    final isVideo = _mode == CameraMode.video;
    return GestureDetector(
      onTap: _onCaptureTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: _isRecording ? Colors.red : Colors.white,
            width: 4,
          ),
        ),
        padding: const EdgeInsets.all(4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isVideo ? Colors.red : Colors.white,
            shape: _isRecording ? BoxShape.rectangle : BoxShape.circle,
            borderRadius: _isRecording ? BorderRadius.circular(8) : null,
          ),
          margin: _isRecording ? const EdgeInsets.all(10) : EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback? onTap,
    double size = 44,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: onTap != null ? 0.2 : 0.08),
        ),
        child: Icon(
          icon,
          color: onTap != null
              ? Colors.white
              : Colors.white.withValues(alpha: 0.3),
          size: size * 0.5,
        ),
      ),
    );
  }

  IconData _flashIcon() {
    switch (_flashMode) {
      case FlashMode.auto:
        return AppIcons.flash;
      case FlashMode.always:
        return AppIcons.flashBold;
      case FlashMode.off:
        return AppIcons.flashSlash;
      case FlashMode.torch:
        return AppIcons.flashBold;
    }
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(AppIcons.danger, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              _cameraError ?? 'Camera error',
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initCamera,
              icon: Icon(AppIcons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnsupportedScreen() {
    return Scaffold(
      appBar: AppBar(title: const Text('Timestamp Camera')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(AppIcons.camera, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Timestamp Camera is not supported on this platform.',
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

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

// ─── Inline Widgets ────────────────────────────────────────────────

/// iOS-style yellow focus square.
class _FocusIndicator extends StatefulWidget {
  final Offset position;
  final VoidCallback onAnimationComplete;

  const _FocusIndicator({
    required this.position,
    required this.onAnimationComplete,
  });

  @override
  State<_FocusIndicator> createState() => _FocusIndicatorState();
}

class _FocusIndicatorState extends State<_FocusIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onAnimationComplete();
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.position.dx - 35,
      top: widget.position.dy - 35,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          double scale;
          double opacity;

          if (t < 0.15) {
            scale = 1.3 - (0.3 * (t / 0.15));
            opacity = 1.0;
          } else if (t < 0.70) {
            scale = 1.0;
            opacity = 1.0;
          } else {
            scale = 1.0;
            opacity = 1.0 - ((t - 0.70) / 0.30);
          }

          return Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: child,
            ),
          );
        },
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            border: Border.all(
              color: const Color(0xFFFFCC00),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

/// Lens selector with 0.5x / 1x / 2x / 5x stops.
class _LensSelectorWidget extends StatelessWidget {
  final double currentZoom;
  final double minZoom;
  final double maxZoom;
  final bool hasUltraWide;
  final ValueChanged<double> onZoomChanged;

  const _LensSelectorWidget({
    required this.currentZoom,
    required this.minZoom,
    required this.maxZoom,
    this.hasUltraWide = false,
    required this.onZoomChanged,
  });

  @override
  Widget build(BuildContext context) {
    final stops = <_LensStop>[];

    if (hasUltraWide || minZoom <= 0.6) {
      stops.add(const _LensStop(label: '.5', zoom: 0.5));
    }
    stops.add(const _LensStop(label: '1x', zoom: 1.0));
    if (maxZoom >= 2.0) {
      stops.add(const _LensStop(label: '2x', zoom: 2.0));
    }
    if (maxZoom >= 5.0) {
      stops.add(const _LensStop(label: '5x', zoom: 5.0));
    }

    if (stops.length < 2) return const SizedBox.shrink();

    int activeIndex = 0;
    double minDist = double.infinity;
    for (var i = 0; i < stops.length; i++) {
      final dist = (stops[i].zoom - currentZoom).abs();
      if (dist < minDist && dist <= 0.25) {
        minDist = dist;
        activeIndex = i;
      }
    }
    final hasActive = minDist <= 0.25;
    final showDynamic = !hasActive;
    final dynamicLabel = '${currentZoom.toStringAsFixed(1)}x';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (showDynamic)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: const Color(0xFFFFCC00),
              ),
              alignment: Alignment.center,
              child: Text(
                dynamicLabel,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ...stops.asMap().entries.map((entry) {
          final i = entry.key;
          final stop = entry.value;
          final isActive = hasActive && i == activeIndex;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => onZoomChanged(stop.zoom.clamp(minZoom, maxZoom)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isActive ? 36 : 32,
                height: isActive ? 36 : 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? const Color(0xFFFFCC00)
                      : Colors.black.withValues(alpha: 0.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  stop.label,
                  style: TextStyle(
                    color: isActive ? Colors.black : Colors.white,
                    fontSize: isActive ? 13 : 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _LensStop {
  final String label;
  final double zoom;
  const _LensStop({required this.label, required this.zoom});
}
