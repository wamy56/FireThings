import 'package:flutter/material.dart';

import '../../../../theme/web_theme.dart';

class BrandingStyleToggleGroup extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const BrandingStyleToggleGroup({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: FtColors.bgAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final active = i == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: FtMotion.fast,
                curve: FtMotion.standardCurve,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: active ? FtColors.bg : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: active ? FtShadows.sm : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[i],
                  style: FtText.inter(
                    size: 12,
                    weight: FontWeight.w600,
                    color: active ? FtColors.primary : FtColors.fg2,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
