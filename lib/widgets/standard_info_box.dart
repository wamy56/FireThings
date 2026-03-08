import 'package:flutter/material.dart';
import '../utils/icon_map.dart';
import '../utils/standards_metadata.dart';

/// Standardised warning + standards reference box for safety-critical tool info dialogs.
class StandardInfoBox extends StatelessWidget {
  final String toolKey;

  const StandardInfoBox({super.key, required this.toolKey});

  @override
  Widget build(BuildContext context) {
    final info = StandardsMetadata.tools[toolKey];
    if (info == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Orange warning box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.orange.shade900.withValues(alpha: 0.3)
                : Colors.orange.shade50,
            border: Border.all(
              color: isDark
                  ? Colors.orange.shade700
                  : Colors.orange.shade300,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                AppIcons.warning,
                color: isDark
                    ? Colors.orange.shade300
                    : Colors.orange.shade700,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This tool provides guidance only. Always refer to '
                  '${info.standardRef} for definitive requirements.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? Colors.orange.shade200
                        : Colors.orange.shade900,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Blue standards reference box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.blue.shade900.withValues(alpha: 0.3)
                : Colors.blue.shade50,
            border: Border.all(
              color: isDark
                  ? Colors.blue.shade700
                  : Colors.blue.shade300,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                AppIcons.book,
                color: isDark
                    ? Colors.blue.shade300
                    : Colors.blue.shade700,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Based on: ${info.standardRef}\n'
                  'Data last reviewed: ${info.lastReviewed}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? Colors.blue.shade200
                        : Colors.blue.shade900,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
