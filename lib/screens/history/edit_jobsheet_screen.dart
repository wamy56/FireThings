import 'package:flutter/material.dart';
import '../../utils/adaptive_widgets.dart';
import 'package:intl/intl.dart';
import '../../utils/icon_map.dart';
import '../../models/models.dart';
import '../../services/database_helper.dart';
import '../../widgets/widgets.dart';
import '../../utils/theme.dart';
import '../signature/signature_screen.dart';

class EditJobsheetScreen extends StatefulWidget {
  final Jobsheet jobsheet;

  const EditJobsheetScreen({super.key, required this.jobsheet});

  @override
  State<EditJobsheetScreen> createState() => _EditJobsheetScreenState();
}

class _EditJobsheetScreenState extends State<EditJobsheetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dbHelper = DatabaseHelper.instance;

  // Standard field controllers
  late TextEditingController _customerNameController;
  late TextEditingController _siteAddressController;
  late TextEditingController _jobNumberController;
  late TextEditingController _systemCategoryController;
  late TextEditingController _notesController;

  // Keys and focus nodes for scroll-to-error
  final _customerNameKey = GlobalKey();
  final _customerNameFocus = FocusNode();
  final _siteAddressKey = GlobalKey();
  final _siteAddressFocus = FocusNode();
  final _jobNumberKey = GlobalKey();
  final _jobNumberFocus = FocusNode();

  // Dynamic form data storage
  late Map<String, dynamic> _formData;
  final Map<String, TextEditingController> _textControllers = {};

  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();

    // Initialize with existing jobsheet data
    _customerNameController = TextEditingController(
      text: widget.jobsheet.customerName,
    );
    _siteAddressController = TextEditingController(
      text: widget.jobsheet.siteAddress,
    );
    _jobNumberController = TextEditingController(
      text: widget.jobsheet.jobNumber,
    );
    _systemCategoryController = TextEditingController(
      text: widget.jobsheet.systemCategory,
    );
    _notesController = TextEditingController(text: widget.jobsheet.notes);

    // Copy form data
    _formData = Map<String, dynamic>.from(widget.jobsheet.formData);

    // Initialize text controllers for dynamic fields
    for (var entry in _formData.entries) {
      if (entry.value is List) {
        // Repeat group data — initialize controllers per entry per child
        final entries = entry.value as List;
        for (final rawEntry in entries) {
          final entryMap = rawEntry as Map<String, dynamic>;
          final entryId = entryMap['_entryId'] as String? ?? entry.key;
          for (final childEntry in entryMap.entries) {
            if (childEntry.key == '_entryId') continue;
            if (childEntry.value is String || childEntry.value is num) {
              _textControllers['${entry.key}.$entryId.${childEntry.key}'] =
                  TextEditingController(text: childEntry.value.toString());
            }
          }
        }
      } else if (entry.value is String || entry.value is num) {
        _textControllers[entry.key] = TextEditingController(
          text: entry.value.toString(),
        );
      }
    }

    // Add change listeners
    _customerNameController.addListener(_onFieldChanged);
    _siteAddressController.addListener(_onFieldChanged);
    _jobNumberController.addListener(_onFieldChanged);
    _systemCategoryController.addListener(_onFieldChanged);
    _notesController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _siteAddressController.dispose();
    _jobNumberController.dispose();
    _systemCategoryController.dispose();
    _notesController.dispose();
    _customerNameFocus.dispose();
    _siteAddressFocus.dispose();
    _jobNumberFocus.dispose();

    for (var controller in _textControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final result = await showAdaptiveAlertDialog<bool>(
      context: context,
      title: 'Discard Changes?',
      message: 'You have unsaved changes. Are you sure you want to leave?',
      confirmLabel: 'Discard',
      cancelLabel: 'Cancel',
      isDestructive: true,
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AdaptiveNavigationBar(
          title: 'Edit Jobsheet',
          actions: [
            if (_hasChanges)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: AnimatedSaveButton(
                  label: 'Save Draft',
                  onPressed: _saveChanges,
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

              // Date (read-only)
              CustomTextField(
                label: 'Date',
                initialValue: dateFormat.format(widget.jobsheet.date),
                readOnly: true,
                enabled: false,
                prefixIcon: Icon(AppIcons.calendar),
              ),
              const SizedBox(height: 16),

              // Engineer (read-only)
              CustomTextField(
                label: 'Engineer',
                initialValue: widget.jobsheet.engineerName,
                readOnly: true,
                enabled: false,
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

              // Site Address
              CustomTextField(
                key: _siteAddressKey,
                controller: _siteAddressController,
                focusNode: _siteAddressFocus,
                label: 'Site Address *',
                hint: 'Enter site address',
                maxLines: 2,
                prefixIcon: Icon(AppIcons.location),
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

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),

              // Work Details Section
              _buildSectionHeader('Work Details', AppIcons.designtools),
              const SizedBox(height: 16),
              _buildDynamicFields(),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),

              // Notes Section
              _buildSectionHeader('Additional Notes', AppIcons.note),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _notesController,
                label: 'Notes',
                hint: 'Add any additional notes or observations',
                maxLines: 4,
              ),

              const SizedBox(height: 32),

              // Action Buttons
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CustomButton(
                    text: 'Save Changes',
                    icon: AppIcons.save,
                    onPressed: _saveChanges,
                    isLoading: _isLoading,
                    isFullWidth: true,
                  ),
                  const SizedBox(height: 12),
                  CustomOutlinedButton(
                    text: 'Update Signatures',
                    icon: AppIcons.edit,
                    onPressed: _goToSignatures,
                    isFullWidth: true,
                  ),
                ],
              ),

              const SizedBox(height: 16),
            ],
          ),
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

  Widget _buildDynamicFields() {
    return Column(
      children: _formData.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildFieldWidget(entry.key, entry.value),
        );
      }).toList(),
    );
  }

  /// Check if a string value looks like an ISO 8601 date (from date picker fields).
  bool _isDateValue(dynamic value) {
    if (value is! String) return false;
    return RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}').hasMatch(value);
  }

  Widget _buildFieldWidget(String key, dynamic value) {
    final label = _formatFieldLabel(key);

    if (value is bool) {
      return _buildCheckboxField(key, label, value);
    } else if (value is List) {
      return _buildRepeatGroupEditor(key, label, value);
    } else if (_isDateValue(value)) {
      return _buildDateField(key, label, value as String);
    } else {
      return CustomTextField(
        controller: _textControllers[key],
        label: label,
        onChanged: (newValue) {
          setState(() {
            _formData[key] = newValue;
            _hasChanges = true;
          });
        },
      );
    }
  }

  Widget _buildDateField(String key, String label, String isoValue) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    String displayValue = isoValue;
    DateTime currentDate = DateTime.now();
    try {
      currentDate = DateTime.parse(isoValue);
      displayValue = dateFormat.format(currentDate);
    } catch (_) {}

    return GestureDetector(
      onTap: () async {
        final picked = await showAdaptiveDatePicker(
          context: context,
          initialDate: currentDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) {
          setState(() {
            _formData[key] = picked.toIso8601String();
            _textControllers[key]?.text = dateFormat.format(picked);
            _hasChanges = true;
          });
        }
      },
      child: AbsorbPointer(
        child: CustomTextField(
          label: label,
          initialValue: displayValue,
          readOnly: true,
          prefixIcon: Icon(AppIcons.calendar),
        ),
      ),
    );
  }

  Widget _buildRepeatGroupEditor(String groupKey, String label, List entries) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Get human-readable labels from the jobsheet's fieldLabels
    final fieldLabels = widget.jobsheet.fieldLabels;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(AppIcons.element, color: AppTheme.primaryBlue, size: 20),
            const SizedBox(width: 8),
            Text(
              fieldLabels[groupKey] ?? label,
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
        ...entries.asMap().entries.map((mapEntry) {
          final index = mapEntry.key;
          final entry = mapEntry.value as Map<String, dynamic>;
          final entryId = entry['_entryId'] as String? ?? groupKey;

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
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: index == 0,
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                title: Text(
                  '#${index + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                children: entry.entries
                    .where((e) => e.key != '_entryId')
                    .map((childEntry) {
                  final childLabel = fieldLabels['$groupKey.${childEntry.key}'] ??
                      _formatFieldLabel(childEntry.key);
                  final controllerKey = '$groupKey.$entryId.${childEntry.key}';

                  if (childEntry.value is bool) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: CheckboxListTile(
                        title: Text(childLabel),
                        value: childEntry.value as bool,
                        onChanged: (newValue) {
                          setState(() {
                            entry[childEntry.key] = newValue ?? false;
                            _hasChanges = true;
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                    );
                  }

                  if (_isDateValue(childEntry.value)) {
                    final dateFormat = DateFormat('dd/MM/yyyy');
                    String displayValue = childEntry.value as String;
                    DateTime currentDate = DateTime.now();
                    try {
                      currentDate = DateTime.parse(childEntry.value as String);
                      displayValue = dateFormat.format(currentDate);
                    } catch (_) {}

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showAdaptiveDatePicker(
                            context: context,
                            initialDate: currentDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setState(() {
                              entry[childEntry.key] = picked.toIso8601String();
                              _textControllers[controllerKey]?.text =
                                  dateFormat.format(picked);
                              _hasChanges = true;
                            });
                          }
                        },
                        child: AbsorbPointer(
                          child: CustomTextField(
                            label: childLabel,
                            initialValue: displayValue,
                            readOnly: true,
                            prefixIcon: Icon(AppIcons.calendar),
                          ),
                        ),
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: CustomTextField(
                      controller: _textControllers[controllerKey],
                      label: childLabel,
                      onChanged: (newValue) {
                        setState(() {
                          entry[childEntry.key] = newValue;
                          _hasChanges = true;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCheckboxField(String key, String label, bool value) {
    return CheckboxListTile(
      title: Text(label),
      value: _formData[key] as bool? ?? value,
      onChanged: (newValue) {
        setState(() {
          _formData[key] = newValue ?? false;
          _hasChanges = true;
        });
      },
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
    );
  }

  String _formatFieldLabel(String key) {
    return key
        .split('_')
        .map((word) => word.isNotEmpty
            ? word[0].toUpperCase() + word.substring(1)
            : '')
        .join(' ');
  }

  void _scrollToFirstError() {
    final fields = [
      (key: _customerNameKey, focus: _customerNameFocus, hasError: () => _customerNameController.text.trim().isEmpty),
      (key: _siteAddressKey, focus: _siteAddressFocus, hasError: () => _siteAddressController.text.trim().isEmpty),
      (key: _jobNumberKey, focus: _jobNumberFocus, hasError: () => _jobNumberController.text.trim().isEmpty),
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

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFirstError());
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Update form data from text controllers
      for (var entry in _textControllers.entries) {
        if (_formData.containsKey(entry.key)) {
          _formData[entry.key] = entry.value.text;
        }
        // Sync repeat group child controllers back into the list entries
        final parts = entry.key.split('.');
        if (parts.length == 3) {
          final groupKey = parts[0];
          final entryId = parts[1];
          final childKey = parts[2];
          final groupData = _formData[groupKey];
          if (groupData is List) {
            for (final rawEntry in groupData) {
              final entryMap = rawEntry as Map<String, dynamic>;
              if (entryMap['_entryId'] == entryId) {
                entryMap[childKey] = entry.value.text;
              }
            }
          }
        }
      }

      // Create updated jobsheet
      final updatedJobsheet = widget.jobsheet.copyWith(
        customerName: _customerNameController.text.trim(),
        siteAddress: _siteAddressController.text.trim(),
        jobNumber: _jobNumberController.text.trim(),
        systemCategory: _systemCategoryController.text.trim(),
        notes: _notesController.text.trim(),
        formData: Map<String, dynamic>.from(_formData),
      );

      // Update in database
      await _dbHelper.updateJobsheet(updatedJobsheet);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _hasChanges = false;
      });

      context.showSuccessToast('Jobsheet updated successfully');

      // Return the updated jobsheet
      Navigator.pop(context, updatedJobsheet);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      context.showErrorToast('Error saving changes: $e');
    }
  }

  void _goToSignatures() async {
    // Save current changes first
    if (_hasChanges) {
      await _saveChanges();
    }

    if (!mounted) return;

    // Get the latest jobsheet data
    final currentJobsheet = widget.jobsheet.copyWith(
      customerName: _customerNameController.text.trim(),
      siteAddress: _siteAddressController.text.trim(),
      jobNumber: _jobNumberController.text.trim(),
      systemCategory: _systemCategoryController.text.trim(),
      notes: _notesController.text.trim(),
      formData: Map<String, dynamic>.from(_formData),
    );

    // Navigate to signature screen
    final result = await Navigator.push(
      context,
      adaptivePageRoute(
        builder: (_) => SignatureScreen(jobsheet: currentJobsheet),
      ),
    );

    // If signatures were updated, pop back with result
    if (result != null && mounted) {
      Navigator.pop(context, result);
    }
  }
}
