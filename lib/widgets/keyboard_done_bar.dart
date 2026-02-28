import 'package:flutter/material.dart';
import '../utils/adaptive_widgets.dart';

/// Shows an iOS-style "Done" toolbar above the keyboard on Apple platforms.
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

    final viewInsets = MediaQuery.of(context).viewInsets;
    final keyboardVisible = viewInsets.bottom > 0;

    return Stack(
      children: [
        child,
        if (keyboardVisible)
          Positioned(
            left: 0,
            right: 0,
            bottom: viewInsets.bottom,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF2C2C2E)
                    : const Color(0xFFD1D1D6),
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF3D3D3F)
                        : const Color(0xFFBCBCC0),
                    width: 0.5,
                  ),
                ),
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: GestureDetector(
                    onTap: () =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    child: Text(
                      'Done',
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF0A84FF)
                            : const Color(0xFF007AFF),
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
