import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import '../../../utils/icon_map.dart';
import '../../../utils/theme.dart';
import '../../../widgets/premium_toast.dart';

// Conditional import: FFmpeg is only available on mobile
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:ffmpeg_kit_flutter_new_min/statistics.dart';

/// Screen shown after video recording stops. Runs FFmpeg to burn overlays
/// into video frames, shows progress, then saves to gallery.
class VideoProcessingScreen extends StatefulWidget {
  final String inputPath;
  final String ffmpegFilter;
  final int totalDurationMs;

  const VideoProcessingScreen({
    super.key,
    required this.inputPath,
    required this.ffmpegFilter,
    required this.totalDurationMs,
  });

  @override
  State<VideoProcessingScreen> createState() => _VideoProcessingScreenState();
}

class _VideoProcessingScreenState extends State<VideoProcessingScreen> {
  double _progress = 0.0;
  bool _isProcessing = true;
  bool _failed = false;
  String _statusText = 'Preparing video...';

  @override
  void initState() {
    super.initState();
    _processVideo();
  }

  Future<void> _processVideo() async {
    if (widget.ffmpegFilter.isEmpty) {
      // No overlays to burn in — just save raw video
      await _saveToGallery(widget.inputPath);
      return;
    }

    final outputPath = widget.inputPath.replaceAll('.mp4', '_stamped.mp4');

    // Enable statistics callback for progress tracking
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
        // Clean up temp files
        _deleteFile(widget.inputPath);
        _deleteFile(outputPath);
      } else {
        debugPrint('FFmpeg failed with code: $returnCode');
        // Fallback: save raw video
        setState(() => _failed = true);
        await _saveToGallery(widget.inputPath);
        _deleteFile(widget.inputPath);
      }
    } catch (e) {
      debugPrint('FFmpeg error: $e');
      setState(() => _failed = true);
      await _saveToGallery(widget.inputPath);
      _deleteFile(widget.inputPath);
    }
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

        // Auto-pop after brief delay
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
          _statusText = 'Failed to save video';
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
                // Animated icon
                Icon(
                  _isProcessing ? AppIcons.video : (_failed ? AppIcons.warning : AppIcons.tickCircle),
                  size: 64,
                  color: _isProcessing
                      ? Colors.white
                      : (_failed ? Colors.orange : Colors.green),
                ),
                const SizedBox(height: 32),
                // Status text
                Text(
                  _statusText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
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
                // Close button when done
                if (!_isProcessing) ...[
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
