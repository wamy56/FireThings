import 'package:flutter/material.dart';
import '../utils/adaptive_widgets.dart';
import '../utils/icon_map.dart';

/// Shows an iOS-style "Done" toolbar above the keyboard on Apple platforms,
/// with up/down arrows for field navigation.
///
/// Wrap this around a screen's body (inside the Scaffold) to give users
/// a way to dismiss the keyboard — especially useful for numeric keyboards
/// which lack a return key on iOS.
class KeyboardDoneBar extends StatelessWidget {
  final Widget child;

  const KeyboardDoneBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!PlatformUtils.isApple) return child;

    // Read raw view insets directly from the View, bypassing Scaffold's
    // consumption of viewInsets (which zeroes them out in the body).
    final rawInsets =
        MediaQueryData.fromView(View.of(context)).viewInsets;
    final keyboardVisible = rawInsets.bottom > 0;

    return Stack(
      children: [
        child,
        if (keyboardVisible)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _DoneBarContent(),
          ),
      ],
    );
  }
}

class _DoneBarContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFD1D1D6),
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF3D3D3F) : const Color(0xFFBCBCC0),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          _BarButton(
            icon: AppIcons.arrowUp,
            color: accentColor,
            onTap: () =>
                FocusManager.instance.primaryFocus?.previousFocus(),
          ),
          _BarButton(
            icon: AppIcons.arrowDown,
            color: accentColor,
            onTap: () =>
                FocusManager.instance.primaryFocus?.nextFocus(),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: Text(
                'Done',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _BarButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Icon(icon, size: 22, color: color),
      ),
    );
  }
}
