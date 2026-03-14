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
import 'overlay_widget.dart';
import 'zoom_gesture_layer.dart';
import 'camera_controls_widget.dart';
import 'camera_settings_panel.dart';
import 'focus_indicator_widget.dart';
import 'lens_selector_widget.dart';
import 'video_processing_screen.dart';

/// Full-screen timestamp camera with live overlay preview, photo capture,
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

  // Zoom — ValueNotifier so only ValueListenableBuilder consumers rebuild
  final ValueNotifier<double> _zoomNotifier = ValueNotifier(1.0);
  double _minZoom = 1.0;
  double _maxZoom = 1.0;

  // Focus
  Offset? _focusPoint;
  bool _showFocusIndicator = false;

  // Recording duration timer (updates top bar only)
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

      // Categorize cameras by direction
      _backCameras = _cameras
          .where((c) => c.lensDirection == CameraLensDirection.back)
          .toList();
      _frontCameras = _cameras
          .where((c) => c.lensDirection == CameraLensDirection.front)
          .toList();

      // Detect ultra-wide camera with multi-pass heuristic
      _mainBackCamera = null;
      _ultraWideCamera = null;

      // Log all cameras for debugging
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

      // Pass 2 — iOS ID-based: parse numeric suffix from AVCaptureDevice IDs
      // e.g. "com.apple.avfoundation.avcapturedevice.built-in_video:0"
      // Lowest suffix (:0) = ultra-wide, next (:2) = wide/main on iPhone Pro
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

      // Pass 3 — generic fallback: if 2+ back cameras, treat non-main as ultra-wide
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

      // Ensure main camera is set even if only one back camera
      _mainBackCamera ??= _backCameras.isNotEmpty ? _backCameras.first : null;
      _hasUltraWide = _ultraWideCamera != null;
      debugPrint('Ultra-wide detected: $_hasUltraWide');

      // Set initial front/back state from actual first camera
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

    // Release old camera FIRST so iOS hardware is free
    _controller = null;
    _isCameraInitialized = false;
    if (prevController != null) {
      try {
        await prevController.dispose();
      } catch (_) {}
      // iOS needs a short delay for AVCaptureSession to release hardware
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await Future.delayed(const Duration(milliseconds: 150));
      }
    }

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

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _cameraError = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _cameraError = 'Camera error: $e');
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
    // Handle ultra-wide lens switching on iOS
    if (_hasUltraWide && !_isUsingFrontCamera) {
      if (zoom < 1.0 && !_isUsingUltraWide) {
        // Switch to ultra-wide camera for 0.5x
        _switchToUltraWide(true);
        return;
      } else if (zoom >= 1.0 && _isUsingUltraWide) {
        // Switch back to main wide camera
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

      final lines = _overlaySettings.buildOverlayLines(
        coords: _locationService.currentCoords,
        address: _locationService.currentAddress,
        dateTime: now,
      );

      final watermarked =
          await TimestampCameraService.instance.watermarkPhoto(
        bytes,
        lines,
        position: _overlaySettings.position,
      );

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
      // Timer for updating the recording duration display only
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

      // Build overlay lines (static parts for FFmpeg)
      final lines = _overlaySettings.buildOverlayLines(
        coords: _locationService.currentCoords,
        address: _locationService.currentAddress,
      );

      if (_isMobile && lines.isNotEmpty) {
        // Extract bundled font to temp file for FFmpeg drawtext
        String? fontPath;
        try {
          final fontData =
              await rootBundle.load('assets/fonts/Inter-Bold.ttf');
          final tempDir = await getTemporaryDirectory();
          final fontFile = File('${tempDir.path}/Inter-Bold.ttf');
          await fontFile.writeAsBytes(fontData.buffer.asUint8List());
          fontPath = fontFile.path;
        } catch (_) {
          // Font extraction failed — filters will omit fontfile param
        }

        final filter = TimestampCameraService.instance
            .buildFallbackFfmpegFilter(
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
      builder: (_) => CameraSettingsPanel(
        settings: _overlaySettings,
        gpsAvailable: _gpsAvailable,
        onSettingsChanged: (newSettings) {
          final resolutionChanged =
              newSettings.resolution != _overlaySettings.resolution;
          setState(() => _overlaySettings = newSettings);
          // Re-init camera if resolution changed
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
          // Camera preview + overlay (overlay inside preview bounds)
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
                    // Camera preview
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CameraPreview(_controller!),
                      ),
                    ),
                    // Overlay — now inside preview bounds
                    Positioned.fill(
                      child: IgnorePointer(
                        child: RepaintBoundary(
                          child: Builder(
                            builder: (context) {
                              // Compute how much safe area overlaps the preview
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

          // Zoom gesture layer (transparent, on top of preview)
          if (_isCameraInitialized && _controller != null)
            Positioned.fill(
              child: ZoomGestureLayer(
                controller: _controller!,
                zoomNotifier: _zoomNotifier,
                minZoom: _hasUltraWide && !_isUsingFrontCamera ? 0.5 : _minZoom,
                maxZoom: _maxZoom,
                onTapDown: _handleTapToFocus,
                onZoomChanged: _setZoom,
              ),
            ),

          // Focus indicator
          if (_showFocusIndicator && _focusPoint != null)
            FocusIndicator(
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
                  return LensSelectorWidget(
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
              child: CameraControlsWidget(
                mode: _mode,
                flashMode: _flashMode,
                isRecording: _isRecording,
                recordingDuration: _recordingDuration,
                onCapture: _onCaptureTap,
                onFlipCamera: _flipCamera,
                onCycleFlash: _cycleFlash,
                onModeChanged: (m) => setState(() => _mode = m),
                canFlip: _cameras.length > 1,
              ),
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
