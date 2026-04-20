import 'package:flutter/material.dart';
import '../utils/theme.dart';

class SelectableAvatar extends StatelessWidget {
  final Widget child;
  final bool isSelected;
  final bool isSelectionMode;

  const SelectableAvatar({
    super.key,
    required this.child,
    required this.isSelected,
    required this.isSelectionMode,
  });

  @override
  Widget build(BuildContext context) {
    if (!isSelectionMode) return child;

    return AnimatedSwitcher(
      duration: AppTheme.fastAnimation,
      switchInCurve: AppTheme.defaultCurve,
      child: isSelected
          ? CircleAvatar(
              key: const ValueKey('selected'),
              backgroundColor: AppTheme.primaryBlue,
              child: const Icon(Icons.check, color: Colors.white, size: 20),
            )
          : Stack(
              key: const ValueKey('unselected'),
              children: [
                child,
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
