import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import '../../models/pdf_form_template.dart';
import '../../services/database_helper.dart';
import '../../services/auth_service.dart';
import '../../services/template_pdf_service.dart';
import '../../utils/adaptive_widgets.dart';
import '../../utils/icon_map.dart';
import '../../widgets/premium_toast.dart';
import '../../widgets/adaptive_app_bar.dart';
import '../../widgets/keyboard_dismiss_wrapper.dart';
import '../common/pdf_preview_screen.dart';
import '../../widgets/premium_dialog.dart';

class PdfFormBuilderScreen extends StatefulWidget {
  final PdfFormTemplate template;
  final FilledPdfForm? existingFilled; // If editing an existing filled form

  const PdfFormBuilderScreen({
    super.key,
    required this.template,
    this.existingFilled,
  });

  @override
  State<PdfFormBuilderScreen> createState() => _PdfFormBuilderScreenState();
}

class _PdfFormBuilderScreenState extends State<PdfFormBuilderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dbHelper = DatabaseHelper.instance;
  final _authService = AuthService();
  final _jobReferenceController = TextEditingController();

  late Map<String, dynamic> _fieldValues;
  late String _engineerName;
  int _currentPage = 0;
  bool _isSaving = false;

  // Signature controllers map
  final Map<String, SignatureController> _signatureControllers = {};

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    final user = _authService.currentUser;
    _engineerName = user?.displayName ?? user?.email?.split('@')[0] ?? 'Engineer';

    if (widget.existingFilled != null) {
      _fieldValues = Map<String, dynamic>.from(widget.existingFilled!.fieldValues);
      _jobReferenceController.text = widget.existingFilled!.jobReference;
    } else {
      _fieldValues = {};
      // Set default values
      for (final field in widget.template.fields) {
        if (field.defaultValue != null) {
          _fieldValues[field.id] = field.defaultValue;
        }
      }
      // Generate job reference
      _jobReferenceController.text = 'JOB-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    }

    // Initialize signature controllers
    for (final field in widget.template.fields) {
      if (field.type == FormFieldDefinitionType.signature) {
        _signatureControllers[field.id] = SignatureController(
          penStrokeWidth: 2,
          penColor: Colors.black,
        );
      }
    }
  }

  @override
  void dispose() {
    _jobReferenceController.dispose();
    for (final controller in _signatureControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<FormFieldDefinition> get _currentPageFields {
    return widget.template.fields
        .where((f) => f.page == _currentPage)
        .toList()
      ..sort((a, b) => a.y.compareTo(b.y));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdaptiveNavigationBar(
        title: widget.template.name,
        actions: [
          IconButton(
            icon: Icon(AppIcons.save),
            onPressed: _saveForm,
            tooltip: 'Save',
          ),
          IconButton(
            icon: Icon(AppIcons.document),
            onPressed: _generatePdf,
            tooltip: 'Generate PDF',
          ),
        ],
      ),
      body: KeyboardDismissWrapper(child: Column(
        children: [
          // Job reference header
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _jobReferenceController,
                    decoration: const InputDecoration(
                      labelText: 'Job Reference',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.done,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Page ${_currentPage + 1} of ${widget.template.pageCount}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          // Form fields
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView.builder(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(16),
                itemCount: _currentPageFields.length,
                itemBuilder: (context, index) {
                  final field = _currentPageFields[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildFieldWidget(field),
                  );
                },
              ),
            ),
          ),
          // Page navigation
          if (widget.template.pageCount > 1)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    onPressed: _currentPage > 0
                        ? () => setState(() => _currentPage--)
                        : null,
                    icon: Icon(AppIcons.arrowLeft),
                    label: const Text('Previous'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _currentPage < widget.template.pageCount - 1
                        ? () => setState(() => _currentPage++)
                        : null,
                    icon: Icon(AppIcons.arrowRight),
                    label: const Text('Next'),
                  ),
                ],
              ),
            ),
        ],
      )),
    );
  }

  Widget _buildFieldWidget(FormFieldDefinition field) {
    switch (field.type) {
      case FormFieldDefinitionType.text:
        return _buildTextField(field);
      case FormFieldDefinitionType.multilineText:
        return _buildMultilineTextField(field);
      case FormFieldDefinitionType.checkbox:
        return _buildCheckbox(field);
      case FormFieldDefinitionType.radioGroup:
        return _buildRadioGroup(field);
      case FormFieldDefinitionType.dropdown:
        return _buildDropdown(field);
      case FormFieldDefinitionType.datePicker:
        return _buildDatePicker(field);
      case FormFieldDefinitionType.signature:
        return _buildSignatureField(field);
      case FormFieldDefinitionType.image:
        return _buildImagePicker(field);
    }
  }

  Widget _buildTextField(FormFieldDefinition field) {
    return TextFormField(
      initialValue: _fieldValues[field.id]?.toString() ?? '',
      decoration: InputDecoration(
        labelText: field.label,
        border: const OutlineInputBorder(),
        suffixIcon: field.required
            ? Icon(AppIcons.danger, color: Colors.red, size: 12)
            : null,
      ),
      textInputAction: TextInputAction.done,
      validator: field.required
          ? (v) => v?.isEmpty == true ? 'Required' : null
          : null,
      onChanged: (v) => _fieldValues[field.id] = v,
    );
  }

  Widget _buildMultilineTextField(FormFieldDefinition field) {
    return TextFormField(
      initialValue: _fieldValues[field.id]?.toString() ?? '',
      decoration: InputDecoration(
        labelText: field.label,
        border: const OutlineInputBorder(),
        alignLabelWithHint: true,
      ),
      maxLines: 4,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      validator: field.required
          ? (v) => v?.isEmpty == true ? 'Required' : null
          : null,
      onChanged: (v) => _fieldValues[field.id] = v,
    );
  }

  Widget _buildCheckbox(FormFieldDefinition field) {
    return CheckboxListTile(
      title: Text(field.label),
      value: _fieldValues[field.id] == true,
      onChanged: (v) => setState(() => _fieldValues[field.id] = v),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildRadioGroup(FormFieldDefinition field) {
    final options = field.options ?? [];
    final selectedValue = _fieldValues[field.id]?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          field.label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        RadioGroup<String>(
          groupValue: selectedValue,
          onChanged: (v) => setState(() => _fieldValues[field.id] = v),
          child: Column(
            children: options.map((option) => RadioListTile<String>(
                  title: Text(option),
                  value: option,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                )).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(FormFieldDefinition field) {
    final options = field.options ?? [];
    final currentValue = _fieldValues[field.id]?.toString();

    return DropdownButtonFormField<String>(
      initialValue: options.contains(currentValue) ? currentValue : null,
      decoration: InputDecoration(
        labelText: field.label,
        border: const OutlineInputBorder(),
      ),
      items: options
          .map((o) => DropdownMenuItem(value: o, child: Text(o)))
          .toList(),
      onChanged: (v) => setState(() => _fieldValues[field.id] = v),
      validator: field.required
          ? (v) => v == null ? 'Required' : null
          : null,
    );
  }

  Widget _buildDatePicker(FormFieldDefinition field) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final currentValue = _fieldValues[field.id];
    DateTime? date;

    if (currentValue is DateTime) {
      date = currentValue;
    } else if (currentValue is String && currentValue.isNotEmpty) {
      try {
        date = DateTime.parse(currentValue);
      } catch (_) {
        try {
          date = dateFormat.parse(currentValue);
        } catch (_) {}
      }
    }

    return InkWell(
      onTap: () async {
        final picked = await showAdaptiveDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          setState(() {
            _fieldValues[field.id] = dateFormat.format(picked);
          });
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: field.label,
          border: const OutlineInputBorder(),
          suffixIcon: Icon(AppIcons.calendar),
        ),
        child: Text(
          date != null ? dateFormat.format(date) : 'Select date',
          style: TextStyle(
            color: date != null ? Colors.black : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildSignatureField(FormFieldDefinition field) {
    final controller = _signatureControllers[field.id]!;
    final hasSignature = _fieldValues[field.id] != null &&
        (_fieldValues[field.id] as String).isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              field.label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            if (hasSignature || controller.isNotEmpty)
              TextButton(
                onPressed: () {
                  controller.clear();
                  setState(() => _fieldValues[field.id] = null);
                },
                child: const Text('Clear'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 150,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[400]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: hasSignature
              ? Image.memory(
                  base64Decode(_fieldValues[field.id]),
                  fit: BoxFit.contain,
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Signature(
                    controller: controller,
                    backgroundColor: Colors.white,
                  ),
                ),
        ),
        const SizedBox(height: 8),
        if (!hasSignature)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                if (controller.isNotEmpty) {
                  final data = await controller.toPngBytes();
                  if (data != null) {
                    setState(() {
                      _fieldValues[field.id] = base64Encode(data);
                    });
                  }
                }
              },
              icon: Icon(AppIcons.tickCircle),
              label: const Text('Confirm Signature'),
            ),
          ),
      ],
    );
  }

  Widget _buildImagePicker(FormFieldDefinition field) {
    final imagePath = _fieldValues[field.id]?.toString();
    final hasImage = imagePath != null && imagePath.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          field.label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[400]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: hasImage
              ? Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(imagePath),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton.filled(
                        onPressed: () {
                          setState(() => _fieldValues[field.id] = null);
                        },
                        icon: Icon(AppIcons.close),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                )
              : InkWell(
                  onTap: () => _pickImage(field),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(AppIcons.gallery,
                          size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text('Tap to add image',
                          style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _pickImage(FormFieldDefinition field) async {
    final picker = ImagePicker();
    ImageSource? source;

    await showAdaptiveActionSheet(
      context: context,
      title: 'Select Image Source',
      options: [
        ActionSheetOption(
          label: 'Camera',
          icon: AppIcons.gallery,
          onTap: () => source = ImageSource.camera,
        ),
        ActionSheetOption(
          label: 'Gallery',
          icon: AppIcons.gallery,
          onTap: () => source = ImageSource.gallery,
        ),
      ],
    );

    if (source != null) {
      final image = await picker.pickImage(source: source!, imageQuality: 80);
      if (image != null) {
        setState(() {
          _fieldValues[field.id] = image.path;
        });
      }
    }
  }

  Future<void> _saveForm() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final user = _authService.currentUser;
      if (user == null) {
        _showError('Not logged in');
        return;
      }

      final filled = FilledPdfForm(
        id: widget.existingFilled?.id ?? const Uuid().v4(),
        templateId: widget.template.id,
        engineerId: user.uid,
        engineerName: _engineerName,
        jobReference: _jobReferenceController.text,
        fieldValues: _fieldValues,
        createdAt: widget.existingFilled?.createdAt ?? DateTime.now(),
        isComplete: false,
      );

      if (widget.existingFilled != null) {
        await _dbHelper.updateFilledPdfForm(filled);
      } else {
        await _dbHelper.insertFilledPdfForm(filled);
      }

      if (mounted) {
        context.showSuccessToast('Form saved successfully');
      }
    } catch (e) {
      _showError('Error saving: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _generatePdf() async {
    try {
      final pdfBytes = await TemplatePdfService.generateFilledPdf(
        template: widget.template,
        fieldValues: _fieldValues,
        engineerName: _engineerName,
        jobReference: _jobReferenceController.text,
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfPreviewScreen(
            pdfBytes: pdfBytes,
            title: widget.template.name,
            fileName: '${widget.template.name}_${_jobReferenceController.text}.pdf',
          ),
        ),
      );
    } catch (e) {
      _showError('Error generating PDF: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      context.showErrorToast(message);
    }
  }
}
