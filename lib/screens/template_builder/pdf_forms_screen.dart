import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../models/pdf_form_template.dart';
import '../../services/database_helper.dart';
import '../../services/bundled_templates_service.dart';
import '../../utils/icon_map.dart';
import 'pdf_form_builder_screen.dart';
import '../../widgets/premium_toast.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/premium_dialog.dart';

class PdfFormsScreen extends StatefulWidget {
  const PdfFormsScreen({super.key});

  @override
  State<PdfFormsScreen> createState() => _PdfFormsScreenState();
}

class _PdfFormsScreenState extends State<PdfFormsScreen>
    with SingleTickerProviderStateMixin {
  final _dbHelper = DatabaseHelper.instance;
  late TabController _tabController;

  List<PdfFormTemplate> _bundledTemplates = [];
  List<PdfFormTemplate> _userTemplates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTemplates();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    setState(() => _isLoading = true);

    try {
      // Load bundled templates
      _bundledTemplates = BundledTemplatesService.getBundledTemplates();

      // Load user-uploaded templates
      _userTemplates = await _dbHelper.getAllPdfFormTemplates();

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        context.showErrorToast('Error loading templates: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Form Templates'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pre-built'),
            Tab(text: 'My Templates'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: AdaptiveLoadingIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTemplateList(_bundledTemplates, isBundled: true),
                _buildTemplateList(_userTemplates, isBundled: false),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadTemplate,
        tooltip: 'Upload Template',
        child: Icon(AppIcons.add),
      ),
    );
  }

  Widget _buildTemplateList(List<PdfFormTemplate> templates, {required bool isBundled}) {
    if (templates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isBundled ? AppIcons.document : AppIcons.document,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              isBundled ? 'No pre-built templates available' : 'No custom templates yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            if (!isBundled) ...[
              const SizedBox(height: 8),
              Text(
                'Tap + to upload a PDF template',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: templates.length,
      itemBuilder: (context, index) {
        final template = templates[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getCategoryColor(template.category).withValues(alpha: 0.2),
              child: Icon(
                _getCategoryIcon(template.category),
                color: _getCategoryColor(template.category),
              ),
            ),
            title: Text(
              template.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(template.description),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getCategoryColor(template.category).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        template.category,
                        style: TextStyle(
                          fontSize: 12,
                          color: _getCategoryColor(template.category),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${template.fields.length} fields',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${template.pageCount} page${template.pageCount > 1 ? 's' : ''}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
            isThreeLine: true,
            trailing: IconButton(
              icon: Icon(AppIcons.more),
              onPressed: () => showAdaptiveActionSheet(
                context: context,
                options: [
                  ActionSheetOption(
                    label: 'Fill Template',
                    icon: AppIcons.edit,
                    onTap: () => _useTemplate(template),
                  ),
                  if (!isBundled)
                    ActionSheetOption(
                      label: 'Delete',
                      icon: AppIcons.trash,
                      isDestructive: true,
                      onTap: () => _deleteTemplate(template),
                    ),
                ],
              ),
            ),
            onTap: () => _useTemplate(template),
          ),
        );
      },
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'fire alarm':
        return Colors.red;
      case 'emergency lighting':
        return Colors.orange;
      case 'maintenance':
        return Colors.blue;
      case 'installation':
        return Colors.green;
      default:
        return Colors.purple;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'fire alarm':
        return AppIcons.danger;
      case 'emergency lighting':
        return AppIcons.flash;
      case 'maintenance':
        return AppIcons.settingOutline;
      case 'installation':
        return AppIcons.settingOutline;
      default:
        return AppIcons.document;
    }
  }

  void _useTemplate(PdfFormTemplate template) {
    Navigator.push(
      context,
      adaptivePageRoute(
        builder: (_) => PdfFormBuilderScreen(template: template),
      ),
    );
  }

  Future<void> _uploadTemplate() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      final sourcePath = result.files.single.path!;
      final fileName = result.files.single.name;

      // Show dialog to configure the template
      if (mounted) {
        _showConfigureTemplateDialog(sourcePath, fileName);
      }
    }
  }

  void _showConfigureTemplateDialog(String sourcePath, String fileName) {
    final nameController = TextEditingController(
      text: fileName.replaceAll('.pdf', ''),
    );
    final descriptionController = TextEditingController();
    String selectedCategory = 'General';

    showPremiumDialog(
      context: context,
      child: Builder(
        builder: (context) => AlertDialog(
        title: const Text('Configure Template'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Template Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              StatefulBuilder(
                builder: (context, setStateDialog) => DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'General', child: Text('General')),
                    DropdownMenuItem(value: 'Fire Alarm', child: Text('Fire Alarm')),
                    DropdownMenuItem(value: 'Emergency Lighting', child: Text('Emergency Lighting')),
                    DropdownMenuItem(value: 'Maintenance', child: Text('Maintenance')),
                    DropdownMenuItem(value: 'Installation', child: Text('Installation')),
                  ],
                  onChanged: (v) {
                    setStateDialog(() {
                      selectedCategory = v ?? 'General';
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(AppIcons.infoCircle, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'After uploading, you can define form fields for this template.',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _saveUploadedTemplate(
                sourcePath: sourcePath,
                name: nameController.text,
                description: descriptionController.text,
                category: selectedCategory,
              );
            },
            child: const Text('Save'),
          ),
        ],
      )),
    );
  }

  Future<void> _saveUploadedTemplate({
    required String sourcePath,
    required String name,
    required String description,
    required String category,
  }) async {
    try {
      // Copy PDF to app's documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final templatesDir = Directory('${appDir.path}/pdf_templates');
      if (!await templatesDir.exists()) {
        await templatesDir.create(recursive: true);
      }

      final newFileName = '${const Uuid().v4()}.pdf';
      final newPath = path.join(templatesDir.path, newFileName);
      await File(sourcePath).copy(newPath);

      // Create template with empty fields (user will define later)
      final template = PdfFormTemplate(
        id: const Uuid().v4(),
        name: name,
        description: description,
        category: category,
        pdfPath: newPath,
        isBundled: false,
        fields: [], // Fields to be defined separately
        pageCount: 1,
        createdAt: DateTime.now(),
      );

      await _dbHelper.insertPdfFormTemplate(template);
      await _loadTemplates();

      if (mounted) {
        // Switch to My Templates tab
        _tabController.animateTo(1);
        context.showSuccessToast('Template uploaded successfully');
      }
    } catch (e) {
      if (mounted) {
        context.showErrorToast('Error uploading template: $e');
      }
    }
  }

  void _deleteTemplate(PdfFormTemplate template) async {
    final confirm = await showAdaptiveAlertDialog<bool>(
      context: context,
      title: 'Delete Template',
      message: 'Are you sure you want to delete "${template.name}"?',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      isDestructive: true,
    );

    if (confirm == true) {
      try {
        // Delete the PDF file
        final file = File(template.pdfPath);
        if (await file.exists()) {
          await file.delete();
        }

        await _dbHelper.deletePdfFormTemplate(template.id);
        await _loadTemplates();

        if (mounted) {
          context.showSuccessToast('Template deleted');
        }
      } catch (e) {
        if (mounted) {
          context.showErrorToast('Error deleting: $e');
        }
      }
    }
  }
}
