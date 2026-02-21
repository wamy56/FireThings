import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import '../../models/pdf_form_template.dart';
import '../../models/jobsheet.dart';
import '../../models/saved_site.dart';
import '../saved_sites/site_picker_screen.dart';
import '../../services/auth_service.dart';
import '../../services/database_helper.dart';
import '../../services/template_pdf_service.dart';
import '../../utils/pdf_form_templates.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import '../../utils/theme.dart';
import '../../widgets/widgets.dart';

/// Screen for filling the IQ Modification Certificate PDF form
class PdfFormFillScreen extends StatefulWidget {
  final PdfFormTemplate? template;
  final Jobsheet? existingJobsheet;

  const PdfFormFillScreen({super.key, this.template, this.existingJobsheet});

  @override
  State<PdfFormFillScreen> createState() => _PdfFormFillScreenState();
}

class _PdfFormFillScreenState extends State<PdfFormFillScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  // Text controllers
  final _customerNameController = TextEditingController();
  final _siteAddressController = TextEditingController();
  final _jobNoController = TextEditingController();
  final _installersController = TextEditingController();
  final _extentOfWorkController = TextEditingController();
  final _variationsController = TextEditingController();
  final _thirdPartyInstallerController = TextEditingController();
  final _subsequentVisitDetailsController = TextEditingController();
  final _engineerNameController = TextEditingController();
  final _engineerPositionController = TextEditingController();
  final _customerCertNameController = TextEditingController();
  final _customerPositionController = TextEditingController();
  final _systemCategoryController = TextEditingController();

  // Date values
  DateTime _date = DateTime.now();
  DateTime _engineerDate = DateTime.now();
  DateTime _customerDate = DateTime.now();

  // Checkbox values
  bool _systemTested = false;
  bool _drawingsUpdated = false;
  bool _noFalseAlarmPotential = false;
  bool _thirdPartyInstallation = false;
  bool _subsequentVisitRequired = false;

  // Signature controllers
  late SignatureController _engineerSignController;
  late SignatureController _customerSignController;
  String? _engineerSignatureData;
  String? _customerSignatureData;

  bool _isGenerating = false;


  late PdfFormTemplate _template;
  final _dbHelper = DatabaseHelper.instance;
  late String _draftId;
  bool _isEditingExisting = false;

  @override
  void initState() {
    super.initState();
    _template = widget.template ?? PdfFormTemplates.iqModificationCertificate;

    _engineerSignController = SignatureController(
      penStrokeWidth: 2,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );

    _customerSignController = SignatureController(
      penStrokeWidth: 2,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );

    if (widget.existingJobsheet != null) {
      _isEditingExisting = true;
      _draftId = widget.existingJobsheet!.id;
      _loadFromJobsheet(widget.existingJobsheet!);
    } else {
      _draftId = const Uuid().v4();
      // Pre-fill engineer name from user
      final user = _authService.currentUser;
      _engineerNameController.text =
          user?.displayName ?? user?.email?.split('@')[0] ?? '';
    }
  }

  void _loadFromJobsheet(Jobsheet jobsheet) {
    final data = jobsheet.formData;
    final dateFormat = DateFormat('dd/MM/yyyy');

    _customerNameController.text = data['customer_name'] as String? ?? '';
    _siteAddressController.text = data['site_address'] as String? ?? '';
    _jobNoController.text = data['job_no'] as String? ?? '';
    _installersController.text = data['installers'] as String? ?? '';
    _extentOfWorkController.text = data['extent_of_work'] as String? ?? '';
    _variationsController.text = data['variations_from_standard'] as String? ?? '';
    _thirdPartyInstallerController.text = data['third_party_installer_name'] as String? ?? '';
    _subsequentVisitDetailsController.text = data['subsequent_visit_details'] as String? ?? '';
    _engineerNameController.text = data['engineer_name'] as String? ?? '';
    _engineerPositionController.text = data['engineer_position'] as String? ?? '';
    _customerCertNameController.text = data['customer_cert_name'] as String? ?? '';
    _customerPositionController.text = data['customer_position'] as String? ?? '';
    _systemCategoryController.text = data['system_category'] as String? ?? '';

    // Parse dates
    if (data['date'] is String && (data['date'] as String).isNotEmpty) {
      try { _date = dateFormat.parse(data['date'] as String); } catch (_) {}
    }
    if (data['engineer_date'] is String && (data['engineer_date'] as String).isNotEmpty) {
      try { _engineerDate = dateFormat.parse(data['engineer_date'] as String); } catch (_) {}
    }
    if (data['customer_date'] is String && (data['customer_date'] as String).isNotEmpty) {
      try { _customerDate = dateFormat.parse(data['customer_date'] as String); } catch (_) {}
    }

    // Booleans
    _systemTested = data['system_tested'] == true;
    _drawingsUpdated = data['drawings_updated'] == true;
    _noFalseAlarmPotential = data['no_false_alarm_potential'] == true;
    _thirdPartyInstallation = data['third_party_installation'] == true;
    _subsequentVisitRequired = data['subsequent_visit_required'] == true;

    // Signatures - extract base64 from data URI
    final engSig = data['engineer_signature'] as String? ?? '';
    if (engSig.startsWith('data:image/png;base64,')) {
      _engineerSignatureData = engSig.replaceFirst('data:image/png;base64,', '');
    }
    final custSig = data['customer_signature'] as String? ?? '';
    if (custSig.startsWith('data:image/png;base64,')) {
      _customerSignatureData = custSig.replaceFirst('data:image/png;base64,', '');
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _siteAddressController.dispose();
    _jobNoController.dispose();
    _installersController.dispose();
    _extentOfWorkController.dispose();
    _variationsController.dispose();
    _thirdPartyInstallerController.dispose();
    _subsequentVisitDetailsController.dispose();
    _engineerNameController.dispose();
    _engineerPositionController.dispose();
    _customerCertNameController.dispose();
    _customerPositionController.dispose();
    _systemCategoryController.dispose();
    _engineerSignController.dispose();
    _customerSignController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdaptiveNavigationBar(
        title: _template.name,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: AnimatedSaveButton(
              label: 'Save Draft',
              onPressed: _saveAsDraft,
              outlined: true,
            ),
          ),
          IconButton(
            icon: Icon(AppIcons.eye),
            onPressed: _previewPdf,
            tooltip: 'Preview PDF',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Job Information Section
            _buildSectionHeader('Job Information', AppIcons.infoCircle),
            const SizedBox(height: 16),
            _buildJobInformationSection(),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),

            // Work Details Section
            _buildSectionHeader('Work Details', AppIcons.settingOutline),
            const SizedBox(height: 16),
            _buildWorkDetailsSection(),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),

            // Compliance Checklist Section
            _buildSectionHeader('Compliance Checklist', AppIcons.clipboard),
            const SizedBox(height: 16),
            _buildComplianceSection(),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),

            // Engineer Certification Section
            _buildSectionHeader('Engineer Certification', AppIcons.user),
            const SizedBox(height: 16),
            _buildEngineerCertificationSection(),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),

            // Customer Certification Section
            _buildSectionHeader('Customer Certification', AppIcons.user),
            const SizedBox(height: 16),
            _buildCustomerCertificationSection(),

            const SizedBox(height: 32),

            // Action Buttons
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CustomOutlinedButton(
                  text: 'Preview PDF',
                  icon: AppIcons.eye,
                  onPressed: _previewPdf,
                  isFullWidth: true,
                ),
                const SizedBox(height: 12),
                CustomButton(
                  text: 'Generate & Share',
                  icon: AppIcons.share,
                  onPressed: _generateAndShare,
                  isLoading: _isGenerating,
                  isFullWidth: true,
                ),
              ],
            ),

            const SizedBox(height: 16),
          ],
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

  Widget _buildJobInformationSection() {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Column(
      children: [
        CustomTextField(
          controller: _customerNameController,
          label: 'Customer Name *',
          hint: 'Enter customer name',
          prefixIcon: Icon(AppIcons.building),
          validator: (value) =>
              value?.isEmpty == true ? 'Customer name is required' : null,
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => _selectDate(
            context,
            initialDate: _date,
            onDateSelected: (date) => setState(() {
              _date = date;
              _engineerDate = date;
              _customerDate = date;
            }),
          ),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Date *',
              prefixIcon: Icon(AppIcons.calendar),
              border: OutlineInputBorder(),
            ),
            child: Text(dateFormat.format(_date)),
          ),
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _siteAddressController,
          label: 'Site Address *',
          hint: 'Enter site address',
          maxLines: 2,
          prefixIcon: Icon(AppIcons.location),
          suffixIcon: IconButton(
            icon: Icon(AppIcons.element),
            tooltip: 'Select from saved sites',
            onPressed: _selectFromSavedSites,
          ),
          validator: (value) =>
              value?.isEmpty == true ? 'Site address is required' : null,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: _jobNoController,
                label: 'Job No *',
                hint: 'Enter job number',
                prefixIcon: Icon(AppIcons.tag),
                validator: (value) =>
                    value?.isEmpty == true ? 'Job number is required' : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CustomTextField(
                controller: _installersController,
                label: 'Installer(s)',
                hint: 'Enter installer names',
                prefixIcon: Icon(AppIcons.user),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _systemCategoryController,
          label: 'System Category',
          hint: 'Enter system category',
          prefixIcon: Icon(AppIcons.category),
        ),
      ],
    );
  }

  Widget _buildWorkDetailsSection() {
    return Column(
      children: [
        CustomTextField(
          controller: _extentOfWorkController,
          label: 'Extent of Installation Work *',
          hint: 'Describe the work performed',
          maxLines: 4,
          validator: (value) =>
              value?.isEmpty == true ? 'Work description is required' : null,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _variationsController,
          label: 'Variations from BS 5839-1:2025',
          hint: 'Describe any variations from the standard',
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildComplianceSection() {
    return Column(
      children: [
        CheckboxListTile(
          title: const Text('System tested in accordance with Clause 46.4.2'),
          value: _systemTested,
          onChanged: (v) => setState(() => _systemTested = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        CheckboxListTile(
          title: const Text('As-fitted drawings and documentation updated'),
          value: _drawingsUpdated,
          onChanged: (v) => setState(() => _drawingsUpdated = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        CheckboxListTile(
          title: const Text('No potential source of false alarms identified'),
          value: _noFalseAlarmPotential,
          onChanged: (v) => setState(() => _noFalseAlarmPotential = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        CheckboxListTile(
          title: const Text('Installation works carried out by:'),
          value: _thirdPartyInstallation,
          onChanged: (v) {
            setState(() {
              _thirdPartyInstallation = v ?? false;
              if (_thirdPartyInstallation && _thirdPartyInstallerController.text.isEmpty) {
                _thirdPartyInstallerController.text = 'IQ FIRE SOLUTIONS';
              }
            });
          },
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        if (_thirdPartyInstallation) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: CustomTextField(
              controller: _thirdPartyInstallerController,
              label: 'Third Party Installer Name',
              hint: 'Enter installer company name',
            ),
          ),
        ],
        CheckboxListTile(
          title: const Text('Subsequent visit required'),
          value: _subsequentVisitRequired,
          onChanged: (v) =>
              setState(() => _subsequentVisitRequired = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        if (_subsequentVisitRequired) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: CustomTextField(
              controller: _subsequentVisitDetailsController,
              label: 'Work to be completed',
              hint: 'Describe work for subsequent visit',
              maxLines: 2,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEngineerCertificationSection() {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: _engineerNameController,
                label: 'Name (BLOCK LETTERS) *',
                hint: 'Enter engineer name',
                prefixIcon: Icon(AppIcons.user),
                validator: (value) =>
                    value?.isEmpty == true ? 'Engineer name is required' : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CustomTextField(
                controller: _engineerPositionController,
                label: 'Position *',
                hint: 'Enter position',
                prefixIcon: Icon(AppIcons.clipboard),
                validator: (value) =>
                    value?.isEmpty == true ? 'Position is required' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSignatureWidget(
          label: 'Engineer Signature *',
          controller: _engineerSignController,
          signatureData: _engineerSignatureData,
          onClear: () {
            _engineerSignController.clear();
            setState(() => _engineerSignatureData = null);
          },
          onConfirm: () async {
            if (_engineerSignController.isNotEmpty) {
              final data = await _engineerSignController.toPngBytes();
              if (data != null) {
                setState(() {
                  _engineerSignatureData = base64Encode(data);
                });
              }
            }
          },
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => _selectDate(
            context,
            initialDate: _engineerDate,
            onDateSelected: (date) => setState(() {
              _date = date;
              _engineerDate = date;
              _customerDate = date;
            }),
          ),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Date *',
              prefixIcon: Icon(AppIcons.calendar),
              border: OutlineInputBorder(),
            ),
            child: Text(dateFormat.format(_engineerDate)),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerCertificationSection() {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Column(
      children: [
        _buildSignatureWidget(
          label: 'Customer Signature *',
          controller: _customerSignController,
          signatureData: _customerSignatureData,
          onClear: () {
            _customerSignController.clear();
            setState(() => _customerSignatureData = null);
          },
          onConfirm: () async {
            if (_customerSignController.isNotEmpty) {
              final data = await _customerSignController.toPngBytes();
              if (data != null) {
                setState(() {
                  _customerSignatureData = base64Encode(data);
                });
              }
            }
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: _customerCertNameController,
                label: 'Name *',
                hint: 'Enter customer name',
                prefixIcon: Icon(AppIcons.user),
                validator: (value) =>
                    value?.isEmpty == true ? 'Customer name is required' : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CustomTextField(
                controller: _customerPositionController,
                label: 'Position',
                hint: 'Enter position',
                prefixIcon: Icon(AppIcons.clipboard),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => _selectDate(
            context,
            initialDate: _customerDate,
            onDateSelected: (date) => setState(() {
              _date = date;
              _engineerDate = date;
              _customerDate = date;
            }),
          ),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Date *',
              prefixIcon: Icon(AppIcons.calendar),
              border: OutlineInputBorder(),
            ),
            child: Text(dateFormat.format(_customerDate)),
          ),
        ),
      ],
    );
  }

  Widget _buildSignatureWidget({
    required String label,
    required SignatureController controller,
    required String? signatureData,
    required VoidCallback onClear,
    required VoidCallback onConfirm,
  }) {
    final hasSignature = signatureData != null && signatureData.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            if (hasSignature || controller.isNotEmpty)
              TextButton(onPressed: onClear, child: const Text('Clear')),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 150,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[400]!),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: hasSignature
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    base64Decode(signatureData),
                    fit: BoxFit.contain,
                    width: double.infinity,
                  ),
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
              onPressed: onConfirm,
              icon: Icon(AppIcons.tickCircle),
              label: const Text('Confirm Signature'),
            ),
          ),
      ],
    );
  }

  Future<void> _selectDate(
    BuildContext context, {
    required DateTime initialDate,
    required Function(DateTime) onDateSelected,
  }) async {
    final picked = await showAdaptiveDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      onDateSelected(picked);
    }
  }

  Future<void> _selectFromSavedSites() async {
    final SavedSite? selected = await Navigator.push(
      context,
      adaptivePageRoute(builder: (_) => const SitePickerScreen()),
    );
    if (selected != null) {
      setState(() {
        _siteAddressController.text = selected.address;
      });
    }
  }

  Map<String, dynamic> _collectFieldValues() {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return {
      'customer_name': _customerNameController.text,
      'date': dateFormat.format(_date),
      'site_address': _siteAddressController.text,
      'job_no': _jobNoController.text,
      'installers': _installersController.text,
      'system_category': _systemCategoryController.text,
      'extent_of_work': _extentOfWorkController.text,
      'variations_from_standard': _variationsController.text,
      'system_tested': _systemTested,
      'drawings_updated': _drawingsUpdated,
      'no_false_alarm_potential': _noFalseAlarmPotential,
      'third_party_installation': _thirdPartyInstallation,
      'third_party_installer_name': _thirdPartyInstallerController.text,
      'subsequent_visit_required': _subsequentVisitRequired,
      'subsequent_visit_details': _subsequentVisitDetailsController.text,
      'engineer_name': _engineerNameController.text.toUpperCase(),
      'engineer_position': _engineerPositionController.text,
      'engineer_signature': _engineerSignatureData != null
          ? 'data:image/png;base64,$_engineerSignatureData'
          : '',
      'engineer_date': dateFormat.format(_engineerDate),
      'customer_signature': _customerSignatureData != null
          ? 'data:image/png;base64,$_customerSignatureData'
          : '',
      'customer_cert_name': _customerCertNameController.text,
      'customer_position': _customerPositionController.text,
      'customer_date': dateFormat.format(_customerDate),
    };
  }

  bool _validateForm() {
    if (!_formKey.currentState!.validate()) {
      context.showErrorToast('Please fill in all required fields');
      return false;
    }

    if (_engineerSignatureData == null || _engineerSignatureData!.isEmpty) {
      context.showErrorToast('Please provide engineer signature');
      return false;
    }

    if (_customerSignatureData == null || _customerSignatureData!.isEmpty) {
      context.showErrorToast('Please provide customer signature');
      return false;
    }

    return true;
  }

  Jobsheet _buildJobsheet(JobsheetStatus status) {
    final user = _authService.currentUser;
    final fieldValues = _collectFieldValues();

    return Jobsheet(
      id: _draftId,
      engineerId: user?.uid ?? '',
      engineerName: _engineerNameController.text,
      date: _date,
      customerName: _customerNameController.text,
      siteAddress: _siteAddressController.text,
      jobNumber: _jobNoController.text,
      systemCategory: _systemCategoryController.text,
      templateType: _template.name,
      formData: fieldValues,
      status: status,
      createdAt: widget.existingJobsheet?.createdAt ?? DateTime.now(),
    );
  }

  Future<void> _saveAsDraft() async {
    try {
      final jobsheet = _buildJobsheet(JobsheetStatus.draft);

      if (_isEditingExisting) {
        await _dbHelper.updateJobsheet(jobsheet);
      } else {
        await _dbHelper.insertJobsheet(jobsheet);
        _isEditingExisting = true;
      }

      if (mounted) {
        context.showSuccessToast('Draft saved successfully');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        context.showErrorToast('Error saving draft: $e');
      }
    }
  }

  Future<void> _previewPdf() async {
    if (!_validateForm()) return;

    try {
      final fieldValues = _collectFieldValues();
      final pdfBytes = await TemplatePdfService.generateOverlayPdf(
        template: _template,
        fieldValues: fieldValues,
      );

      await TemplatePdfService.previewPdf(
        pdfBytes,
        'IQ_Modification_Certificate_${_jobNoController.text}.pdf',
      );
    } catch (e) {
      if (mounted) {
        context.showErrorToast('Error generating PDF: $e');
      }
    }
  }

  Future<void> _generateAndShare() async {
    if (!_validateForm()) return;

    setState(() => _isGenerating = true);

    try {
      final fieldValues = _collectFieldValues();
      final pdfBytes = await TemplatePdfService.generateOverlayPdf(
        template: _template,
        fieldValues: fieldValues,
      );

      await TemplatePdfService.sharePdf(
        pdfBytes,
        'IQ_Modification_Certificate_${_jobNoController.text}.pdf',
      );

      // Save as completed to database
      try {
        final jobsheet = _buildJobsheet(JobsheetStatus.completed);
        if (_isEditingExisting) {
          await _dbHelper.updateJobsheet(jobsheet);
        } else {
          await _dbHelper.insertJobsheet(jobsheet);
          _isEditingExisting = true;
        }
      } catch (e) {
        debugPrint('Error saving completed jobsheet: $e');
      }

      if (mounted) {
        context.showSuccessToast('PDF generated and saved successfully');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        context.showErrorToast('Error generating PDF: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }
}
