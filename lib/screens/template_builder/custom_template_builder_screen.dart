import 'package:flutter/material.dart';
import '../../utils/adaptive_widgets.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../services/template_service.dart';
import '../../widgets/widgets.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../new_job/job_form_screen.dart';

class CustomTemplateBuilderScreen extends StatefulWidget {
  const CustomTemplateBuilderScreen({super.key});

  @override
  State<CustomTemplateBuilderScreen> createState() =>
      _CustomTemplateBuilderScreenState();
}

class _CustomTemplateBuilderScreenState
    extends State<CustomTemplateBuilderScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _templateService = TemplateService.instance;
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  final List<TemplateField> _fields = [];
  bool _isSaving = false;

  late TabController _tabController;
  late PdfSectionLayoutConfig _sectionLayout;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _sectionLayout = PdfSectionLayoutConfig.defaults();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ─── Section display name mapping ───
  String _sectionName(PdfSectionId id) {
    switch (id) {
      case PdfSectionId.jobInfo:
        return 'Job Information';
      case PdfSectionId.siteDetails:
        return 'Site Details';
      case PdfSectionId.workDetails:
        return 'Work Carried Out';
      case PdfSectionId.notes:
        return 'Notes';
      case PdfSectionId.defects:
        return 'Defects';
      case PdfSectionId.compliance:
        return 'Compliance Statement';
      case PdfSectionId.signatures:
        return 'Signatures';
      case PdfSectionId.assetSummary:
        return 'Asset Inspection Summary';
    }
  }

  String? _sectionSubtitle(PdfSectionId id) {
    switch (id) {
      case PdfSectionId.notes:
      case PdfSectionId.defects:
        return 'Only shown when data exists';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdaptiveNavigationBar(
        title: 'Create Custom Template',
        actions: [
          TextButton(onPressed: _saveTemplate, child: const Text('Save')),
        ],
      ),
      body: KeyboardDismissWrapper(child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Template Info — always visible
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(AppIcons.editNote, color: AppTheme.primaryBlue),
                          const SizedBox(width: 8),
                          const Text(
                            'Template Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _nameController,
                        label: 'Template Name *',
                        hint: 'e.g., Custom Inspection',
                        prefixIcon: Icon(AppIcons.noteText),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Template name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _descriptionController,
                        label: 'Description *',
                        hint: 'Brief description of this template',
                        maxLines: 2,
                        prefixIcon: Icon(AppIcons.document),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Description is required';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Tabs
            TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryBlue,
              unselectedLabelColor: AppTheme.mediumGrey,
              indicatorColor: AppTheme.primaryBlue,
              tabs: [
                Tab(icon: Icon(AppIcons.document), text: 'PDF Layout'),
                Tab(icon: Icon(AppIcons.element), text: 'Custom Fields'),
              ],
            ),
            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPdfLayoutTab(),
                  _buildCustomFieldsTab(),
                ],
              ),
            ),
          ],
        ),
      )),
    );
  }

  // ══════════════════════════════════════════════════════
  // PDF LAYOUT TAB
  // ══════════════════════════════════════════════════════

  Widget _buildPdfLayoutTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Mini PDF Preview
        _buildMiniPdfPreview(),
        const SizedBox(height: 16),

        // Side-by-side / Stacked toggle
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Job Info + Site Details Layout',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                SegmentedButton<SectionLayoutMode>(
                  segments: [
                    ButtonSegment(
                      value: SectionLayoutMode.sideBySide,
                      label: Text('Side-by-side'),
                      icon: Icon(AppIcons.element),
                    ),
                    ButtonSegment(
                      value: SectionLayoutMode.stacked,
                      label: Text('Stacked'),
                      icon: Icon(AppIcons.element),
                    ),
                  ],
                  selected: {_sectionLayout.jobSiteLayout},
                  onSelectionChanged: (selected) {
                    setState(() {
                      _sectionLayout = _sectionLayout.copyWith(
                        jobSiteLayout: selected.first,
                      );
                    });
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Section Reorder List
        Row(
          children: [
            Icon(AppIcons.more, color: AppTheme.primaryBlue),
            const SizedBox(width: 8),
            const Text(
              'Section Order',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _sectionLayout.sections.length,
          onReorder: _reorderSections,
          itemBuilder: (context, index) {
            final entry = _sectionLayout.sections[index];
            return _buildSectionOrderCard(entry, index);
          },
        ),
      ],
    );
  }

  Widget _buildMiniPdfPreview() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Header placeholder
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Header',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Colors.black54),
            ),
          ),
          const SizedBox(height: 6),

          // Body sections
          ..._buildPreviewSections(),

          const SizedBox(height: 6),
          // Footer placeholder
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Footer',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPreviewSections() {
    final layout = _sectionLayout;
    final widgets = <Widget>[];

    for (int i = 0; i < layout.sections.length; i++) {
      final entry = layout.sections[i];
      final isHidden = !entry.visible;

      // Side-by-side check
      if (entry.id == PdfSectionId.jobInfo &&
          layout.jobSiteLayout == SectionLayoutMode.sideBySide &&
          i + 1 < layout.sections.length &&
          layout.sections[i + 1].id == PdfSectionId.siteDetails) {
        final nextHidden = !layout.sections[i + 1].visible;
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Expanded(
                child: _previewBlock('Job Information', isHidden),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _previewBlock('Site Details', nextHidden),
              ),
            ],
          ),
        ));
        i++;
        continue;
      }
      if (entry.id == PdfSectionId.siteDetails &&
          layout.jobSiteLayout == SectionLayoutMode.sideBySide &&
          i + 1 < layout.sections.length &&
          layout.sections[i + 1].id == PdfSectionId.jobInfo) {
        final nextHidden = !layout.sections[i + 1].visible;
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Expanded(
                child: _previewBlock('Site Details', isHidden),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _previewBlock('Job Information', nextHidden),
              ),
            ],
          ),
        ));
        i++;
        continue;
      }

      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: _previewBlock(_sectionName(entry.id), isHidden),
      ));
    }

    return widgets;
  }

  Widget _previewBlock(String label, bool isHidden) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      decoration: BoxDecoration(
        color: isHidden
            ? AppTheme.primaryBlue.withValues(alpha: 0.05)
            : AppTheme.primaryBlue.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isHidden
              ? Colors.grey.withValues(alpha: 0.3)
              : AppTheme.primaryBlue.withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: isHidden ? Colors.grey : AppTheme.primaryBlue,
          decoration: isHidden ? TextDecoration.lineThrough : null,
        ),
      ),
    );
  }

  Widget _buildSectionOrderCard(PdfSectionEntry entry, int index) {
    final subtitle = _sectionSubtitle(entry.id);
    return Card(
      key: ValueKey(entry.id),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(AppIcons.more),
        title: Text(
          _sectionName(entry.id),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: entry.visible ? null : Colors.grey,
            decoration: entry.visible ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: subtitle != null
            ? Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[500]))
            : null,
        trailing: IconButton(
          icon: Icon(
            entry.visible ? AppIcons.eye : AppIcons.eyeSlash,
            color: entry.visible ? AppTheme.primaryBlue : Colors.grey,
          ),
          onPressed: () {
            setState(() {
              final sections = List<PdfSectionEntry>.from(_sectionLayout.sections);
              sections[index] = entry.copyWith(visible: !entry.visible);
              _sectionLayout = _sectionLayout.copyWith(sections: sections);
            });
          },
        ),
      ),
    );
  }

  void _reorderSections(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final sections = List<PdfSectionEntry>.from(_sectionLayout.sections);
      final item = sections.removeAt(oldIndex);
      sections.insert(newIndex, item);
      _sectionLayout = _sectionLayout.copyWith(sections: sections);
    });
  }

  // ══════════════════════════════════════════════════════
  // CUSTOM FIELDS TAB
  // ══════════════════════════════════════════════════════

  Widget _buildCustomFieldsTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Info box
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? Colors.blue.shade900.withValues(alpha: 0.3) : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            border: Border.all(
              color: isDark ? Colors.blue.shade700 : Colors.blue.shade200,
            ),
          ),
          child: Row(
            children: [
              Icon(AppIcons.infoCircle, color: Colors.blue.shade600, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Custom fields only affect the \'Work Carried Out\' section of your jobsheet.',
                  style: TextStyle(fontSize: 13.5, color: isDark ? Colors.blue.shade200 : Colors.blue.shade800),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Fields Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(AppIcons.element, color: AppTheme.primaryBlue),
                const SizedBox(width: 8),
                Text(
                  'Fields (${_fields.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _showAddFieldDialog,
              icon: Icon(AppIcons.add),
              label: const Text('Add Field'),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Fields List
        if (_fields.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: EmptyState(
                icon: AppIcons.add,
                title: 'No Fields Yet',
                message: 'Add fields to build your custom template',
                buttonText: 'Add First Field',
                onButtonPressed: _showAddFieldDialog,
              ),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _fields.length,
            onReorder: _reorderFields,
            itemBuilder: (context, index) {
              final field = _fields[index];
              return _buildFieldCard(field, index);
            },
          ),

        const SizedBox(height: 24),

        // Use Template Button
        if (_fields.isNotEmpty)
          CustomButton(
            text: 'Save & Use Template',
            icon: AppIcons.tickCircle,
            onPressed: _saveAndUseTemplate,
            isLoading: _isSaving,
            isFullWidth: true,
          ),
      ],
    );
  }

  Widget _buildFieldCard(TemplateField field, int index) {
    return Card(
      key: ValueKey(field.id),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
          child: Icon(
            _getFieldIcon(field.type),
            color: AppTheme.primaryBlue,
            size: 20,
          ),
        ),
        title: Text(
          field.label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          _getFieldTypeLabel(field.type) +
              (field.required ? ' - Required' : ''),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(AppIcons.edit, size: 20),
              onPressed: () => _editField(index),
            ),
            IconButton(
              icon: Icon(AppIcons.trash, size: 20, color: Colors.red),
              onPressed: () => _deleteField(index),
            ),
            Icon(AppIcons.more),
          ],
        ),
      ),
    );
  }

  // ─── Field CRUD ───

  Future<void> _showAddFieldDialog() async {
    final result = await showPremiumDialog<TemplateField>(
      context: context,
      child: const _AddFieldDialog(),
    );

    if (result != null) {
      setState(() {
        _fields.add(result);
      });
    }
  }

  Future<void> _editField(int index) async {
    final result = await showPremiumDialog<TemplateField>(
      context: context,
      child: _AddFieldDialog(field: _fields[index]),
    );

    if (result != null) {
      setState(() {
        _fields[index] = result;
      });
    }
  }

  void _deleteField(int index) {
    setState(() {
      _fields.removeAt(index);
    });
  }

  void _reorderFields(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final field = _fields.removeAt(oldIndex);
      _fields.insert(newIndex, field);
    });
  }

  // ─── Template Save ───

  /// Check if the layout differs from defaults (to avoid storing defaults unnecessarily).
  bool get _hasCustomLayout {
    final defaults = PdfSectionLayoutConfig.defaults();
    if (_sectionLayout.jobSiteLayout != defaults.jobSiteLayout) return true;
    if (_sectionLayout.sections.length != defaults.sections.length) return true;
    for (int i = 0; i < _sectionLayout.sections.length; i++) {
      if (_sectionLayout.sections[i].id != defaults.sections[i].id) return true;
      if (_sectionLayout.sections[i].visible != defaults.sections[i].visible) {
        return true;
      }
    }
    return false;
  }

  Future<void> _saveTemplate() async {
    if (!_formKey.currentState!.validate()) {
      context.showErrorToast('Please fill in template name and description');
      return;
    }

    if (_fields.isEmpty) {
      context.showErrorToast('Please add at least one field');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final template = JobTemplate(
        id: 'custom_${const Uuid().v4()}',
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        fields: List.from(_fields),
        createdAt: DateTime.now(),
        sectionLayout: _hasCustomLayout ? _sectionLayout : null,
      );

      await _templateService.addCustomTemplate(template);

      if (mounted) {
        context.showSuccessToast('Template saved successfully!');

        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        context.showErrorToast('Error saving template: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveAndUseTemplate() async {
    if (!_formKey.currentState!.validate()) {
      context.showErrorToast('Please fill in template name and description');
      return;
    }

    if (_fields.isEmpty) {
      context.showErrorToast('Please add at least one field');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final template = JobTemplate(
        id: 'custom_${const Uuid().v4()}',
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        fields: List.from(_fields),
        createdAt: DateTime.now(),
        sectionLayout: _hasCustomLayout ? _sectionLayout : null,
      );

      await _templateService.addCustomTemplate(template);

      if (mounted) {
        // Navigate to job form with this template
        Navigator.pushReplacement(
          context,
          adaptivePageRoute(builder: (_) => JobFormScreen(template: template)),
        );
      }
    } catch (e) {
      if (mounted) {
        context.showErrorToast('Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  IconData _getFieldIcon(FieldType type) {
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
        return 'Text';
      case FieldType.number:
        return 'Number';
      case FieldType.dropdown:
        return 'Dropdown';
      case FieldType.checkbox:
        return 'Checkbox';
      case FieldType.date:
        return 'Date';
      case FieldType.multiline:
        return 'Multi-line';
    }
  }
}

// ══════════════════════════════════════════════════════
// Add Field Dialog (unchanged)
// ══════════════════════════════════════════════════════

class _AddFieldDialog extends StatefulWidget {
  final TemplateField? field;

  const _AddFieldDialog({this.field});

  @override
  State<_AddFieldDialog> createState() => _AddFieldDialogState();
}

class _AddFieldDialogState extends State<_AddFieldDialog> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _optionsController = TextEditingController();

  FieldType _selectedType = FieldType.text;
  bool _isRequired = false;

  @override
  void initState() {
    super.initState();
    if (widget.field != null) {
      _labelController.text = widget.field!.label;
      _selectedType = widget.field!.type;
      _isRequired = widget.field!.required;
      if (widget.field!.options != null) {
        _optionsController.text = widget.field!.options!.join('\n');
      }
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _optionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.field == null ? 'Add Field' : 'Edit Field'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Field Label
              TextFormField(
                controller: _labelController,
                decoration: const InputDecoration(
                  labelText: 'Field Label *',
                  hintText: 'e.g., Panel Make/Model',
                ),
                textInputAction: TextInputAction.done,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Label is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Field Type Dropdown
              DropdownButtonFormField<FieldType>(
                initialValue: _selectedType,
                decoration: const InputDecoration(labelText: 'Field Type *'),
                items: FieldType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(_getFieldTypeLabel(type)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedType = value!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Options (for dropdown only)
              if (_selectedType == FieldType.dropdown) ...[
                TextFormField(
                  controller: _optionsController,
                  decoration: const InputDecoration(
                    labelText: 'Options (one per line) *',
                    hintText: 'Option 1\nOption 2\nOption 3',
                  ),
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                    validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please provide at least one option';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Required Checkbox
              CheckboxListTile(
                title: const Text('Required field'),
                value: _isRequired,
                onChanged: (value) {
                  setState(() {
                    _isRequired = value ?? false;
                  });
                },
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _saveField, child: const Text('Save Field')),
      ],
    );
  }

  void _saveField() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    List<String>? options;
    if (_selectedType == FieldType.dropdown) {
      options = _optionsController.text
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (options.isEmpty) {
        context.showErrorToast('Please provide at least one option');
        return;
      }
    }

    final field = TemplateField(
      id: widget.field?.id ?? 'field_${const Uuid().v4()}',
      label: _labelController.text.trim(),
      type: _selectedType,
      required: _isRequired,
      options: options,
    );

    Navigator.pop(context, field);
  }

  String _getFieldTypeLabel(FieldType type) {
    switch (type) {
      case FieldType.text:
        return 'Text Input';
      case FieldType.number:
        return 'Number Input';
      case FieldType.dropdown:
        return 'Dropdown Selection';
      case FieldType.checkbox:
        return 'Checkbox';
      case FieldType.date:
        return 'Date Picker';
      case FieldType.multiline:
        return 'Multi-line Text';
    }
  }
}
