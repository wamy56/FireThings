import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import '../../models/pdf_form_template.dart';
import '../../models/jobsheet.dart';
import '../../models/saved_site.dart';
import '../saved_sites/site_picker_screen.dart';
import '../../services/analytics_service.dart';
import '../../services/auth_service.dart';
import '../../services/database_helper.dart';
import '../../services/template_pdf_service.dart';
import '../../utils/pdf_form_templates.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import '../common/pdf_preview_screen.dart';
import '../../utils/theme.dart';
import '../../widgets/widgets.dart';

/// Screen for filling the IQ Minor Works & Call Out Certificate PDF form
class MinorWorksFormFillScreen extends StatefulWidget {
  final PdfFormTemplate? template;
  final Jobsheet? existingJobsheet;

  const MinorWorksFormFillScreen({super.key, this.template, this.existingJobsheet});

  @override
  State<MinorWorksFormFillScreen> createState() =>
      _MinorWorksFormFillScreenState();
}

class _MinorWorksFormFillScreenState extends State<MinorWorksFormFillScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  // Text controllers
  final _customerNameController = TextEditingController();
  final _siteAddressController = TextEditingController();
  final _jobNumberController = TextEditingController();
  final _arrivalTimeController = TextEditingController();
  final _departureTimeController = TextEditingController();
  final _otherSystemTypeController = TextEditingController();
  final _descriptionOfWorkController = TextEditingController();
  final _partsUsedController = TextEditingController();
  final _iqRepNameController = TextEditingController();
  final _clientRepNameController = TextEditingController();

  // Date value
  DateTime _date = DateTime.now();

  // Visit type checkboxes
  bool _visitTypeRemedial = false;
  bool _visitTypeCallout = false;

  // System type checkboxes
  bool _systemTypeFireAlarm = false;
  bool _systemTypeEmergencyLighting = false;
  bool _systemTypeAov = false;
  bool _systemTypeOther = false;

  // Client not available
  bool _clientNotAvailable = false;

  // Signature controllers
  late SignatureController _iqRepSignController;
  late SignatureController _clientRepSignController;
  String? _iqRepSignatureData;
  String? _clientRepSignatureData;

  bool _isGenerating = false;


  late PdfFormTemplate _template;
  final _dbHelper = DatabaseHelper.instance;
  late String _draftId;
  bool _isEditingExisting = false;

  @override
  void initState() {
    super.initState();
    _template = widget.template ?? PdfFormTemplates.iqMinorWorksCertificate;
    AnalyticsService.instance.logPdfFormOpened('minor_works');

    _iqRepSignController = SignatureController(
      penStrokeWidth: 2,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );

    _clientRepSignController = SignatureController(
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
      // Pre-fill IQ rep name from user
      final user = _authService.currentUser;
      _iqRepNameController.text =
          user?.displayName ?? user?.email?.split('@')[0] ?? '';
    }
  }

  void _loadFromJobsheet(Jobsheet jobsheet) {
    final data = jobsheet.formData;
    final dateFormat = DateFormat('dd/MM/yyyy');

    _customerNameController.text = data['customer_name'] as String? ?? '';
    _siteAddressController.text = data['site_address'] as String? ?? '';
    _jobNumberController.text = data['job_number'] as String? ?? '';
    _arrivalTimeController.text = data['callout_arrival_time'] as String? ?? '';
    _departureTimeController.text = data['callout_departure_time'] as String? ?? '';
    _otherSystemTypeController.text = data['system_type_other_text'] as String? ?? '';
    _descriptionOfWorkController.text = data['description_of_work'] as String? ?? '';
    _partsUsedController.text = data['parts_used'] as String? ?? '';
    _iqRepNameController.text = data['iq_rep_name'] as String? ?? '';
    _clientRepNameController.text = data['client_rep_name'] as String? ?? '';

    // Parse date
    if (data['date'] is String && (data['date'] as String).isNotEmpty) {
      try { _date = dateFormat.parse(data['date'] as String); } catch (_) {}
    }

    // Booleans
    _visitTypeRemedial = data['visit_type_remedial'] == true;
    _visitTypeCallout = data['visit_type_callout'] == true;
    _systemTypeFireAlarm = data['system_type_fire_alarm'] == true;
    _systemTypeEmergencyLighting = data['system_type_emergency_lighting'] == true;
    _systemTypeAov = data['system_type_aov'] == true;
    _systemTypeOther = data['system_type_other'] == true;
    _clientNotAvailable = data['client_not_available'] == true;

    // Signatures
    final iqSig = data['iq_rep_signature'] as String? ?? '';
    if (iqSig.startsWith('data:image/png;base64,')) {
      _iqRepSignatureData = iqSig.replaceFirst('data:image/png;base64,', '');
    }
    final clientSig = data['client_rep_signature'] as String? ?? '';
    if (clientSig.startsWith('data:image/png;base64,')) {
      _clientRepSignatureData = clientSig.replaceFirst('data:image/png;base64,', '');
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _siteAddressController.dispose();
    _jobNumberController.dispose();
    _arrivalTimeController.dispose();
    _departureTimeController.dispose();
    _otherSystemTypeController.dispose();
    _descriptionOfWorkController.dispose();
    _partsUsedController.dispose();
    _iqRepNameController.dispose();
    _clientRepNameController.dispose();
    _iqRepSignController.dispose();
    _clientRepSignController.dispose();
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
      body: KeyboardDismissWrapper(
        child: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(16),
          children: [
            // Job Information Section
            _buildSectionHeader('Job Information', AppIcons.infoCircle),
            const SizedBox(height: 16),
            _buildJobInformationSection(),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),

            // Visit & System Type Section
            _buildSectionHeader('Visit & System Type', AppIcons.category),
            const SizedBox(height: 16),
            _buildVisitAndSystemTypeSection(),

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

            // IQ Fire Representative Section
            _buildSectionHeader('IQ Fire Representative', AppIcons.user),
            const SizedBox(height: 16),
            _buildIqRepSection(),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),

            // Client Representative Section
            _buildSectionHeader('Client Representative', AppIcons.user),
            const SizedBox(height: 16),
            _buildClientRepSection(),

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
            onDateSelected: (date) => setState(() => _date = date),
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
          controller: _jobNumberController,
          label: 'Job Number *',
          hint: 'Enter job number',
          prefixIcon: Icon(AppIcons.tag),
          validator: (value) =>
              value?.isEmpty == true ? 'Job number is required' : null,
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
                controller: _arrivalTimeController,
                label: 'Call Out Arrival Time',
                hint: 'e.g. 09:30',
                prefixIcon: Icon(AppIcons.clock),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CustomTextField(
                controller: _departureTimeController,
                label: 'Call Out Departure Time',
                hint: 'e.g. 11:45',
                prefixIcon: Icon(AppIcons.clock),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVisitAndSystemTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Visit Type',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        CheckboxListTile(
          title: const Text('Remedial Works'),
          value: _visitTypeRemedial,
          onChanged: (v) => setState(() => _visitTypeRemedial = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        CheckboxListTile(
          title: const Text('Call Out'),
          value: _visitTypeCallout,
          onChanged: (v) => setState(() => _visitTypeCallout = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 16),
        const Text(
          'System Type',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        CheckboxListTile(
          title: const Text('Fire Alarm'),
          value: _systemTypeFireAlarm,
          onChanged: (v) => setState(() => _systemTypeFireAlarm = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        CheckboxListTile(
          title: const Text('Emergency Lighting'),
          value: _systemTypeEmergencyLighting,
          onChanged: (v) =>
              setState(() => _systemTypeEmergencyLighting = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        CheckboxListTile(
          title: const Text('AOV/Smoke Vent'),
          value: _systemTypeAov,
          onChanged: (v) => setState(() => _systemTypeAov = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        CheckboxListTile(
          title: const Text('Other'),
          value: _systemTypeOther,
          onChanged: (v) => setState(() => _systemTypeOther = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        if (_systemTypeOther) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: CustomTextField(
              controller: _otherSystemTypeController,
              label: 'Other System Type',
              hint: 'Specify system type',
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWorkDetailsSection() {
    return Column(
      children: [
        CustomTextField(
          controller: _descriptionOfWorkController,
          label: 'Description of Work Completed *',
          hint: 'Describe the work performed',
          maxLines: 6,
          validator: (value) =>
              value?.isEmpty == true ? 'Work description is required' : null,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _partsUsedController,
          label: 'Parts Used on Call Out',
          hint: 'List parts used',
          maxLines: 4,
        ),
      ],
    );
  }

  Widget _buildIqRepSection() {
    return Column(
      children: [
        CustomTextField(
          controller: _iqRepNameController,
          label: 'Print Name *',
          hint: 'Enter name',
          prefixIcon: Icon(AppIcons.user),
          validator: (value) =>
              value?.isEmpty == true ? 'Name is required' : null,
        ),
        const SizedBox(height: 16),
        _buildSignatureWidget(
          label: 'Signature *',
          controller: _iqRepSignController,
          signatureData: _iqRepSignatureData,
          onClear: () {
            _iqRepSignController.clear();
            setState(() => _iqRepSignatureData = null);
          },
          onConfirm: () async {
            if (_iqRepSignController.isNotEmpty) {
              final data = await _iqRepSignController.toPngBytes();
              if (data != null) {
                setState(() {
                  _iqRepSignatureData = base64Encode(data);
                });
              }
            }
          },
        ),
      ],
    );
  }

  Widget _buildClientRepSection() {
    return Column(
      children: [
        CheckboxListTile(
          title: const Text('Client Not Available'),
          value: _clientNotAvailable,
          onChanged: (v) => setState(() => _clientNotAvailable = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        if (!_clientNotAvailable) ...[
          const SizedBox(height: 16),
          CustomTextField(
            controller: _clientRepNameController,
            label: 'Print Name *',
            hint: 'Enter client name',
            prefixIcon: Icon(AppIcons.user),
            validator: (value) {
              if (_clientNotAvailable) return null;
              return value?.isEmpty == true ? 'Client name is required' : null;
            },
          ),
          const SizedBox(height: 16),
          _buildSignatureWidget(
            label: 'Signature *',
            controller: _clientRepSignController,
            signatureData: _clientRepSignatureData,
            onClear: () {
              _clientRepSignController.clear();
              setState(() => _clientRepSignatureData = null);
            },
            onConfirm: () async {
              if (_clientRepSignController.isNotEmpty) {
                final data = await _clientRepSignController.toPngBytes();
                if (data != null) {
                  setState(() {
                    _clientRepSignatureData = base64Encode(data);
                  });
                }
              }
            },
          ),
        ],
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
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
      'job_number': _jobNumberController.text,
      'site_address': _siteAddressController.text,
      'callout_arrival_time': _arrivalTimeController.text,
      'callout_departure_time': _departureTimeController.text,
      'visit_type_remedial': _visitTypeRemedial,
      'visit_type_callout': _visitTypeCallout,
      'system_type_fire_alarm': _systemTypeFireAlarm,
      'system_type_emergency_lighting': _systemTypeEmergencyLighting,
      'system_type_aov': _systemTypeAov,
      'system_type_other': _systemTypeOther,
      'system_type_other_text': _otherSystemTypeController.text,
      'description_of_work': _descriptionOfWorkController.text,
      'parts_used': _partsUsedController.text,
      'iq_rep_name': _iqRepNameController.text.toUpperCase(),
      'iq_rep_signature': _iqRepSignatureData != null
          ? 'data:image/png;base64,$_iqRepSignatureData'
          : '',
      'client_rep_name': _clientRepNameController.text,
      'client_rep_signature': _clientRepSignatureData != null
          ? 'data:image/png;base64,$_clientRepSignatureData'
          : '',
      'client_not_available': _clientNotAvailable,
    };
  }

  bool _validateForm() {
    if (!_formKey.currentState!.validate()) {
      showValidationBanner(context: context, message: 'Please fill in all required fields');
      return false;
    }

    if (_iqRepSignatureData == null || _iqRepSignatureData!.isEmpty) {
      showValidationBanner(context: context, message: 'Please provide IQ representative signature');
      return false;
    }

    if (!_clientNotAvailable) {
      if (_clientRepSignatureData == null ||
          _clientRepSignatureData!.isEmpty) {
        showValidationBanner(context: context, message: 'Please provide client signature or mark as not available');
        return false;
      }
    }

    return true;
  }

  Jobsheet _buildJobsheet(JobsheetStatus status) {
    final user = _authService.currentUser;
    final fieldValues = _collectFieldValues();

    return Jobsheet(
      id: _draftId,
      engineerId: user?.uid ?? '',
      engineerName: _iqRepNameController.text,
      date: _date,
      customerName: _customerNameController.text,
      siteAddress: _siteAddressController.text,
      jobNumber: _jobNumberController.text,
      systemCategory: '',
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
      AnalyticsService.instance.logPdfFormSavedDraft('minor_works');

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
    AnalyticsService.instance.logPdfFormPreviewed('minor_works');

    try {
      final fieldValues = _collectFieldValues();
      final pdfBytes = await TemplatePdfService.generateOverlayPdf(
        template: _template,
        fieldValues: fieldValues,
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfPreviewScreen(
            pdfBytes: pdfBytes,
            title: 'Minor Works Certificate',
            fileName: 'IQ_Minor_Works_Certificate_${_jobNumberController.text}.pdf',
          ),
        ),
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
        'IQ_Minor_Works_Certificate_${_jobNumberController.text}.pdf',
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
