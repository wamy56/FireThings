import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../theme/web_theme.dart';

Color hexToColor(String hex) {
  final clean = hex.replaceFirst('#', '');
  if (clean.length != 6) return FtColors.primary;
  final value = int.tryParse(clean, radix: 16);
  if (value == null) return FtColors.primary;
  return Color(0xFF000000 + value);
}

String colorToHex(Color c) {
  return '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

class BrandingColourPicker extends StatefulWidget {
  final String label;
  final String hexValue;
  final List<Color> presets;
  final ValueChanged<String> onChanged;

  const BrandingColourPicker({
    super.key,
    required this.label,
    required this.hexValue,
    required this.presets,
    required this.onChanged,
  });

  @override
  State<BrandingColourPicker> createState() => _BrandingColourPickerState();
}

class _BrandingColourPickerState extends State<BrandingColourPicker> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.hexValue.toUpperCase());
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(BrandingColourPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hexValue != widget.hexValue && !_focusNode.hasFocus) {
      _controller.text = widget.hexValue.toUpperCase();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _trySubmit();
    }
  }

  void _trySubmit() {
    final text = _controller.text.trim();
    final hex = text.startsWith('#') ? text : '#$text';
    final clean = hex.replaceFirst('#', '');
    if (clean.length == 6 && int.tryParse(clean, radix: 16) != null) {
      widget.onChanged(hex.toUpperCase());
    } else {
      _controller.text = widget.hexValue.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colour = hexToColor(widget.hexValue);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: FtText.inter(size: 12, weight: FontWeight.w600, color: FtColors.fg2),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colour,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: FtColors.border, width: 1.5),
                boxShadow: const [
                  BoxShadow(color: Colors.white, spreadRadius: 2, blurRadius: 0),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 36,
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  style: FtText.mono(size: 13, color: FtColors.fg1),
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[#0-9a-fA-F]')),
                    LengthLimitingTextInputFormatter(7),
                  ],
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: FtColors.border, width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: FtColors.border, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: FtColors.primary, width: 1.5),
                    ),
                  ),
                  onSubmitted: (_) => _trySubmit(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: widget.presets.map((c) {
            final presetHex = colorToHex(c);
            final selected = presetHex == widget.hexValue.toUpperCase();
            return GestureDetector(
              onTap: () => widget.onChanged(presetHex),
              child: AnimatedContainer(
                duration: FtMotion.fast,
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: selected ? FtColors.fg1 : Colors.transparent,
                    width: 1.5,
                  ),
                  boxShadow: selected
                      ? const [BoxShadow(color: Colors.white, spreadRadius: 2, blurRadius: 0)]
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
