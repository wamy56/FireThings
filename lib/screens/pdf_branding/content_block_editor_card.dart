import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../models/pdf_content_block.dart';
import '../../models/pdf_header_config.dart' show PdfDocumentType;
import '../../models/pdf_variable.dart';
import '../../utils/theme.dart';
import '../../utils/adaptive_widgets.dart';
import 'variable_insertion_sheet.dart';

/// Reusable card for editing a single [ContentBlock].
///
/// Collapsed: shows drag handle, type icon, resolved preview text, delete button.
/// Expanded: full editing controls (text, font size, bold/italic, alignment, etc.).
class ContentBlockEditorCard extends StatefulWidget {
  final ContentBlock block;
  final PdfDocumentType docType;
  final bool isExpanded;
  final ValueChanged<ContentBlock> onChanged;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const ContentBlockEditorCard({
    super.key,
    required this.block,
    required this.docType,
    required this.isExpanded,
    required this.onChanged,
    required this.onDelete,
    required this.onTap,
  });

  @override
  State<ContentBlockEditorCard> createState() => _ContentBlockEditorCardState();
}

class _ContentBlockEditorCardState extends State<ContentBlockEditorCard> {
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.block.text ?? '');
  }

  @override
  void didUpdateWidget(ContentBlockEditorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.id != widget.block.id) {
      _textController.text = widget.block.text ?? '';
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final block = widget.block;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: isDark ? AppTheme.darkSurface : Colors.white,
      elevation: widget.isExpanded ? 2 : 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Collapsed header row ──
              Row(
                children: [
                  Icon(
                    IconsaxPlusBold.menu,
                    size: 18,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _iconForType(block.type),
                    size: 16,
                    color: AppTheme.primaryBlue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _previewText(block),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  if (block.bold)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text('B', style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryBlue,
                      )),
                    ),
                  if (block.italic)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text('I', style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.italic,
                        color: AppTheme.primaryBlue,
                      )),
                    ),
                  Text(
                    '${block.fontSize.toInt()}pt',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(IconsaxPlusBold.trash, size: 16),
                    color: AppTheme.errorRed,
                    onPressed: widget.onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),

              // ── Expanded controls ──
              if (widget.isExpanded) ...[
                const Divider(height: 20),
                if (block.type == ContentBlockType.text) _buildTextControls(isDark),
                if (block.type == ContentBlockType.divider) _buildDividerControls(isDark),
                if (block.type == ContentBlockType.spacer) _buildSpacerControls(isDark),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextControls(bool isDark) {
    final block = widget.block;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Variable indicator
        if (block.variable != null && block.variable != PdfVariable.custom)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.data_object, size: 12, color: AppTheme.primaryBlue),
                  const SizedBox(width: 4),
                  Text(
                    'Variable: ${block.variable!.label}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Text input with variable insertion
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                decoration: InputDecoration(
                  hintText: block.variable != null
                      ? 'Override: ${block.variable!.token}'
                      : 'Enter text...',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                style: const TextStyle(fontSize: 13),
                onChanged: (value) {
                  widget.onChanged(block.copyWith(text: value));
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.data_object, size: 18),
              color: AppTheme.primaryBlue,
              tooltip: 'Insert variable',
              onPressed: () => _showVariableSheet(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Font size slider
        Row(
          children: [
            Text('Size', style: TextStyle(
              fontSize: 12,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
            )),
            Expanded(
              child: AdaptiveSlider(
                value: block.fontSize,
                min: 6,
                max: 24,
                divisions: 18,
                onChanged: (v) {
                  widget.onChanged(block.copyWith(fontSize: v));
                },
              ),
            ),
            SizedBox(
              width: 32,
              child: Text(
                '${block.fontSize.toInt()}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Style toggles row
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: const Text('B', style: TextStyle(fontWeight: FontWeight.w900)),
              selected: block.bold,
              onSelected: (v) => widget.onChanged(block.copyWith(bold: v)),
              visualDensity: VisualDensity.compact,
            ),
            FilterChip(
              label: const Text('I', style: TextStyle(fontStyle: FontStyle.italic)),
              selected: block.italic,
              onSelected: (v) => widget.onChanged(block.copyWith(italic: v)),
              visualDensity: VisualDensity.compact,
            ),
            FilterChip(
              label: const Text('ABC'),
              selected: block.uppercase,
              onSelected: (v) => widget.onChanged(block.copyWith(uppercase: v)),
              visualDensity: VisualDensity.compact,
            ),
            SegmentedButton<TextAlignment>(
              segments: const [
                ButtonSegment(value: TextAlignment.left, icon: Icon(Icons.format_align_left, size: 16)),
                ButtonSegment(value: TextAlignment.center, icon: Icon(Icons.format_align_center, size: 16)),
                ButtonSegment(value: TextAlignment.right, icon: Icon(Icons.format_align_right, size: 16)),
              ],
              selected: {block.alignment},
              onSelectionChanged: (v) {
                widget.onChanged(block.copyWith(alignment: v.first));
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Spacing after
        Row(
          children: [
            Text('Spacing', style: TextStyle(
              fontSize: 12,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
            )),
            Expanded(
              child: AdaptiveSlider(
                value: block.spacingAfter,
                min: 0,
                max: 12,
                divisions: 12,
                onChanged: (v) {
                  widget.onChanged(block.copyWith(spacingAfter: v));
                },
              ),
            ),
            SizedBox(
              width: 32,
              child: Text(
                '${block.spacingAfter.toInt()}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDividerControls(bool isDark) {
    final block = widget.block;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Thickness', style: TextStyle(
              fontSize: 12,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
            )),
            Expanded(
              child: AdaptiveSlider(
                value: block.dividerThickness ?? 1,
                min: 0.5,
                max: 4,
                divisions: 7,
                onChanged: (v) {
                  widget.onChanged(block.copyWith(dividerThickness: v));
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSpacerControls(bool isDark) {
    final block = widget.block;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Height', style: TextStyle(
              fontSize: 12,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
            )),
            Expanded(
              child: AdaptiveSlider(
                value: block.spacingAfter,
                min: 2,
                max: 24,
                divisions: 22,
                onChanged: (v) {
                  widget.onChanged(block.copyWith(spacingAfter: v));
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showVariableSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VariableInsertionSheet(
        docType: widget.docType,
        onSelected: (variable) {
          widget.onChanged(widget.block.copyWith(variable: variable));
        },
      ),
    );
  }

  String _previewText(ContentBlock block) {
    if (block.type == ContentBlockType.divider) return 'Divider';
    if (block.type == ContentBlockType.spacer) return 'Spacer (${block.spacingAfter.toInt()}pt)';
    if (block.type == ContentBlockType.logo) return 'Logo';
    if (block.variable != null && block.variable != PdfVariable.custom) {
      return block.text?.isNotEmpty == true
          ? block.text!
          : block.variable!.label;
    }
    return block.text ?? 'Empty text';
  }

  IconData _iconForType(ContentBlockType type) => switch (type) {
    ContentBlockType.text => IconsaxPlusBold.text,
    ContentBlockType.logo => IconsaxPlusBold.image,
    ContentBlockType.divider => Icons.horizontal_rule,
    ContentBlockType.spacer => Icons.space_bar,
  };
}
