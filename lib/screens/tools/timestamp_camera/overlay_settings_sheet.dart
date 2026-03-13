import 'package:flutter/material.dart';
import '../../../utils/theme.dart';
import '../../../widgets/custom_text_field.dart';
import '../../../services/timestamp_camera_service.dart';

/// Modal bottom sheet for configuring per-corner overlay assignments.
class OverlaySettingsSheet extends StatefulWidget {
  final OverlaySettings settings;
  final ValueChanged<OverlaySettings> onSettingsChanged;
  final bool gpsAvailable;

  const OverlaySettingsSheet({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
    this.gpsAvailable = true,
  });

  @override
  State<OverlaySettingsSheet> createState() => _OverlaySettingsSheetState();
}

class _OverlaySettingsSheetState extends State<OverlaySettingsSheet> {
  late OverlaySettings _settings;
  late TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
    _noteController = TextEditingController(text: _settings.customNote);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _update(OverlaySettings newSettings) {
    setState(() => _settings = newSettings);
    widget.onSettingsChanged(newSettings);
    TimestampCameraService.instance.saveSettings(newSettings);
  }

  static const _cornerLabels = {
    OverlayCorner.topLeft: 'Top Left',
    OverlayCorner.topRight: 'Top Right',
    OverlayCorner.bottomLeft: 'Bottom Left',
    OverlayCorner.bottomRight: 'Bottom Right',
  };

  static const _dataTypeLabels = {
    null: 'None',
    OverlayDataType.date: 'Date',
    OverlayDataType.time: 'Time',
    OverlayDataType.gpsCoords: 'GPS Coordinates',
    OverlayDataType.gpsAddress: 'GPS Address',
    OverlayDataType.customNote: 'Custom Note',
  };

  OverlayDataType? _getCornerValue(OverlayCorner corner) => _settings[corner];

  void _setCornerValue(OverlayCorner corner, OverlayDataType? value) {
    switch (corner) {
      case OverlayCorner.topLeft:
        _update(_settings.copyWith(topLeft: () => value));
        break;
      case OverlayCorner.topRight:
        _update(_settings.copyWith(topRight: () => value));
        break;
      case OverlayCorner.bottomLeft:
        _update(_settings.copyWith(bottomLeft: () => value));
        break;
      case OverlayCorner.bottomRight:
        _update(_settings.copyWith(bottomRight: () => value));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Overlay Settings',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 20),

              // Corner assignment dropdowns
              for (final corner in OverlayCorner.values) ...[
                _buildCornerDropdown(corner, isDark),
                const SizedBox(height: 12),
              ],

              // Custom note text field (shown when any corner uses customNote)
              if (_settings.hasCustomNote) ...[
                const SizedBox(height: 4),
                CustomTextField(
                  controller: _noteController,
                  label: 'Note text',
                  hint: 'e.g. Site inspection - Panel A',
                  maxLines: 2,
                  onChanged: (value) {
                    _update(_settings.copyWith(customNote: value));
                  },
                ),
              ],

              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),

              // Resolution selector
              Text(
                'Resolution',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'low', label: Text('480p')),
                  ButtonSegment(value: 'medium', label: Text('720p')),
                  ButtonSegment(value: 'high', label: Text('1080p')),
                ],
                selected: {_settings.resolution},
                onSelectionChanged: (set) {
                  _update(_settings.copyWith(resolution: set.first));
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCornerDropdown(OverlayCorner corner, bool isDark) {
    final currentValue = _getCornerValue(corner);

    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            _cornerLabels[corner]!,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
              ),
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<OverlayDataType?>(
                value: currentValue,
                isExpanded: true,
                dropdownColor: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
                items: _dataTypeLabels.entries.map((entry) {
                  final isGps = entry.key == OverlayDataType.gpsCoords ||
                      entry.key == OverlayDataType.gpsAddress;
                  final enabled = !isGps || widget.gpsAvailable;

                  return DropdownMenuItem<OverlayDataType?>(
                    value: entry.key,
                    enabled: enabled,
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: 14,
                        color: enabled ? null : Colors.grey,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  // DropdownButton passes the selected value (null means "None")
                  _setCornerValue(corner, value);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
