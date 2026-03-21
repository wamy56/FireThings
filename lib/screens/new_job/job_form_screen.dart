import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/icon_map.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/database_helper.dart';
import '../../widgets/widgets.dart';
import '../../utils/adaptive_widgets.dart';
import '../../utils/theme.dart';
import '../saved_sites/site_picker_screen.dart';
import '../../services/analytics_service.dart';
import '../signature/signature_screen.dart';

class JobFormScreen extends StatefulWidget {
  final JobTemplate template;
  final Jobsheet? existingDraft;
  final DispatchedJob? dispatchedJob;

  const JobFormScreen({
    super.key,
    required this.template,
    this.existingDraft,
    this.dispatchedJob,
  });

  @override
  State<JobFormScreen> createState() => _JobFormScreenState();
}

class _JobFormScreenState extends State<JobFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _dbHelper = DatabaseHelper.instance;

  // Standard field controllers
  final _customerNameController = TextEditingController();
  final _siteAddressController = TextEditingController();
  final _jobNumberController = TextEditingController();
  final _systemCategoryController = TextEditingController();
  final _notesController = TextEditingController();
  late final TextEditingController _engineerNameController;

  // Keys and focus nodes for scroll-to-error
  final _customerNameKey = GlobalKey();
  final _customerNameFocus = FocusNode();
  final _siteAddressKey = GlobalKey();
  final _siteAddressFocus = FocusNode();
  final _jobNumberKey = GlobalKey();
  final _jobNumberFocus = FocusNode();
  final Map<String, GlobalKey> _dynamicFieldKeys = {};
  final Map<String, FocusNode> _dynamicFieldFocusNodes = {};

  // Dynamic form data storage
  final Map<String, dynamic> _formData = {};
  final Map<String, TextEditingController> _textControllers = {};

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isEditingDraft = false;
  String? _draftId;

  @override
  void initState() {
    super.initState();
    // Initialize engineer name controller with current user
    final user = _authService.currentUser;
    _engineerNameController = TextEditingController(
      text: user?.displayName ?? user?.email ?? 'Engineer',
    );
    // Initialize controllers and keys for text fields
    for (var field in widget.template.fields) {
      if (field.type == FieldType.text ||
          field.type == FieldType.number ||
          field.type == FieldType.multiline) {
        _textControllers[field.id] = TextEditingController();
      }
      if (field.required) {
        _dynamicFieldKeys[field.id] = GlobalKey();
        _dynamicFieldFocusNodes[field.id] = FocusNode();
      }
      // Initialize with default values
      if (field.defaultValue != null) {
        _formData[field.id] = field.defaultValue;
        if (_textControllers.containsKey(field.id)) {
          _textControllers[field.id]!.text = field.defaultValue!;
        }
      }
    }

    // Load existing draft data if provided
    if (widget.existingDraft != null) {
      _loadDraftData(widget.existingDraft!);
    }

    // Pre-fill from dispatched job if provided
    if (widget.dispatchedJob != null) {
      _prefillFromDispatchedJob(widget.dispatchedJob!);
    }
  }

  void _prefillFromDispatchedJob(DispatchedJob job) {
    _customerNameController.text = job.contactName ?? job.siteName;
    _siteAddressController.text = job.siteAddress;
    if (job.jobNumber != null) {
      _jobNumberController.text = job.jobNumber!;
    }
    if (job.systemCategory != null) {
      _systemCategoryController.text = job.systemCategory!;
    }
    if (job.scheduledDate != null) {
      _selectedDate = job.scheduledDate!;
    }
  }

  void _loadDraftData(Jobsheet draft) {
    _isEditingDraft = true;
    _draftId = draft.id;

    // Load standard fields
    _customerNameController.text = draft.customerName;
    _siteAddressController.text = draft.siteAddress;
    _jobNumberController.text = draft.jobNumber;
    _systemCategoryController.text = draft.systemCategory;
    _notesController.text = draft.notes;

    // Load dynamic form data
    _formData.addAll(draft.formData);

    // Populate text controllers from form data
    for (var field in widget.template.fields) {
      if (_textControllers.containsKey(field.id) && draft.formData.containsKey(field.id)) {
        _textControllers[field.id]!.text = draft.formData[field.id]?.toString() ?? '';
      }
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _siteAddressController.dispose();
    _jobNumberController.dispose();
    _systemCategoryController.dispose();
    _notesController.dispose();
    _engineerNameController.dispose();
    _customerNameFocus.dispose();
    _siteAddressFocus.dispose();
    _jobNumberFocus.dispose();

    // Dispose dynamic controllers and focus nodes
    for (var controller in _textControllers.values) {
      controller.dispose();
    }
    for (var focusNode in _dynamicFieldFocusNodes.values) {
      focusNode.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdaptiveNavigationBar(
        title: widget.template.name,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: AnimatedSaveButton(
              label: 'Save Draft',
              onPressed: _saveAsDraft,
              outlined: true,
            ),
          ),
        ],
      ),
      body: KeyboardDismissWrapper(
        child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Job Information Section
              _buildSectionHeader('Job Information', AppIcons.infoCircle),
              const SizedBox(height: 16),
              _buildStandardFields(),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),

              // Work Details Section (Dynamic Fields)
              _buildSectionHeader('Work Details', AppIcons.designtools),
              const SizedBox(height: 16),
              _buildDynamicFields(),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),

              // Additional Notes Section
              _buildSectionHeader('Additional Notes', AppIcons.note),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _notesController,
                label: 'Notes',
                hint: 'Add any additional notes or observations',
                maxLines: 4,
              ),

              const SizedBox(height: 32),

              // Continue Button
              CustomButton(
                text: 'Continue to Signatures',
                icon: AppIcons.edit,
                onPressed: _validateAndContinue,
                isLoading: _isLoading,
                isFullWidth: true,
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryBlue, size: 24),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
      ],
    );
  }

  Widget _buildStandardFields() {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Column(
      children: [
        // Date (editable via date picker)
        InkWell(
          onTap: () async {
            final DateTime? picked = await showAdaptiveDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (picked != null) {
              setState(() => _selectedDate = picked);
            }
          },
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Date',
              prefixIcon: Icon(AppIcons.calendar),
            ),
            child: Text(dateFormat.format(_selectedDate)),
          ),
        ),
        const SizedBox(height: 16),

        // Engineer (editable)
        CustomTextField(
          controller: _engineerNameController,
          label: 'Engineer',
          prefixIcon: Icon(AppIcons.user),
        ),
        const SizedBox(height: 16),

        // Customer Name
        CustomTextField(
          key: _customerNameKey,
          controller: _customerNameController,
          focusNode: _customerNameFocus,
          label: 'Customer Name *',
          hint: 'Enter customer name',
          prefixIcon: Icon(AppIcons.building),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Customer name is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Site Address with picker
        CustomTextField(
          key: _siteAddressKey,
          controller: _siteAddressController,
          focusNode: _siteAddressFocus,
          label: 'Site Address *',
          hint: 'Enter site address',
          maxLines: 2,
          prefixIcon: Icon(AppIcons.location),
          suffixIcon: IconButton(
            icon: Icon(AppIcons.element),
            tooltip: 'Select from saved sites',
            onPressed: _selectFromSavedSites,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Site address is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Job Number
        CustomTextField(
          key: _jobNumberKey,
          controller: _jobNumberController,
          focusNode: _jobNumberFocus,
          label: 'Job Number *',
          hint: 'Enter job number',
          prefixIcon: Icon(AppIcons.tag),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Job number is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // System Category
        CustomTextField(
          controller: _systemCategoryController,
          label: 'System Category',
          hint: 'e.g., L1, L2, L3',
          prefixIcon: Icon(AppIcons.category),
        ),
      ],
    );
  }

  Widget _buildDynamicFields() {
    return Column(
      children: widget.template.fields.map((field) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildFieldWidget(field),
        );
      }).toList(),
    );
  }

  Widget _buildFieldWidget(TemplateField field) {
    switch (field.type) {
      case FieldType.text:
        return _buildTextField(field);

      case FieldType.number:
        return _buildNumberField(field);

      case FieldType.dropdown:
        return _buildDropdownField(field);

      case FieldType.checkbox:
        return _buildCheckboxField(field);

      case FieldType.date:
        return _buildDateField(field);

      case FieldType.multiline:
        return _buildMultilineField(field);
    }
  }

  Widget _buildTextField(TemplateField field) {
    return CustomTextField(
      key: _dynamicFieldKeys[field.id],
      controller: _textControllers[field.id],
      focusNode: _dynamicFieldFocusNodes[field.id],
      label: field.label + (field.required ? ' *' : ''),
      prefixIcon: Icon(_getFieldIcon(field)),
      onChanged: (value) => _formData[field.id] = value,
      validator: field.required
          ? (value) {
              if (value == null || value.isEmpty) {
                return '${field.label} is required';
              }
              return null;
            }
          : null,
    );
  }

  Widget _buildNumberField(TemplateField field) {
    return CustomTextField(
      key: _dynamicFieldKeys[field.id],
      controller: _textControllers[field.id],
      focusNode: _dynamicFieldFocusNodes[field.id],
      label: field.label + (field.required ? ' *' : ''),
      keyboardType: TextInputType.number,
      onChanged: (value) => _formData[field.id] = value,
      validator: field.required
          ? (value) {
              if (value == null || value.isEmpty) {
                return '${field.label} is required';
              }
              return null;
            }
          : null,
    );
  }

  Widget _buildDropdownField(TemplateField field) {
    return DropdownButtonFormField<String>(
      initialValue: _formData[field.id] as String?,
      decoration: InputDecoration(
        labelText: field.label + (field.required ? ' *' : ''),
        prefixIcon: Icon(AppIcons.arrowDown),
      ),
      items: field.options!.map((option) {
        return DropdownMenuItem(value: option, child: Text(option));
      }).toList(),
      onChanged: (value) {
        setState(() {
          _formData[field.id] = value;
        });
      },
      validator: field.required
          ? (value) {
              if (value == null || value.isEmpty) {
                return '${field.label} is required';
              }
              return null;
            }
          : null,
    );
  }

  Widget _buildCheckboxField(TemplateField field) {
    return CheckboxListTile(
      title: Text(field.label),
      value: _formData[field.id] as bool? ?? false,
      onChanged: (value) {
        setState(() {
          _formData[field.id] = value ?? false;
        });
      },
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildDateField(TemplateField field) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    String displayValue = '';

    if (_formData[field.id] != null) {
      if (_formData[field.id] is DateTime) {
        displayValue = dateFormat.format(_formData[field.id] as DateTime);
      } else if (_formData[field.id] is String) {
        try {
          final date = DateTime.parse(_formData[field.id] as String);
          displayValue = dateFormat.format(date);
        } catch (e) {
          displayValue = _formData[field.id] as String;
        }
      }
    }

    return FormField<String>(
      initialValue: displayValue,
      validator: field.required
          ? (value) {
              if (_formData[field.id] == null) {
                return '${field.label} is required';
              }
              return null;
            }
          : null,
      builder: (FormFieldState<String> state) {
        return InkWell(
          onTap: () => _selectDate(field),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: field.label + (field.required ? ' *' : ''),
              prefixIcon: Icon(AppIcons.calendar),
              errorText: state.errorText,
            ),
            child: Text(
              displayValue.isNotEmpty ? displayValue : 'Select date',
              style: TextStyle(
                color: displayValue.isNotEmpty
                    ? Theme.of(context).textTheme.bodyLarge?.color
                    : Theme.of(context).hintColor,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMultilineField(TemplateField field) {
    return CustomTextField(
      key: _dynamicFieldKeys[field.id],
      controller: _textControllers[field.id],
      focusNode: _dynamicFieldFocusNodes[field.id],
      label: field.label + (field.required ? ' *' : ''),
      maxLines: 3,
      onChanged: (value) => _formData[field.id] = value,
      validator: field.required
          ? (value) {
              if (value == null || value.isEmpty) {
                return '${field.label} is required';
              }
              return null;
            }
          : null,
    );
  }

  Future<void> _selectFromSavedSites() async {
    final SavedSite? selected = await Navigator.push(
      context,
      adaptivePageRoute(builder: (_) => const SitePickerScreen()),
    );

    if (selected != null) {
      AnalyticsService.instance.logSiteSelected();
      setState(() {
        _siteAddressController.text = selected.address;
      });
    }
  }

  Future<void> _selectDate(TemplateField field) async {
    final DateTime? picked = await showAdaptiveDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        _formData[field.id] = picked.toIso8601String();
      });
    }
  }

  Future<void> _saveAsDraft() async {
    final user = _authService.currentUser;
    if (user == null) {
      context.showErrorToast('User not logged in');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Collect current form data from text controllers
      for (var field in widget.template.fields) {
        if (_textControllers.containsKey(field.id)) {
          _formData[field.id] = _textControllers[field.id]!.text;
        }
      }

      // Build field labels map for PDF generation
      final fieldLabels = <String, String>{};
      for (var field in widget.template.fields) {
        fieldLabels[field.id] = field.label;
      }

      final jobsheet = Jobsheet(
        id: _isEditingDraft ? _draftId! : const Uuid().v4(),
        engineerId: user.uid,
        engineerName: _engineerNameController.text.trim(),
        date: _selectedDate,
        customerName: _customerNameController.text.trim(),
        siteAddress: _siteAddressController.text.trim(),
        jobNumber: _jobNumberController.text.trim(),
        systemCategory: _systemCategoryController.text.trim(),
        templateType: widget.template.name,
        formData: Map.from(_formData),
        fieldLabels: fieldLabels,
        notes: _notesController.text.trim(),
        defects: [],
        createdAt: _isEditingDraft ? widget.existingDraft!.createdAt : DateTime.now(),
        status: JobsheetStatus.draft,
        sectionLayout: widget.template.sectionLayout,
        dispatchedJobId: widget.dispatchedJob?.id,
      );

      if (_isEditingDraft) {
        await _dbHelper.updateJobsheet(jobsheet);
      } else {
        await _dbHelper.insertJobsheet(jobsheet);
      }
      AnalyticsService.instance.logJobsheetSavedDraft();

      if (mounted) {
        context.showSuccessToast('Draft saved successfully');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        context.showErrorToast('Error saving draft: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _scrollToFirstError() {
    final fields = [
      (key: _customerNameKey, focus: _customerNameFocus, hasError: () => _customerNameController.text.trim().isEmpty),
      (key: _siteAddressKey, focus: _siteAddressFocus, hasError: () => _siteAddressController.text.trim().isEmpty),
      (key: _jobNumberKey, focus: _jobNumberFocus, hasError: () => _jobNumberController.text.trim().isEmpty),
      // Dynamic required fields
      ...widget.template.fields.where((f) => f.required).map((f) {
        final controller = _textControllers[f.id];
        final isEmpty = controller != null
            ? () => controller.text.trim().isEmpty
            : () => _formData[f.id] == null || _formData[f.id].toString().isEmpty;
        return (key: _dynamicFieldKeys[f.id]!, focus: _dynamicFieldFocusNodes[f.id]!, hasError: isEmpty);
      }),
    ];
    for (final field in fields) {
      if (field.hasError()) {
        final ctx = field.key.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(ctx, duration: AppTheme.normalAnimation, curve: AppTheme.defaultCurve, alignment: 0.2)
              .then((_) => field.focus.requestFocus());
        }
        break;
      }
    }
  }

  Future<void> _validateAndContinue() async {
    // Validate form (including dynamic fields)
    if (!_formKey.currentState!.validate()) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFirstError());
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Build field labels map for PDF generation
      final fieldLabels = <String, String>{};
      for (var field in widget.template.fields) {
        fieldLabels[field.id] = field.label;
      }

      // Create jobsheet object
      final jobsheet = Jobsheet(
        id: const Uuid().v4(),
        engineerId: user.uid,
        engineerName: _engineerNameController.text.trim(),
        date: _selectedDate,
        customerName: _customerNameController.text.trim(),
        siteAddress: _siteAddressController.text.trim(),
        jobNumber: _jobNumberController.text.trim(),
        systemCategory: _systemCategoryController.text.trim(),
        templateType: widget.template.name,
        formData: Map.from(_formData),
        fieldLabels: fieldLabels,
        notes: _notesController.text.trim(),
        defects: [],
        createdAt: DateTime.now(),
        sectionLayout: widget.template.sectionLayout,
        dispatchedJobId: widget.dispatchedJob?.id,
      );

      // Save to database (without signatures yet)
      await _dbHelper.insertJobsheet(jobsheet);
      AnalyticsService.instance.logJobsheetStarted(widget.template.name);

      if (mounted) {
        setState(() => _isLoading = false);

        // Navigate to signature screen
        Navigator.push(
          context,
          adaptivePageRoute(
            builder: (_) => SignatureScreen(
              jobsheet: jobsheet,
              dispatchedJob: widget.dispatchedJob,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        context.showErrorToast('Error saving jobsheet: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  IconData _getFieldIcon(TemplateField field) {
    // Map field IDs to appropriate icons
    final iconMap = {
      'panel_make': AppIcons.settingOutline,
      'panel_location': AppIcons.location,
      'battery_type': AppIcons.batteryCharging,
      'detector_location': AppIcons.location,
      'zone_number': AppIcons.tag,
      'fault_reported': AppIcons.warning,
      'action_taken': AppIcons.designtools,
    };

    return iconMap[field.id] ?? AppIcons.edit;
  }
}
