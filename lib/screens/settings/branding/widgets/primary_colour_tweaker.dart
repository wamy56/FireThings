import 'package:flutter/material.dart';

import '../../../../utils/theme.dart';

class PrimaryColourTweaker extends StatelessWidget {
  final Color currentColor;
  final ValueChanged<Color> onChanged;

  const PrimaryColourTweaker({
    super.key,
    required this.currentColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hsv = HSVColor.fromColor(currentColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Tweak primary colour',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite,
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            boxShadow: isDark ? null : AppTheme.cardShadow,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: currentColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _colorToHex(currentColor),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _HueSlider(
                hue: hsv.hue,
                onChanged: (hue) {
                  final newHsv = hsv.withHue(hue);
                  onChanged(newHsv.toColor());
                },
              ),
              const SizedBox(height: 12),
              _BrightnessSlider(
                value: hsv.value,
                hsv: hsv,
                onChanged: (val) {
                  final newHsv = hsv.withValue(val);
                  onChanged(newHsv.toColor());
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _colorToHex(Color c) {
    return '#${(c.r * 255).round().toRadixString(16).padLeft(2, '0')}'
        '${(c.g * 255).round().toRadixString(16).padLeft(2, '0')}'
        '${(c.b * 255).round().toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }
}

class _HueSlider extends StatelessWidget {
  final double hue;
  final ValueChanged<double> onChanged;

  const _HueSlider({required this.hue, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hue',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textSecondary,
              ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 28,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFF0000),
                Color(0xFFFFFF00),
                Color(0xFF00FF00),
                Color(0xFF00FFFF),
                Color(0xFF0000FF),
                Color(0xFFFF00FF),
                Color(0xFFFF0000),
              ],
            ),
          ),
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 28,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              thumbColor: Colors.white,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
              overlayColor: Colors.white.withValues(alpha: 0.15),
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
            ),
            child: Slider(
              value: hue,
              min: 0,
              max: 360,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _BrightnessSlider extends StatelessWidget {
  final double value;
  final HSVColor hsv;
  final ValueChanged<double> onChanged;

  const _BrightnessSlider({
    required this.value,
    required this.hsv,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Brightness',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textSecondary,
              ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 28,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: [
                Colors.black,
                hsv.withValue(1.0).toColor(),
              ],
            ),
          ),
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 28,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              thumbColor: Colors.white,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
              overlayColor: Colors.white.withValues(alpha: 0.15),
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
            ),
            child: Slider(
              value: value,
              min: 0.05,
              max: 1.0,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
