import 'package:flutter/material.dart';
import '../../utils/adaptive_widgets.dart';
import '../template_builder/custom_template_builder_screen.dart';
import '../../services/template_service.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../widgets/premium_toast.dart';
import '../new_job/job_form_screen.dart';
import '../../widgets/adaptive_app_bar.dart';
import '../../widgets/premium_dialog.dart';

class CustomTemplatesScreen extends StatefulWidget {
  const CustomTemplatesScreen({super.key});

  @override
  State<CustomTemplatesScreen> createState() => _CustomTemplatesScreenState();
}

class _CustomTemplatesScreenState extends State<CustomTemplatesScreen> {
  final _templateService = TemplateService.instance;

  @override
  Widget build(BuildContext context) {
    final customTemplates = _templateService.getCustomTemplates();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AdaptiveNavigationBar(
        title: 'Custom Templates',
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        children: [
          // Display user-created custom templates
          ...customTemplates.map(
            (template) => Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.listItemSpacing),
              child: _buildCustomTemplateCard(context, template, isDark),
            ),
          ),

          // Create new template card
          _buildCreateTemplateCard(context, isDark),
        ],
      ),
    );
  }

  Widget _buildCustomTemplateCard(BuildContext context, JobTemplate template, bool isDark) {
    final cardColor = isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite;
    final shadow = isDark ? AppTheme.darkCardShadow : AppTheme.cardShadow;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: shadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              adaptivePageRoute(
                builder: (_) => JobFormScreen(template: template),
              ),
            );
          },
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.cardPadding),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(AppIcons.folder, color: Colors.indigo, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        template.description,
                        style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${template.fields.length} fields',
                        style: TextStyle(fontSize: 12, color: AppTheme.textHint),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(AppIcons.more),
                  onPressed: () => showAdaptiveActionSheet(
                    context: context,
                    options: [
                      ActionSheetOption(
                        label: 'Use Template',
                        icon: AppIcons.play,
                        onTap: () => Navigator.push(
                          context,
                          adaptivePageRoute(
                            builder: (_) => JobFormScreen(template: template),
                          ),
                        ),
                      ),
                      ActionSheetOption(
                        label: 'Delete',
                        icon: AppIcons.trash,
                        isDestructive: true,
                        onTap: () => _deleteTemplate(template),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteTemplate(JobTemplate template) async {
    final confirm = await showAdaptiveAlertDialog<bool>(
      context: context,
      title: 'Delete Template',
      message: 'Are you sure you want to delete "${template.name}"? This cannot be undone.',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      isDestructive: true,
    );

    if (confirm == true) {
      await _templateService.deleteCustomTemplate(template.id);
      setState(() {});

      if (!mounted) return;
      context.showWarningToast('Template deleted');
    }
  }

  Widget _buildCreateTemplateCard(BuildContext context, bool isDark) {
    final cardColor = isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite;
    final shadow = isDark ? AppTheme.darkCardShadow : AppTheme.cardShadow;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: shadow,
        border: Border.all(
          color: AppTheme.dividerColor,
          width: 1,
          style: BorderStyle.solid,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            await Navigator.push(
              context,
              adaptivePageRoute(
                builder: (_) => const CustomTemplateBuilderScreen(),
              ),
            );
            setState(() {});
          },
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.cardPadding),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.dividerColor, width: 2),
                  ),
                  child: Icon(AppIcons.add, color: AppTheme.darkGrey, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Create New Template',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Build a custom jobsheet template',
                        style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                Icon(AppIcons.arrowRight, color: AppTheme.textHint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
