import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/disclaimer_service.dart';
import '../utils/theme.dart';
import '../utils/icon_map.dart';
import '../utils/adaptive_widgets.dart';

/// Static helper that checks disclaimer acceptance before navigating to a safety-critical tool.
class ToolsDisclaimerGate {
  ToolsDisclaimerGate._();

  /// Navigate to [toolScreen] after ensuring the disclaimer has been accepted.
  static Future<void> navigateToTool(
    BuildContext context,
    Widget toolScreen,
  ) async {
    final accepted =
        await DisclaimerService.instance.hasAcceptedCurrentDisclaimer();

    if (!context.mounted) return;

    if (accepted) {
      Navigator.push(
        context,
        adaptivePageRoute(builder: (_) => toolScreen),
      );
      return;
    }

    final result = await _showDisclaimerDialog(context);

    if (result == true && context.mounted) {
      await DisclaimerService.instance.acceptDisclaimer();
      if (!context.mounted) return;
      Navigator.push(
        context,
        adaptivePageRoute(builder: (_) => toolScreen),
      );
    }
  }

  /// Show the disclaimer in read-only mode (no accept/cancel — just a Close button).
  static Future<void> showDisclaimerReadOnly(BuildContext context) {
    HapticFeedback.mediumImpact();

    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: AppTheme.normalAnimation,
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: AppTheme.defaultCurve,
          ),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              constraints: const BoxConstraints(maxWidth: 500),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.orange.shade900.withValues(alpha: 0.3)
                          : Colors.orange.shade50,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          AppIcons.warning,
                          color: isDark
                              ? Colors.orange.shade300
                              : Colors.orange.shade700,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Tools Disclaimer',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.orange.shade200
                                      : Colors.orange.shade900,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Body
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildParagraph(
                            'The safety-critical reference tools in this app '
                            '(BS 5839 Reference, Detector Spacing Calculator, '
                            'Battery Load Test, and Decibel Meter) are provided '
                            'as guidance aids only.',
                          ),
                          const SizedBox(height: 12),
                          _buildBullet(
                            'These tools are not a substitute for reading and '
                            'understanding the full relevant standards '
                            '(e.g. BS 5839-1:2025).',
                          ),
                          _buildBullet(
                            'Data within these tools may not reflect the latest '
                            'amendments or corrections. You must verify all '
                            'information against the current published standard.',
                          ),
                          _buildBullet(
                            'The Decibel Meter uses your phone\'s built-in '
                            'microphone, which has hardware limitations. It is '
                            'not a calibrated instrument and must not be used '
                            'for compliance certification.',
                          ),
                          _buildBullet(
                            'No liability is accepted for any loss, damage, or '
                            'injury arising from reliance on information '
                            'provided by these tools.',
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Close button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Future<bool?> _showDisclaimerDialog(BuildContext context) {
    HapticFeedback.mediumImpact();

    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: AppTheme.normalAnimation,
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: AppTheme.defaultCurve,
          ),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              constraints: const BoxConstraints(maxWidth: 500),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.orange.shade900.withValues(alpha: 0.3)
                          : Colors.orange.shade50,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          AppIcons.warning,
                          color: isDark
                              ? Colors.orange.shade300
                              : Colors.orange.shade700,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Important Disclaimer',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.orange.shade200
                                      : Colors.orange.shade900,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Body
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildParagraph(
                            'The safety-critical reference tools in this app '
                            '(BS 5839 Reference, Detector Spacing Calculator, '
                            'Battery Load Test, and Decibel Meter) are provided '
                            'as guidance aids only.',
                          ),
                          const SizedBox(height: 12),
                          _buildBullet(
                            'These tools are not a substitute for reading and '
                            'understanding the full relevant standards '
                            '(e.g. BS 5839-1:2025).',
                          ),
                          _buildBullet(
                            'Data within these tools may not reflect the latest '
                            'amendments or corrections. You must verify all '
                            'information against the current published standard.',
                          ),
                          _buildBullet(
                            'The Decibel Meter uses your phone\'s built-in '
                            'microphone, which has hardware limitations. It is '
                            'not a calibrated instrument and must not be used '
                            'for compliance certification.',
                          ),
                          _buildBullet(
                            'No liability is accepted for any loss, damage, or '
                            'injury arising from reliance on information '
                            'provided by these tools.',
                          ),
                          const SizedBox(height: 12),
                          _buildParagraph(
                            'By tapping "I Accept" you acknowledge '
                            'that you have read and understood this disclaimer.',
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Actions
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('I Accept'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _buildParagraph(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 14, height: 1.5),
    );
  }

  static Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('\u2022 ', style: TextStyle(fontSize: 14, height: 1.5)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
