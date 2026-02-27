import 'package:flutter/material.dart';
import '../../../utils/adaptive_widgets.dart';
import '../../../utils/icon_map.dart';
import '../../../utils/theme.dart';
import '../../../widgets/custom_text_field.dart';
import '../../../services/timestamp_camera_service.dart';

/// Modal bottom sheet for configuring overlay toggles, custom note, and resolution.
class CameraSettingsPanel extends StatefulWidget {
  final OverlaySettings settings;
  final ValueChanged<OverlaySettings> onSettingsChanged;
  final bool gpsAvailable;

  const CameraSettingsPanel({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
    this.gpsAvailable = true,
  });

  @override
  State<CameraSettingsPanel> createState() => _CameraSettingsPanelState();
}

class _CameraSettingsPanelState extends State<CameraSettingsPanel> {
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.8,
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
              const SizedBox(height: 16),

              // Overlay toggles
              _buildToggle(
                icon: AppIcons.calendar,
                label: 'Date',
                value: _settings.showDate,
                onChanged: (v) => _update(_settings.copyWith(showDate: v)),
              ),
              _buildToggle(
                icon: AppIcons.clock,
                label: 'Time',
                value: _settings.showTime,
                onChanged: (v) => _update(_settings.copyWith(showTime: v)),
              ),
              _buildToggle(
                icon: AppIcons.location,
                label: 'GPS Coordinates',
                value: _settings.showCoords,
                enabled: widget.gpsAvailable,
                onChanged: (v) => _update(_settings.copyWith(showCoords: v)),
              ),
              _buildToggle(
                icon: AppIcons.building,
                label: 'Address',
                value: _settings.showAddress,
                enabled: widget.gpsAvailable,
                onChanged: (v) => _update(_settings.copyWith(showAddress: v)),
              ),
              _buildToggle(
                icon: AppIcons.editNote,
                label: 'Custom Note',
                value: _settings.showNote,
                onChanged: (v) => _update(_settings.copyWith(showNote: v)),
              ),

              // Custom note text field
              if (_settings.showNote) ...[
                const SizedBox(height: 8),
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

              // Resolution dropdown
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

  Widget _buildToggle({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: enabled ? null : Colors.grey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: enabled ? null : Colors.grey,
              ),
            ),
          ),
          AdaptiveSwitch(
            value: value && enabled,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}
