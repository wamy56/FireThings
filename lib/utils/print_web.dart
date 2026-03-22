// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Triggers the browser's native print dialog.
void printPage() {
  html.window.print();
}
