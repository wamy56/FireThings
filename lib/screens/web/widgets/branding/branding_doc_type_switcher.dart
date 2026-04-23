import 'package:flutter/material.dart';

import '../../../../models/pdf_branding.dart';
import '../../../../theme/web_theme.dart';
import '../../../../utils/icon_map.dart';

class BrandingDocTypeSwitcher extends StatelessWidget {
  final BrandingDocType selectedDocType;
  final ValueChanged<BrandingDocType> onDocTypeChanged;

  const BrandingDocTypeSwitcher({
    super.key,
    required this.selectedDocType,
    required this.onDocTypeChanged,
  });

  static const _docTypes = [
    (type: BrandingDocType.report, icon: AppIcons.clipboardTick, label: 'Compliance report'),
    (type: BrandingDocType.quote, icon: AppIcons.document, label: 'Quote'),
    (type: BrandingDocType.invoice, icon: AppIcons.receiptItem, label: 'Invoice'),
    (type: BrandingDocType.jobsheet, icon: AppIcons.edit, label: 'Job sheet'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: FtColors.bg,
        border: Border.all(color: FtColors.border),
        borderRadius: BorderRadius.circular(12),
        boxShadow: FtShadows.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            margin: const EdgeInsets.only(right: 4),
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: FtColors.border)),
            ),
            height: 28,
            alignment: Alignment.center,
            child: Text(
              'PREVIEWING',
              style: FtText.inter(
                size: 11,
                weight: FontWeight.w700,
                color: FtColors.fg2,
                letterSpacing: 0.4,
              ),
            ),
          ),
          ..._docTypes.map((dt) {
            final active = dt.type == selectedDocType;
            return Padding(
              padding: const EdgeInsets.only(left: 2),
              child: _DocPill(
                icon: dt.icon,
                label: dt.label,
                active: active,
                onTap: () => onDocTypeChanged(dt.type),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _DocPill extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _DocPill({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  State<_DocPill> createState() => _DocPillState();
}

class _DocPillState extends State<_DocPill> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: FtMotion.fast,
          curve: FtMotion.standardCurve,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: widget.active
                ? FtColors.primary
                : _hovered
                    ? FtColors.bgAlt
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: widget.active ? FtShadows.navyDepth : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 14,
                color: widget.active
                    ? FtColors.accent
                    : _hovered
                        ? FtColors.fg2
                        : FtColors.hint,
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: FtText.inter(
                  size: 13,
                  weight: FontWeight.w600,
                  color: widget.active
                      ? Colors.white
                      : _hovered
                          ? FtColors.fg1
                          : FtColors.fg2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
