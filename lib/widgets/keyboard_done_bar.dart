import 'package:flutter/material.dart';
import '../utils/adaptive_widgets.dart';
import '../utils/icon_map.dart';

/// Shows an iOS-style "Done" toolbar above the keyboard on Apple platforms,
/// with up/down arrows for field navigation.
///
/// Wrap this around a screen's body (inside the Scaffold) to give users
/// a way to dismiss the keyboard — especially useful for numeric keyboards
/// which lack a return key on iOS.
class KeyboardDoneBar extends StatefulWidget {
  final Widget child;

  const KeyboardDoneBar({super.key, required this.child});

  @override
  State<KeyboardDoneBar> createState() => _KeyboardDoneBarState();
}

class _KeyboardDoneBarState extends State<KeyboardDoneBar>
    with WidgetsBindingObserver {
  OverlayEntry? _overlayEntry;
  bool _keyboardVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _removeOverlay();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry?.dispose();
    _overlayEntry = null;
  }

  @override
  void didChangeMetrics() {
    final rawInsets =
        MediaQueryData.fromView(View.of(context)).viewInsets;
    final visible = rawInsets.bottom > 0;
    if (visible != _keyboardVisible) {
      _keyboardVisible = visible;
      if (visible) {
        _showOverlay();
      } else {
        _removeOverlay();
      }
    }
    // Update position when keyboard height changes
    _overlayEntry?.markNeedsBuild();
  }

  void _showOverlay() {
    if (!PlatformUtils.isApple) return;
    _removeOverlay();
    _overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        final viewInsets =
            MediaQueryData.fromView(View.of(context)).viewInsets;
        return Positioned(
          left: 0,
          right: 0,
          bottom: viewInsets.bottom,
          child: _DoneBarContent(),
        );
      },
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _DoneBarContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);

    return Material(
      type: MaterialType.transparency,
      child: Container(
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
