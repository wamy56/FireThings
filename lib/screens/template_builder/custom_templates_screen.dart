import 'package:flutter/material.dart';
import '../../utils/adaptive_widgets.dart';
import '../../models/models.dart';
import '../../services/template_service.dart';
import '../../widgets/widgets.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../new_job/job_form_screen.dart';
import 'custom_template_builder_screen.dart';

class CustomTemplatesScreen extends StatefulWidget {
  const CustomTemplatesScreen({super.key});

  @override
  State<CustomTemplatesScreen> createState() => _CustomTemplatesScreenState();
}

class _CustomTemplatesScreenState extends State<CustomTemplatesScreen> {
  final _templateService = TemplateService.instance;
  List<JobTemplate> _customTemplates = [];

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  void _loadTemplates() {
    setState(() {
      _customTemplates = _templateService.getCustomTemplates();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdaptiveNavigationBar(title: 'Custom Templates'),
      body: _customTemplates.isEmpty
          ? EmptyState(
              icon: AppIcons.folder,
              title: 'No Custom Templates',
              message: 'Create your own custom templates for specific jobs',
              buttonText: 'Create Template',
              onButtonPressed: () async {
                await Navigator.push(
                  context,
                  adaptivePageRoute(
                    builder: (_) => const CustomTemplateBuilderScreen(),
                  ),
                );
                _loadTemplates();
              },
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '${_customTemplates.length} custom template${_customTemplates.length == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                ..._customTemplates.map((template) {
                  return _buildTemplateCard(template);
                }),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            adaptivePageRoute(
              builder: (_) => const CustomTemplateBuilderScreen(),
            ),
          );
          _loadTemplates();
        },
        child: Icon(AppIcons.add),
      ),
    );
  }

  Widget _buildTemplateCard(JobTemplate template) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
          child: Icon(AppIcons.folder, color: AppTheme.primaryBlue),
        ),
        title: Text(
          template.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              template.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${template.fields.length} fields',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
        trailing: IconButton(
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
        onTap: () {
          Navigator.push(
            context,
            adaptivePageRoute(
              builder: (_) => JobFormScreen(template: template),
            ),
          );
        },
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
      _loadTemplates();

      if (!mounted) return;
      context.showWarningToast('Template deleted');
    }
  }
}
