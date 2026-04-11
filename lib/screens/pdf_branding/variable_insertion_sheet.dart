import 'package:flutter/material.dart';
import '../../models/pdf_header_config.dart' show PdfDocumentType;
import '../../models/pdf_variable.dart';
import '../../utils/theme.dart';

/// Bottom sheet for inserting dynamic variables into text fields.
///
/// Shows available variables as tappable chips, filtered by document type.
class VariableInsertionSheet extends StatelessWidget {
  final PdfDocumentType docType;
  final ValueChanged<PdfVariable> onSelected;

  const VariableInsertionSheet({
    super.key,
    required this.docType,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final variables = <PdfVariable>[
      ...PdfVariable.common,
      if (docType == PdfDocumentType.invoice) ...PdfVariable.invoiceOnly,
      if (docType == PdfDocumentType.jobsheet) ...PdfVariable.jobsheetOnly,
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Insert Variable',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Variables auto-populate with real data when generating PDFs',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: variables.map((v) => _VariableChip(
              variable: v,
              onTap: () {
                onSelected(v);
                Navigator.pop(context);
              },
            )).toList(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _VariableChip extends StatelessWidget {
  final PdfVariable variable;
  final VoidCallback onTap;

  const _VariableChip({required this.variable, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark
          ? AppTheme.primaryBlue.withValues(alpha: 0.15)
          : AppTheme.primaryBlue.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.data_object,
                size: 14,
                color: AppTheme.primaryBlue,
              ),
              const SizedBox(width: 6),
              Text(
                variable.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
