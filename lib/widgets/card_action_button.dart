import 'package:flutter/material.dart';
import '../utils/theme.dart';

class CardActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isDestructive;

  const CardActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDestructive
        ? (isDark ? Colors.red[300]! : Colors.red)
        : (isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue);
    return SizedBox(
      height: 30,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: isDark ? 0.6 : 0.4)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label),
      ),
    );
  }
}
