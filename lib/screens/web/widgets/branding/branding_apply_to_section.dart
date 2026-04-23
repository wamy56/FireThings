import 'package:flutter/material.dart';

import '../../../../models/pdf_branding.dart';
import '../../../../theme/web_theme.dart';
import '../../../../utils/icon_map.dart';

class BrandingApplyToSection extends StatelessWidget {
  final Set<BrandingDocType> appliesTo;
  final ValueChanged<Set<BrandingDocType>> onChanged;

  const BrandingApplyToSection({
    super.key,
    required this.appliesTo,
    required this.onChanged,
  });

  static const _rows = [
    (type: BrandingDocType.report, icon: AppIcons.clipboardTick, name: 'Compliance reports', meta: 'BS 5839, BS 5266, BAFE certs'),
    (type: BrandingDocType.quote, icon: AppIcons.document, name: 'Quotes', meta: 'Sent to customers for approval'),
    (type: BrandingDocType.invoice, icon: AppIcons.receiptItem, name: 'Invoices', meta: 'Issued for completed jobs'),
    (type: BrandingDocType.jobsheet, icon: AppIcons.edit, name: 'Job sheets', meta: 'Completed work record'),
  ];

  void _toggle(BrandingDocType type) {
    final updated = Set<BrandingDocType>.from(appliesTo);
    if (updated.contains(type)) {
      updated.remove(type);
    } else {
      updated.add(type);
    }
    onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < _rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 4),
          _buildRow(_rows[i]),
        ],
      ],
    );
  }

  Widget _buildRow(({BrandingDocType type, IconData icon, String name, String meta}) row) {
    final checked = appliesTo.contains(row.type);
    return GestureDetector(
      onTap: () => _toggle(row.type),
      child: AnimatedContainer(
        duration: FtMotion.fast,
        curve: FtMotion.standardCurve,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: checked ? FtColors.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: checked ? const Color(0x40FFB020) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: FtMotion.fast,
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: checked ? FtColors.accent : FtColors.bg,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: checked ? FtColors.accent : FtColors.borderStrong,
                  width: 1.5,
                ),
              ),
              child: checked
                  ? const Icon(Icons.check, size: 10, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Icon(row.icon, size: 16, color: checked ? FtColors.accentHover : FtColors.fg2),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.name, style: FtText.inter(size: 13, weight: FontWeight.w600, color: FtColors.fg1)),
                  const SizedBox(height: 2),
                  Text(row.meta, style: FtText.inter(size: 11, weight: FontWeight.w500, color: FtColors.fg2)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
