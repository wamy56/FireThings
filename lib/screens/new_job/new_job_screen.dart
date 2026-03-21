import 'package:flutter/material.dart';
import '../../utils/adaptive_widgets.dart';
import '../../utils/icon_map.dart';
import '../template_builder/custom_template_builder_screen.dart';
import '../../services/template_service.dart';
import '../../services/permission_service.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../utils/pdf_form_templates.dart';
import '../../widgets/premium_toast.dart';
import '../../widgets/adaptive_app_bar.dart';
import '../../widgets/premium_dialog.dart';
import '../../services/analytics_service.dart';
import 'job_form_screen.dart';
import '../pdf_forms/pdf_form_fill_screen.dart';
import '../pdf_forms/minor_works_form_fill_screen.dart';

class NewJobScreen extends StatefulWidget {
  final DispatchedJob? dispatchedJob;

  const NewJobScreen({super.key, this.dispatchedJob});

  @override
  State<NewJobScreen> createState() => _NewJobScreenState();
}

class _NewJobScreenState extends State<NewJobScreen> {
  final _templateService = TemplateService.instance;
  final _permissionService = PermissionService();
  bool _canAccessPdfCertificates = false;
  bool _permissionsLoaded = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final hasAccess = await _permissionService.hasPdfCertificatesAccess();
    if (mounted) {
      setState(() {
        _canAccessPdfCertificates = hasAccess;
        _permissionsLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final templates = _templateService.getPreloadedTemplates();
    final customTemplates = _templateService.getCustomTemplates();

    return Scaffold(
      appBar: AdaptiveNavigationBar(
        title: 'Select Template',
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        children: [
          // PDF Certificates Section (only shown to whitelisted users)
          if (_permissionsLoaded && _canAccessPdfCertificates) ...[
            Text(
              'PDF Certificates',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Fill out professional certificates',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: AppTheme.listItemSpacing),
            _buildIQModificationCard(context),
            const SizedBox(height: AppTheme.listItemSpacing),
            _buildIQMinorWorksCard(context),
            const SizedBox(height: AppTheme.sectionGap),
          ],

          // Header
          Text(
            'Select Job Type',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a template to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          const SizedBox(height: AppTheme.sectionGap),

          // Template cards from template service
          ...templates.map(
            (template) => Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.listItemSpacing),
              child: _buildTemplateCard(
                context,
                template,
                _getTemplateIcon(template.id),
                _getTemplateColor(template.id),
              ),
            ),
          ),

          // Custom Templates Section
          const SizedBox(height: AppTheme.sectionGap),
          Text(
            'Custom Templates',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your saved templates',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          const SizedBox(height: AppTheme.listItemSpacing),

          // Display user-created custom templates
          ...customTemplates.map(
            (template) => Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.listItemSpacing),
              child: _buildCustomTemplateCard(context, template),
            ),
          ),

          // Create new template card
          _buildCreateTemplateCard(context),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(
    BuildContext context,
    JobTemplate template,
    IconData icon,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: isDark ? AppTheme.darkCardShadow : AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _showTemplatePreview(context, template);
          },
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.cardPadding),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 32),
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
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${template.fields.length} fields',
                        style: TextStyle(fontSize: 12, color: AppTheme.textHint),
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

  Widget _buildIQModificationCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: isDark ? AppTheme.darkCardShadow : AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            AnalyticsService.instance.logTemplateSelected('IQ Modification', 'pdf_cert');
            Navigator.push(
              context,
              adaptivePageRoute(
                builder: (_) => PdfFormFillScreen(
                  template: PdfFormTemplates.iqModificationCertificate,
                ),
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
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(AppIcons.document, color: Colors.red, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'IQ Modification Certificate',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Fire alarm modification certificate per BS 5839-1:2025',
                        style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Certificate',
                          style: TextStyle(fontSize: 11, color: Colors.red),
                        ),
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

  Widget _buildIQMinorWorksCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: isDark ? AppTheme.darkCardShadow : AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            AnalyticsService.instance.logTemplateSelected('IQ Minor Works', 'pdf_cert');
            Navigator.push(
              context,
              adaptivePageRoute(
                builder: (_) => MinorWorksFormFillScreen(
                  template: PdfFormTemplates.iqMinorWorksCertificate,
                ),
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
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(AppIcons.designtools, color: Colors.orange, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'IQ Minor Works & Call Out Certificate',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Minor works and call out visit certificate',
                        style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Certificate',
                          style: TextStyle(fontSize: 11, color: Colors.orange),
                        ),
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

  Widget _buildCustomTemplateCard(BuildContext context, JobTemplate template) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: isDark ? AppTheme.darkCardShadow : AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            AnalyticsService.instance.logTemplateSelected(template.name, 'custom');
            Navigator.push(
              context,
              adaptivePageRoute(
                builder: (_) => JobFormScreen(
                  template: template,
                  dispatchedJob: widget.dispatchedJob,
                ),
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
                            builder: (_) => JobFormScreen(
                              template: template,
                              dispatchedJob: widget.dispatchedJob,
                            ),
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

  Widget _buildCreateTemplateCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: isDark ? AppTheme.darkCardShadow : AppTheme.cardShadow,
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
                    color: isDark ? AppTheme.darkSurfaceElevated : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? AppTheme.darkDivider : AppTheme.dividerColor, width: 2),
                  ),
                  child: Icon(AppIcons.add, color: isDark ? AppTheme.darkTextSecondary : AppTheme.darkGrey, size: 32),
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

  void _showTemplatePreview(BuildContext context, JobTemplate template) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkDivider : AppTheme.lightGrey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    template.description,
                    style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildInfoChip(
                        '${template.fields.length} fields',
                        AppIcons.element,
                      ),
                      const SizedBox(width: 8),
                      _buildInfoChip(
                        '${template.fields.where((f) => f.required).length} required',
                        AppIcons.award,
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                ],
              ),
            ),

            // Fields list
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: template.fields.length,
                itemBuilder: (context, index) {
                  final field = template.fields[index];
                  return _buildFieldPreview(field);
                },
              ),
            ),

            // Start button
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    AnalyticsService.instance.logTemplateSelected(template.name, 'built_in');
                    Navigator.pop(context); // Close the bottom sheet

                    // Navigate to job form
                    Navigator.push(
                      context,
                      adaptivePageRoute(
                        builder: (context) => JobFormScreen(
                          template: template,
                          dispatchedJob: widget.dispatchedJob,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Start Job',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceElevated : AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isDark ? AppTheme.darkTextSecondary : AppTheme.darkGrey),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.darkGrey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldPreview(TemplateField field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _getFieldTypeIcon(field.type),
            size: 20,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      field.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (field.required) ...[
                      const SizedBox(width: 4),
                      const Text(
                        '*',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _getFieldTypeLabel(field.type),
                  style: TextStyle(fontSize: 12, color: AppTheme.textHint),
                ),
                if (field.options != null && field.options!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Options: ${field.options!.take(3).join(", ")}${field.options!.length > 3 ? "..." : ""}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textHint,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTemplateIcon(String templateId) {
    switch (templateId) {
      case 'battery_replacement':
        return AppIcons.batteryCharging;
      case 'detector_replacement':
        return AppIcons.scanner;
      case 'annual_inspection':
        return AppIcons.clipboardTick;
      case 'quarterly_test':
        return AppIcons.clock;
      case 'panel_commissioning':
        return AppIcons.settingOutline;
      case 'fault_finding':
        return AppIcons.designtools;
      default:
        return AppIcons.briefcaseOutline;
    }
  }

  Color _getTemplateColor(String templateId) {
    return AppTheme.getTemplateColor(templateId);
  }

  IconData _getFieldTypeIcon(FieldType type) {
    switch (type) {
      case FieldType.text:
        return AppIcons.noteText;
      case FieldType.number:
        return AppIcons.tag;
      case FieldType.dropdown:
        return AppIcons.arrowDown;
      case FieldType.checkbox:
        return AppIcons.tickCircle;
      case FieldType.date:
        return AppIcons.calendar;
      case FieldType.multiline:
        return AppIcons.note;
    }
  }

  String _getFieldTypeLabel(FieldType type) {
    switch (type) {
      case FieldType.text:
        return 'Text input';
      case FieldType.number:
        return 'Number input';
      case FieldType.dropdown:
        return 'Dropdown selection';
      case FieldType.checkbox:
        return 'Checkbox';
      case FieldType.date:
        return 'Date picker';
      case FieldType.multiline:
        return 'Multi-line text';
    }
  }
}
