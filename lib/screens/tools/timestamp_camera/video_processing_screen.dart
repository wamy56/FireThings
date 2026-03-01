import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import '../../../utils/icon_map.dart';
import '../../../utils/theme.dart';
import '../../../widgets/premium_toast.dart';
import '../../../services/timestamp_camera_service.dart';

import 'package:ffmpeg_kit_flutter_new_video/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_video/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new_video/return_code.dart';
import 'package:ffmpeg_kit_flutter_new_video/statistics.dart';

/// Screen shown after video recording stops. Runs FFmpeg to burn overlays
/// into video frames, shows progress, then saves to gallery.
class VideoProcessingScreen extends StatefulWidget {
  final String inputPath;
  final String ffmpegFilter;
  final int totalDurationMs;
  final DateTime? recordingStartTime;

  const VideoProcessingScreen({
    super.key,
    required this.inputPath,
    required this.ffmpegFilter,
    required this.totalDurationMs,
    this.recordingStartTime,
  });

  @override
  State<VideoProcessingScreen> createState() => _VideoProcessingScreenState();
}

class _VideoProcessingScreenState extends State<VideoProcessingScreen> {
  double _progress = 0.0;
  bool _isProcessing = true;
  bool _failed = false;
  bool _showActions = false;
  String _statusText = 'Preparing video...';
  String? _errorDetail;

  @override
  void initState() {
    super.initState();
    _processVideo();
  }

  Future<void> _processVideo() async {
    if (widget.ffmpegFilter.isEmpty) {
      await _saveToGallery(widget.inputPath);
      return;
    }

    setState(() {
      _isProcessing = true;
      _failed = false;
      _showActions = false;
      _progress = 0.0;
      _statusText = 'Processing video...';
      _errorDetail = null;
    });

    final outputPath = widget.inputPath.replaceAll('.mp4', '_stamped.mp4');

    FFmpegKitConfig.enableStatisticsCallback((Statistics statistics) {
      if (widget.totalDurationMs > 0) {
        final time = statistics.getTime();
        if (mounted) {
          setState(() {
            _progress = (time / widget.totalDurationMs).clamp(0.0, 1.0);
            _statusText = 'Processing... ${(_progress * 100).toInt()}%';
          });
        }
      }
    });

    final command =
        '-i "${widget.inputPath}" -vf "${widget.ffmpegFilter}" -codec:a copy -preset ultrafast -y "$outputPath"';

    try {
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        await _saveToGallery(outputPath);
        _deleteFile(widget.inputPath);
        _deleteFile(outputPath);
      } else {
        final logs = await session.getAllLogsAsString();
        _handleFailure('FFmpeg failed with code: $returnCode', logs);
      }
    } catch (e) {
      _handleFailure('FFmpeg error: $e', null);
    }
  }

  void _handleFailure(String message, String? logs) {
    debugPrint(message);
    if (logs != null) debugPrint(logs);
    if (mounted) {
      setState(() {
        _isProcessing = false;
        _failed = true;
        _showActions = true;
        _statusText = 'Overlay processing failed';
        _errorDetail = message;
      });
    }
  }

  Future<void> _retryWithFallback() async {
    if (widget.recordingStartTime == null) {
      // No start time — can't build fallback filter, just save raw
      await _saveWithoutOverlay();
      return;
    }

    setState(() {
      _isProcessing = true;
      _failed = false;
      _showActions = false;
      _progress = 0.0;
      _statusText = 'Retrying with fallback filter...';
      _errorDetail = null;
    });

    // Build fallback per-second filter
    // We need the settings, so we load them fresh
    final settings = await TimestampCameraService.instance.loadSettings();
    final fallbackFilter =
        TimestampCameraService.instance.buildFallbackFfmpegFilter(
      settings: settings,
      recordingStartTime: widget.recordingStartTime!,
      durationMs: widget.totalDurationMs,
    );

    if (fallbackFilter.isEmpty) {
      await _saveWithoutOverlay();
      return;
    }

    final outputPath = widget.inputPath.replaceAll('.mp4', '_stamped.mp4');

    final command =
        '-i "${widget.inputPath}" -vf "$fallbackFilter" -codec:a copy -preset ultrafast -y "$outputPath"';

    try {
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        await _saveToGallery(outputPath);
        _deleteFile(widget.inputPath);
        _deleteFile(outputPath);
      } else {
        // Fallback also failed — show save without overlay
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _failed = true;
            _showActions = true;
            _statusText = 'Overlay processing failed';
            _errorDetail = 'Both primary and fallback filters failed';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _failed = true;
          _showActions = true;
          _statusText = 'Overlay processing failed';
          _errorDetail = 'Fallback error: $e';
        });
      }
    }
  }

  Future<void> _saveWithoutOverlay() async {
    setState(() {
      _isProcessing = true;
      _statusText = 'Saving raw video...';
    });
    await _saveToGallery(widget.inputPath);
    _deleteFile(widget.inputPath);
  }

  Future<void> _saveToGallery(String path) async {
    try {
      await Gal.putVideo(path);
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _progress = 1.0;
          _statusText = _failed
              ? 'Saved raw video (overlay processing failed)'
              : 'Video saved to gallery';
        });

        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          if (_failed) {
            context.showWarningToast('Video saved without overlays');
          } else {
            context.showSuccessToast('Video saved to gallery');
          }
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _failed = true;
          _showActions = true;
          _statusText = 'Failed to save video';
          _errorDetail = '$e';
        });
        context.showErrorToast('Failed to save video: $e');
      }
    }
  }

  void _deleteFile(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isProcessing,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isProcessing
                      ? AppIcons.video
                      : (_failed ? AppIcons.warning : AppIcons.tickCircle),
                  size: 64,
                  color: _isProcessing
                      ? Colors.white
                      : (_failed ? Colors.orange : Colors.green),
                ),
                const SizedBox(height: 32),
                Text(
                  _statusText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_errorDetail != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _errorDetail!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 24),
                // Progress bar
                if (_isProcessing) ...[
                  SizedBox(
                    width: 240,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _progress > 0 ? _progress : null,
                        minHeight: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.accentOrange,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Do not close the app',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
                // Error actions: Retry + Save Without Overlay
                if (_showActions) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 240,
                    child: ElevatedButton.icon(
                      onPressed: _retryWithFallback,
                      icon: Icon(AppIcons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentOrange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 240,
                    child: OutlinedButton.icon(
                      onPressed: _saveWithoutOverlay,
                      icon: Icon(AppIcons.save),
                      label: const Text('Save without overlay'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ),
                ],
                // Done button when complete (non-error)
                if (!_isProcessing && !_showActions) ...[
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
