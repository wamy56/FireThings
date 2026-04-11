import 'package:flutter/material.dart';
import '../../data/pdf_branding_presets.dart';
import '../../models/pdf_branding_config.dart';
import '../../models/pdf_layout_template.dart';
import '../../utils/theme.dart';

/// Horizontal scrolling preset selector with mini-thumbnail previews.
///
/// Tapping a preset fires [onSelected] with the preset's [PdfBrandingConfig].
class TemplatePresetSelector extends StatelessWidget {
  final PdfBrandingConfig currentConfig;
  final ValueChanged<PdfBrandingConfig> onSelected;

  const TemplatePresetSelector({
    super.key,
    required this.currentConfig,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: PdfBrandingPresets.all.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final preset = PdfBrandingPresets.all[index];
          final isSelected =
              currentConfig.headerTemplate == preset.config.headerTemplate &&
              currentConfig.footerTemplate == preset.config.footerTemplate;

          return GestureDetector(
            onTap: () => onSelected(preset.config),
            child: AnimatedContainer(
              duration: AppTheme.fastAnimation,
              width: 90,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryBlue
                      : isDark
                          ? AppTheme.darkDivider
                          : AppTheme.lightGrey,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Expanded(
                    child: _PresetThumbnail(
                      config: preset.config,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    preset.name,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? AppTheme.primaryBlue
                          : isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preset.description,
                    style: TextStyle(
                      fontSize: 9,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Mini-thumbnail that shows the header layout structure visually.
class _PresetThumbnail extends StatelessWidget {
  final PdfBrandingConfig config;
  final bool isDark;

  const _PresetThumbnail({required this.config, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final primary = Color(config.colourScheme.primaryColorValue);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          // Header zone representation
          Expanded(
            flex: 3,
            child: _buildHeaderPreview(primary),
          ),
          const SizedBox(height: 3),
          // Body lines mockup
          Expanded(
            flex: 2,
            child: _buildBodyLines(),
          ),
          const SizedBox(height: 3),
          // Footer zone
          Container(
            height: 6,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: primary, width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(top: 2),
                    color: (isDark ? AppTheme.darkTextHint : AppTheme.textHint)
                        .withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderPreview(Color primary) {
    switch (config.headerTemplate) {
      case HeaderLayoutTemplate.logoLeftTextRight:
        return Row(
          children: [
            _logoBox(primary, 16),
            const SizedBox(width: 4),
            Expanded(child: _textLines(3)),
          ],
        );
      case HeaderLayoutTemplate.logoRightTextLeft:
        return Row(
          children: [
            Expanded(child: _textLines(3)),
            const SizedBox(width: 4),
            _logoBox(primary, 16),
          ],
        );
      case HeaderLayoutTemplate.centeredLogoAboveText:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _logoBox(primary, 12),
            const SizedBox(height: 2),
            _centeredTextLine(0.6),
            const SizedBox(height: 1),
            _centeredTextLine(0.4),
          ],
        );
      case HeaderLayoutTemplate.textOnly:
        return _textLines(4);
      case HeaderLayoutTemplate.twoColumn:
        return Row(
          children: [
            Expanded(child: _textLines(2)),
            const SizedBox(width: 4),
            Expanded(child: _textLines(2, alignRight: true)),
          ],
        );
      case HeaderLayoutTemplate.minimal:
        return Center(child: _centeredTextLine(0.5));
    }
  }

  Widget _logoBox(Color primary, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: primary.withValues(alpha: 0.4), width: 0.5),
      ),
    );
  }

  Widget _textLines(int count, {bool alignRight = false}) {
    return Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final widthFraction = i == 0 ? 0.9 : (0.7 - i * 0.1).clamp(0.3, 1.0);
        return Padding(
          padding: EdgeInsets.only(bottom: i < count - 1 ? 2 : 0),
          child: FractionallySizedBox(
            alignment:
                alignRight ? Alignment.centerRight : Alignment.centerLeft,
            widthFactor: widthFraction,
            child: Container(
              height: i == 0 ? 3 : 2,
              decoration: BoxDecoration(
                color: (isDark ? AppTheme.darkTextHint : AppTheme.textHint)
                    .withValues(alpha: i == 0 ? 0.5 : 0.3),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _centeredTextLine(double widthFraction) {
    return FractionallySizedBox(
      widthFactor: widthFraction,
      child: Container(
        height: 3,
        decoration: BoxDecoration(
          color: (isDark ? AppTheme.darkTextHint : AppTheme.textHint)
              .withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }

  Widget _buildBodyLines() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        return Padding(
          padding: EdgeInsets.only(bottom: i < 2 ? 2 : 0),
          child: FractionallySizedBox(
            widthFactor: (1.0 - i * 0.1),
            child: Container(
              height: 1.5,
              decoration: BoxDecoration(
                color: (isDark ? AppTheme.darkTextHint : AppTheme.textHint)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        );
      }),
    );
  }
}
