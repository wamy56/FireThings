import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/icon_map.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/asset_service.dart';
import '../../services/asset_type_service.dart';
import '../../services/database_helper.dart';
import '../../services/remote_config_service.dart';
import '../../services/service_history_service.dart';
import '../../widgets/widgets.dart';
import '../../utils/adaptive_widgets.dart';
import '../../utils/theme.dart';
import '../../data/default_asset_types.dart';
import '../saved_sites/site_picker_screen.dart';
import '../assets/batch_test_screen.dart';
import '../../services/analytics_service.dart';
import '../../utils/rotation_tracker.dart';
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
  String? _selectedSiteId;
  final List<Map<String, dynamic>> _testedAssets = [];

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
      if (field.type == FieldType.repeatGroup) {
        // Initialize repeat group with one empty entry
        final entryId = const Uuid().v4();
        _formData[field.id] = <Map<String, dynamic>>[
          {'_entryId': entryId},
        ];
        _initRepeatEntryControllers(field, entryId);
        if (field.required) {
          _dynamicFieldKeys[field.id] = GlobalKey();
          _dynamicFieldFocusNodes[field.id] = FocusNode();
        }
        continue;
      }
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
    _selectedSiteId = draft.siteId;

    // Load dynamic form data
    _formData.addAll(draft.formData);

    // Populate text controllers from form data
    for (var field in widget.template.fields) {
      if (field.type == FieldType.repeatGroup && draft.formData.containsKey(field.id)) {
        final entries = draft.formData[field.id];
        if (entries is List && entries.isNotEmpty) {
          // Dispose any controllers created during initState for the default empty entry
          _disposeRepeatGroupControllers(field.id);

          final loadedEntries = <Map<String, dynamic>>[];
          for (final rawEntry in entries) {
            final entry = Map<String, dynamic>.from(rawEntry as Map);
            // Ensure each entry has a stable ID
            if (!entry.containsKey('_entryId')) {
              entry['_entryId'] = const Uuid().v4();
            }
            loadedEntries.add(entry);
            _initRepeatEntryControllers(field, entry['_entryId'] as String);
            // Populate controllers with saved values
            for (final child in field.children ?? <TemplateField>[]) {
              final controllerKey = '${field.id}.${entry['_entryId']}.${child.id}';
              if (_textControllers.containsKey(controllerKey) && entry.containsKey(child.id)) {
                _textControllers[controllerKey]!.text = entry[child.id]?.toString() ?? '';
              }
            }
          }
          _formData[field.id] = loadedEntries;
        }
        continue;
      }
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

              // Site Assets Section (conditional)
              if (_selectedSiteId != null &&
                  RemoteConfigService.instance.assetRegisterEnabled) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),
                _buildSiteAssetsSection(),
              ],

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

  Widget _buildSiteAssetsSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final passCount = _testedAssets.where((a) => a['result'] == 'pass').length;
    final failCount = _testedAssets.where((a) => a['result'] == 'fail').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader('Site Assets', AppIcons.clipboard),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _testSiteAssets,
          icon: Icon(AppIcons.setting),
          label: Text(_testedAssets.isEmpty
              ? 'Test Assets'
              : 'Test More Assets'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentOrange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        if (_testedAssets.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            '${_testedAssets.length} assets tested: $passCount pass, $failCount fail',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ..._testedAssets.map((a) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: a['result'] == 'pass'
                        ? AppTheme.successGreen
                        : AppTheme.errorRed,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${a['reference'] ?? 'No ref'} — ${a['typeName'] ?? 'Unknown'}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Text(
                  (a['result'] as String).toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: a['result'] == 'pass'
                        ? AppTheme.successGreen
                        : AppTheme.errorRed,
                  ),
                ),
              ],
            ),
          )),
        ],
      ],
    );
  }

  Future<void> _testSiteAssets() async {
    final user = _authService.currentUser;
    if (user == null || _selectedSiteId == null) return;

    final basePath = 'users/${user.uid}';
    final siteId = _selectedSiteId!;

    // Fetch assets and types for the site
    final assets = await AssetService.instance
        .getAssetsStream(basePath, siteId).first;
    final assetTypes = await AssetTypeService.instance
        .getAssetTypes(basePath);

    if (!mounted) return;

    if (assets.isEmpty) {
      context.showErrorToast('No assets found for this site');
      return;
    }

    // Filter to only active (non-decommissioned) assets
    final activeAssets = assets
        .where((a) => a.complianceStatus != 'decommissioned')
        .toList();

    if (activeAssets.isEmpty) {
      context.showErrorToast('No active assets at this site');
      return;
    }

    // Generate a temporary jobsheet ID for tagging records
    // Use the draft ID if editing, otherwise create one
    final jobsheetId = _isEditingDraft ? _draftId! : const Uuid().v4();

    // For quarterly tests, calculate suggested 25% rotation
    List<String>? suggestedAssetIds;
    if (widget.template.id == 'quarterly_test') {
      suggestedAssetIds = await RotationTracker.getSuggestedAssets(
        basePath: basePath,
        siteId: siteId,
        assets: activeAssets,
      );
    }

    if (!mounted) return;

    final result = await Navigator.of(context).push<bool>(
      adaptivePageRoute(
        builder: (_) => BatchTestScreen(
          basePath: basePath,
          siteId: siteId,
          assets: activeAssets,
          assetTypes: assetTypes,
          jobsheetId: jobsheetId,
          suggestedAssetIds: suggestedAssetIds,
        ),
      ),
    );

    if (result == true && mounted) {
      // Refresh tested assets list from service history
      final records = await ServiceHistoryService.instance
          .getRecordsForJobsheet(basePath, siteId, jobsheetId);

      setState(() {
        _testedAssets.clear();
        for (final record in records) {
          // Find the asset to get reference and type info
          final asset = assets.where((a) => a.id == record.assetId).firstOrNull;
          final assetType = asset != null
              ? (assetTypes.where((t) => t.id == asset.assetTypeId).firstOrNull
                  ?? DefaultAssetTypes.getById(asset.assetTypeId))
              : null;

          _testedAssets.add({
            'assetId': record.assetId,
            'reference': asset?.reference ?? 'Unknown',
            'typeName': assetType?.name ?? 'Unknown',
            'location': asset?.locationDescription ?? '',
            'zone': asset?.zone ?? '',
            'result': record.overallResult,
          });
        }
      });
    }
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

      case FieldType.repeatGroup:
        return _buildRepeatGroupField(field);
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

  // ---------------------------------------------------------------------------
  // Repeat Group Helpers
  // ---------------------------------------------------------------------------

  void _initRepeatEntryControllers(TemplateField groupField, String entryId) {
    for (final child in groupField.children ?? <TemplateField>[]) {
      if (child.type == FieldType.text ||
          child.type == FieldType.number ||
          child.type == FieldType.multiline) {
        _textControllers['${groupField.id}.$entryId.${child.id}'] =
            TextEditingController();
      }
    }
  }

  void _disposeRepeatGroupControllers(String groupId) {
    final keysToRemove = _textControllers.keys
        .where((k) => k.startsWith('$groupId.'))
        .toList();
    for (final key in keysToRemove) {
      _textControllers[key]!.dispose();
      _textControllers.remove(key);
    }
  }

  void _addRepeatEntry(TemplateField groupField) {
    final entries = _formData[groupField.id] as List<Map<String, dynamic>>;
    if (groupField.maxEntries != null &&
        entries.length >= groupField.maxEntries!) {
      return;
    }
    final entryId = const Uuid().v4();
    _initRepeatEntryControllers(groupField, entryId);
    setState(() {
      entries.add({'_entryId': entryId});
    });
  }

  void _removeRepeatEntry(TemplateField groupField, int index) {
    final entries = _formData[groupField.id] as List<Map<String, dynamic>>;
    final minEntries = groupField.minEntries ?? 1;
    if (entries.length <= minEntries) return;

    final entryId = entries[index]['_entryId'] as String;
    // Dispose controllers for this entry
    for (final child in groupField.children ?? <TemplateField>[]) {
      final key = '${groupField.id}.$entryId.${child.id}';
      _textControllers[key]?.dispose();
      _textControllers.remove(key);
    }
    setState(() {
      entries.removeAt(index);
    });
  }

  void _syncRepeatEntryData(TemplateField groupField) {
    final entries = _formData[groupField.id] as List<Map<String, dynamic>>;
    for (final entry in entries) {
      final entryId = entry['_entryId'] as String;
      for (final child in groupField.children ?? <TemplateField>[]) {
        final key = '${groupField.id}.$entryId.${child.id}';
        if (_textControllers.containsKey(key)) {
          entry[child.id] = _textControllers[key]!.text;
        }
      }
    }
  }

  Widget _buildRepeatGroupField(TemplateField field) {
    final entries = _formData[field.id] as List<Map<String, dynamic>>? ?? [];
    final children = field.children ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final minEntries = field.minEntries ?? 1;
    final canAdd =
        field.maxEntries == null || entries.length < field.maxEntries!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section header
        Row(
          children: [
            Icon(AppIcons.element, color: AppTheme.primaryBlue, size: 20),
            const SizedBox(width: 8),
            Text(
              field.label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${entries.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Entry cards
        ...entries.asMap().entries.map((mapEntry) {
          final index = mapEntry.key;
          final entry = mapEntry.value;
          final entryId = entry['_entryId'] as String;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              boxShadow: AppTheme.cardShadow,
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.grey.withValues(alpha: 0.15),
              ),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
              ),
              child: ExpansionTile(
                initiallyExpanded: true,
                tilePadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                childrenPadding:
                    const EdgeInsets.fromLTRB(16, 0, 16, 16),
                title: Row(
                  children: [
                    Text(
                      '#${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _repeatEntrySummary(entry, children),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.textSecondary,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                trailing: entries.length > minEntries
                    ? IconButton(
                        icon: Icon(AppIcons.close, size: 18),
                        color: AppTheme.errorRed,
                        onPressed: () =>
                            _removeRepeatEntry(field, index),
                        tooltip: 'Remove entry',
                      )
                    : null,
                children: children.map((child) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildRepeatChildField(
                        field.id, entryId, entry, child),
                  );
                }).toList(),
              ),
            ),
          );
        }),

        // Add button
        if (canAdd)
          OutlinedButton.icon(
            onPressed: () => _addRepeatEntry(field),
            icon: Icon(AppIcons.addCircle, size: 18),
            label: const Text('Add Another'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryBlue,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide(
                color: AppTheme.primaryBlue.withValues(alpha: 0.3),
              ),
            ),
          ),
      ],
    );
  }

  String _repeatEntrySummary(
      Map<String, dynamic> entry, List<TemplateField> children) {
    // Try to build a useful summary from the first text/dropdown values
    for (final child in children) {
      final value = entry[child.id];
      if (value != null && value.toString().isNotEmpty) {
        return value.toString();
      }
    }
    return 'New entry';
  }

  Widget _buildRepeatChildField(
    String groupId,
    String entryId,
    Map<String, dynamic> entry,
    TemplateField child,
  ) {
    final controllerKey = '$groupId.$entryId.${child.id}';

    switch (child.type) {
      case FieldType.text:
        return CustomTextField(
          controller: _textControllers[controllerKey],
          label: child.label + (child.required ? ' *' : ''),
          onChanged: (value) => entry[child.id] = value,
          validator: child.required
              ? (value) {
                  if (value == null || value.isEmpty) {
                    return '${child.label} is required';
                  }
                  return null;
                }
              : null,
        );

      case FieldType.number:
        return CustomTextField(
          controller: _textControllers[controllerKey],
          label: child.label + (child.required ? ' *' : ''),
          keyboardType: TextInputType.number,
          onChanged: (value) => entry[child.id] = value,
          validator: child.required
              ? (value) {
                  if (value == null || value.isEmpty) {
                    return '${child.label} is required';
                  }
                  return null;
                }
              : null,
        );

      case FieldType.multiline:
        return CustomTextField(
          controller: _textControllers[controllerKey],
          label: child.label + (child.required ? ' *' : ''),
          maxLines: 3,
          onChanged: (value) => entry[child.id] = value,
          validator: child.required
              ? (value) {
                  if (value == null || value.isEmpty) {
                    return '${child.label} is required';
                  }
                  return null;
                }
              : null,
        );

      case FieldType.dropdown:
        return DropdownButtonFormField<String>(
          initialValue: entry[child.id] as String?,
          decoration: InputDecoration(
            labelText: child.label + (child.required ? ' *' : ''),
            prefixIcon: Icon(AppIcons.arrowDown),
          ),
          items: child.options!.map((option) {
            return DropdownMenuItem(value: option, child: Text(option));
          }).toList(),
          onChanged: (value) {
            setState(() {
              entry[child.id] = value;
            });
          },
          validator: child.required
              ? (value) {
                  if (value == null || value.isEmpty) {
                    return '${child.label} is required';
                  }
                  return null;
                }
              : null,
        );

      case FieldType.checkbox:
        return CheckboxListTile(
          title: Text(child.label),
          value: entry[child.id] as bool? ?? false,
          onChanged: (value) {
            setState(() {
              entry[child.id] = value ?? false;
            });
          },
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        );

      case FieldType.date:
        final dateFormat = DateFormat('dd/MM/yyyy');
        String displayValue = '';
        if (entry[child.id] != null) {
          try {
            final date = DateTime.parse(entry[child.id] as String);
            displayValue = dateFormat.format(date);
          } catch (_) {
            displayValue = entry[child.id].toString();
          }
        }
        return InkWell(
          onTap: () async {
            final picked = await showAdaptiveDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (picked != null) {
              setState(() {
                entry[child.id] = picked.toIso8601String();
              });
            }
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: child.label + (child.required ? ' *' : ''),
              prefixIcon: Icon(AppIcons.calendar),
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

      case FieldType.repeatGroup:
        // Nested repeat groups not supported
        return const SizedBox.shrink();
    }
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
        _selectedSiteId = selected.id;
      });
      // Auto-populate from asset register for annual inspection
      if (RemoteConfigService.instance.assetRegisterEnabled) {
        _autoPopulateFromAssetRegister(selected.id);
      }
    }
  }

  Future<void> _autoPopulateFromAssetRegister(String siteId) async {
    final templateId = widget.template.id;
    if (templateId != 'annual_inspection' && templateId != 'quarterly_test') {
      return;
    }

    final user = _authService.currentUser;
    if (user == null) return;

    final basePath = 'users/${user.uid}';

    try {
      final assets = await AssetService.instance
          .getAssetsStream(basePath, siteId)
          .first;

      final activeAssets = assets
          .where((a) => a.complianceStatus != 'decommissioned')
          .toList();

      if (activeAssets.isEmpty || !mounted) return;

      if (templateId == 'annual_inspection') {
        final totalDevices = activeAssets.length;
        final zones = activeAssets
            .where((a) => a.zone != null && a.zone!.isNotEmpty)
            .map((a) => a.zone!)
            .toSet();

        setState(() {
          _formData['total_devices'] = totalDevices.toString();
          _formData['total_zones'] = zones.length.toString();
          if (_textControllers.containsKey('total_devices')) {
            _textControllers['total_devices']!.text = totalDevices.toString();
          }
          if (_textControllers.containsKey('total_zones')) {
            _textControllers['total_zones']!.text = zones.length.toString();
          }
        });
      }
    } catch (e) {
      // Silently fail — auto-populate is a convenience, not critical
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
        if (field.type == FieldType.repeatGroup) {
          _syncRepeatEntryData(field);
          continue;
        }
        if (_textControllers.containsKey(field.id)) {
          _formData[field.id] = _textControllers[field.id]!.text;
        }
      }

      // Build field labels map for PDF generation
      final fieldLabels = _buildFieldLabels();

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
        siteId: _selectedSiteId,
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

    // Validate repeat group required children programmatically
    // (collapsed ExpansionTiles may not have validators in the widget tree)
    for (final field in widget.template.fields) {
      if (field.type == FieldType.repeatGroup) {
        _syncRepeatEntryData(field);
        final entries = _formData[field.id] as List<Map<String, dynamic>>? ?? [];
        for (var i = 0; i < entries.length; i++) {
          for (final child in field.children ?? <TemplateField>[]) {
            if (child.required) {
              final value = entries[i][child.id];
              if (value == null || value.toString().trim().isEmpty) {
                if (mounted) {
                  context.showErrorToast(
                    '${child.label} is required in ${field.label} #${i + 1}',
                  );
                }
                return;
              }
            }
          }
        }
      }
    }

    setState(() => _isLoading = true);

    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Sync repeat group text controllers before saving
      for (final field in widget.template.fields) {
        if (field.type == FieldType.repeatGroup) {
          _syncRepeatEntryData(field);
        }
      }

      // Build field labels map for PDF generation
      final fieldLabels = _buildFieldLabels();

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
        siteId: _selectedSiteId,
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

  Map<String, String> _buildFieldLabels() {
    final fieldLabels = <String, String>{};
    for (var field in widget.template.fields) {
      fieldLabels[field.id] = field.label;
      if (field.type == FieldType.repeatGroup && field.children != null) {
        for (final child in field.children!) {
          fieldLabels['${field.id}.${child.id}'] = child.label;
        }
      }
    }
    return fieldLabels;
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
