import 'package:flutter/material.dart';
import 'keyboard_done_bar.dart';

/// Wraps a widget so that tapping outside any text field dismisses the keyboard.
/// Also shows an iOS-style "Done" toolbar on Apple platforms by default.
class KeyboardDismissWrapper extends StatelessWidget {
  final Widget child;
  final bool showDoneBar;

  const KeyboardDismissWrapper({
    super.key,
    required this.child,
    this.showDoneBar = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget result = GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.translucent,
      child: child,
    );

    if (showDoneBar) {
      result = KeyboardDoneBar(child: result);
    }

    return result;
  }
}
