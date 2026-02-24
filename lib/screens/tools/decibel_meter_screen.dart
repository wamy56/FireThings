import 'dart:async';
import '../../widgets/premium_dialog.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:noise_meter/noise_meter.dart';
import '../../utils/icon_map.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../widgets/premium_toast.dart';
import '../../widgets/adaptive_app_bar.dart';

class DecibelMeterScreen extends StatefulWidget {
  const DecibelMeterScreen({super.key});

  @override
  State<DecibelMeterScreen> createState() => _DecibelMeterScreenState();
}

class _DecibelMeterScreenState extends State<DecibelMeterScreen>
    with SingleTickerProviderStateMixin {
  NoiseMeter? _noiseMeter;
  StreamSubscription<NoiseReading>? _noiseSubscription;

  late AnimationController _pulseController;

  // Current readings
  double _currentDecibels = 0;
  double _maxDecibels = 0;
  double _minDecibels = 0;
  double _avgDecibels = 0;

  // Measurement state
  bool _isRecording = false;
  bool _hasPermission = false;

  // Refresh mode
  bool _fastMode = true;
  DateTime? _lastUiUpdate;

  // Data for averaging
  final List<double> _readings = [];
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _noiseMeter = NoiseMeter();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
    _requestPermission();
  }

  @override
  void dispose() {
    _noiseSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _requestPermission() async {
    final status = await Permission.microphone.request();
    if (mounted) {
      setState(() {
        _hasPermission = status.isGranted;
      });
    }

    if (status.isPermanentlyDenied) {
      if (mounted) {
        context.showWarningToast('Please enable microphone in Settings');
        await openAppSettings();
      }
    } else if (!status.isGranted) {
      if (mounted) {
        context.showWarningToast('Microphone permission is required for the decibel meter');
      }
    } else {
      // Show limitation notice on first use
      if (mounted) {
        context.showInfoToast('Note: Phone microphones typically max out at 90-100 dB due to hardware limitations');
      }
    }
  }

  void _startRecording() {
    if (!_hasPermission) {
      _requestPermission();
      return;
    }

    try {
      _noiseSubscription = _noiseMeter?.noise.listen((NoiseReading reading) {
        if (mounted) {
          final double db = reading.meanDecibel.clamp(0.0, 120.0);

          // Always accumulate readings for accurate stats
          _readings.add(db);
          if (_readings.length > 100) {
            _readings.removeAt(0);
          }

          if (_readings.length == 1) {
            _maxDecibels = db;
            _minDecibels = db;
          } else {
            _maxDecibels = max(_maxDecibels, db);
            _minDecibels = min(_minDecibels, db);
          }
          _avgDecibels = _readings.reduce((a, b) => a + b) / _readings.length;

          // Throttle UI updates based on mode
          final now = DateTime.now();
          final threshold = _fastMode ? 100 : 1000;
          if (_lastUiUpdate == null ||
              now.difference(_lastUiUpdate!).inMilliseconds >= threshold) {
            _lastUiUpdate = now;
            setState(() {
              _currentDecibels = db;
            });
          }
        }
      });

      if (mounted) {
        setState(() {
          _isRecording = true;
          _startTime = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        context.showErrorToast('Error starting measurement: $e');
      }
    }
  }

  void _stopRecording() {
    _noiseSubscription?.cancel();
    if (mounted) {
      setState(() {
        _isRecording = false;
      });
    }
  }

  void _resetMeasurement() {
    if (mounted) {
      setState(() {
        _currentDecibels = 0;
        _maxDecibels = 0;
        _minDecibels = 0;
        _avgDecibels = 0;
        _readings.clear();
        _startTime = null;
      });
    }
  }

  Color _getDecibelColor(double db) {
    if (db < 40) return Colors.green;
    if (db < 60) return Colors.lightGreen;
    if (db < 80) return Colors.orange;
    if (db < 100) return Colors.deepOrange;
    return Colors.red;
  }

  String _getDecibelLevel(double db) {
    if (db < 40) return 'Quiet';
    if (db < 60) return 'Moderate';
    if (db < 80) return 'Loud';
    if (db < 100) return 'Very Loud';
    return 'Harmful';
  }

  IconData _getDecibelIcon(double db) {
    if (db < 40) return AppIcons.sound;
    if (db < 60) return AppIcons.sound;
    if (db < 80) return AppIcons.volumeHigh;
    return AppIcons.warning;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdaptiveNavigationBar(
        title: 'Decibel Meter',
        actions: [
          IconButton(
            icon: Icon(AppIcons.infoCircle),
            onPressed: _showInfoDialog,
            tooltip: 'Information',
          ),
        ],
      ),
      body: !_hasPermission ? _buildPermissionRequest() : _buildDecibelMeter(),
    );
  }

  Widget _buildPermissionRequest() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(AppIcons.microphone, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 24),
            Text(
              'Microphone Permission Required',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'This app needs access to your microphone to measure sound levels.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _requestPermission,
              icon: Icon(AppIcons.microphone),
              label: const Text('Grant Permission'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDecibelMeter() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMainDisplay(),
          const SizedBox(height: 24),
          _buildControls(),
          const SizedBox(height: 12),
          _buildRefreshToggle(),
          const SizedBox(height: 24),
          _buildStatistics(),
          const SizedBox(height: 24),
          _buildReferenceChart(),
        ],
      ),
    );
  }

  Widget _buildMainDisplay() {
    final color = _getDecibelColor(_currentDecibels);
    final level = _getDecibelLevel(_currentDecibels);
    final icon = _getDecibelIcon(_currentDecibels);

    return Card(
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withValues(alpha:0.1), color.withValues(alpha:0.05)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            // Icon with pulse animation
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _isRecording
                      ? 1.0 + (_pulseController.value * 0.1)
                      : 1.0,
                  child: Icon(icon, size: 48, color: color),
                );
              },
            ),
            const SizedBox(height: 12),

            // Current dB reading
            Text(
              _currentDecibels.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              'dB',
              style: TextStyle(
                fontSize: 24,
                color: color.withValues(alpha:0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),

            // Level indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha:0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color, width: 2),
              ),
              child: Text(
                level.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Visual meter bar
            _buildMeterBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildMeterBar() {
    final percentage = (_currentDecibels / 120).clamp(0.0, 1.0);
    final color = _getDecibelColor(_currentDecibels);

    return Column(
      children: [
        Stack(
          children: [
            // Background bar
            Container(
              height: 24,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            // Filled bar
            FractionallySizedBox(
              widthFactor: percentage,
              child: Container(
                height: 24,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha:0.7)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Scale markers
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildScaleMarker('0', Colors.grey),
            _buildScaleMarker('40', Colors.green),
            _buildScaleMarker('60', Colors.orange),
            _buildScaleMarker('80', Colors.deepOrange),
            _buildScaleMarker('120', Colors.red),
          ],
        ),
      ],
    );
  }

  Widget _buildScaleMarker(String label, Color color) {
    return Text(
      label,
      style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildStatistics() {
    final duration = _startTime != null
        ? DateTime.now().difference(_startTime!).inSeconds
        : 0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statistics',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Average',
                    _avgDecibels.toStringAsFixed(1),
                    AppIcons.slider,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Maximum',
                    _maxDecibels.toStringAsFixed(1),
                    AppIcons.arrowUp,
                    Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Minimum',
                    _minDecibels.toStringAsFixed(1),
                    AppIcons.arrowDown,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Duration',
                    '${duration}s',
                    AppIcons.clock,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha:0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color.withValues(alpha:0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildReferenceChart() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reference Levels',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildReferenceItem('0-30 dB', 'Whisper, Library', Colors.green),
            _buildReferenceItem(
              '40-60 dB',
              'Normal Conversation',
              Colors.lightGreen,
            ),
            _buildReferenceItem(
              '70-85 dB',
              'Fire Alarm Test (Typical)',
              Colors.orange,
            ),
            _buildReferenceItem(
              '90-100 dB',
              'Fire Alarm (Close Range)',
              Colors.deepOrange,
            ),
            _buildReferenceItem('110+ dB', 'Hearing Damage Risk', Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildReferenceItem(String range, String description, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  range,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isRecording ? _stopRecording : _startRecording,
            icon: Icon(_isRecording ? AppIcons.close : AppIcons.microphone),
            label: Text(_isRecording ? 'Stop' : 'Start'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isRecording
                  ? Colors.red
                  : Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: _isRecording ? null : _resetMeasurement,
          icon: Icon(AppIcons.refresh),
          label: const Text('Reset'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildRefreshToggle() {
    return Center(
      child: SegmentedButton<bool>(
        segments: const [
          ButtonSegment<bool>(
            value: false,
            label: Text('Slow'),
          ),
          ButtonSegment<bool>(
            value: true,
            label: Text('Fast'),
          ),
        ],
        selected: {_fastMode},
        onSelectionChanged: (Set<bool> selection) {
          setState(() {
            _fastMode = selection.first;
          });
        },
      ),
    );
  }

  void _showInfoDialog() {
    showPremiumDialog(
      context: context,
      child: Builder(
        builder: (context) => AlertDialog(
        title: const Text('About Decibel Meter'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This tool measures sound pressure levels in decibels (dB).',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          AppIcons.warning,
                          color: Colors.orange.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Phone Limitations',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Most phones max out at 90-100 dB\n'
                      '• Automatic Gain Control (AGC) limits readings\n'
                      '• Hardware clipping prevents higher measurements\n'
                      '• Budget phones may cap at 85-90 dB\n'
                      '• High-end phones may reach 100-110 dB',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text('Fire Alarm Standards:'),
              const SizedBox(height: 8),
              const Text('• BS 5839: Minimum 65 dB(A) at bedhead'),
              const Text('• BS 5839: Maximum 120 dB(A) at 1m'),
              const Text('• Typical range: 75-90 dB(A)'),
              const SizedBox(height: 12),
              const Text(
                'For Accurate High-Level Measurements:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Use calibrated Class 1 or Class 2 sound level meters\n'
                '• This app is best for comparative measurements\n'
                '• Good for testing if alarms are working\n'
                '• Not suitable for compliance certification',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              Text(
                'Tip: If you need to verify levels above 90 dB, use this meter to confirm the alarm is working, then use professional equipment for exact measurements.',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      )),
    );
  }
}
