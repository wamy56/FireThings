import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../../models/dispatched_job.dart';
import '../../models/company_member.dart';
import '../../services/dispatch_service.dart';
import '../../services/company_service.dart';
import '../../services/user_profile_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/premium_toast.dart';

class CreateJobScreen extends StatefulWidget {
  final DispatchedJob? editJob;

  const CreateJobScreen({super.key, this.editJob});

  @override
  State<CreateJobScreen> createState() => _CreateJobScreenState();
}

class _CreateJobScreenState extends State<CreateJobScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isEdit = false;

  // Job details
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _jobNumberController = TextEditingController();
  final _jobTypeController = TextEditingController();

  // Site
  final _siteNameController = TextEditingController();
  final _siteAddressController = TextEditingController();
  final _parkingNotesController = TextEditingController();
  final _accessNotesController = TextEditingController();
  final _siteNotesController = TextEditingController();

  // Contact
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _contactEmailController = TextEditingController();

  // System
  final _systemCategoryController = TextEditingController();
  final _panelMakeController = TextEditingController();
  final _panelLocationController = TextEditingController();
  final _numberOfZonesController = TextEditingController();

  // Scheduling
  final _scheduledTimeController = TextEditingController();
  final _estimatedDurationController = TextEditingController();
  DateTime? _scheduledDate;

  // Assignment
  JobPriority _priority = JobPriority.normal;
  String? _assignedToUid;
  String? _assignedToName;
  List<CompanyMember> _members = [];

  @override
  void initState() {
    super.initState();
    _loadMembers();

    if (widget.editJob != null) {
      _isEdit = true;
      _populateFromJob(widget.editJob!);
    }
  }

  void _populateFromJob(DispatchedJob job) {
    _titleController.text = job.title;
    _descriptionController.text = job.description ?? '';
    _jobNumberController.text = job.jobNumber ?? '';
    _jobTypeController.text = job.jobType ?? '';
    _siteNameController.text = job.siteName;
    _siteAddressController.text = job.siteAddress;
    _parkingNotesController.text = job.parkingNotes ?? '';
    _accessNotesController.text = job.accessNotes ?? '';
    _siteNotesController.text = job.siteNotes ?? '';
    _contactNameController.text = job.contactName ?? '';
    _contactPhoneController.text = job.contactPhone ?? '';
    _contactEmailController.text = job.contactEmail ?? '';
    _systemCategoryController.text = job.systemCategory ?? '';
    _panelMakeController.text = job.panelMake ?? '';
    _panelLocationController.text = job.panelLocation ?? '';
    _numberOfZonesController.text =
        job.numberOfZones?.toString() ?? '';
    _scheduledTimeController.text = job.scheduledTime ?? '';
    _estimatedDurationController.text = job.estimatedDuration ?? '';
    _scheduledDate = job.scheduledDate;
    _priority = job.priority;
    _assignedToUid = job.assignedTo;
    _assignedToName = job.assignedToName;
  }

  Future<void> _loadMembers() async {
    final companyId = UserProfileService.instance.companyId;
    if (companyId == null) return;

    final members =
        await CompanyService.instance.getCompanyMembers(companyId);
    if (mounted) {
      setState(() => _members = members);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _jobNumberController.dispose();
    _jobTypeController.dispose();
    _siteNameController.dispose();
    _siteAddressController.dispose();
    _parkingNotesController.dispose();
    _accessNotesController.dispose();
    _siteNotesController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _contactEmailController.dispose();
    _systemCategoryController.dispose();
    _panelMakeController.dispose();
    _panelLocationController.dispose();
    _numberOfZonesController.dispose();
    _scheduledTimeController.dispose();
    _estimatedDurationController.dispose();
    super.dispose();
  }

  Future<void> _saveJob() async {
    if (!_formKey.currentState!.validate()) return;

    final companyId = UserProfileService.instance.companyId;
    final user = FirebaseAuth.instance.currentUser;
    if (companyId == null || user == null) return;

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final zonesText = _numberOfZonesController.text.trim();

      final job = DispatchedJob(
        id: _isEdit ? widget.editJob!.id : const Uuid().v4(),
        companyId: companyId,
        title: _titleController.text.trim(),
        description: _nullIfEmpty(_descriptionController.text),
        jobNumber: _nullIfEmpty(_jobNumberController.text),
        jobType: _nullIfEmpty(_jobTypeController.text),
        siteName: _siteNameController.text.trim(),
        siteAddress: _siteAddressController.text.trim(),
        parkingNotes: _nullIfEmpty(_parkingNotesController.text),
        accessNotes: _nullIfEmpty(_accessNotesController.text),
        siteNotes: _nullIfEmpty(_siteNotesController.text),
        contactName: _nullIfEmpty(_contactNameController.text),
        contactPhone: _nullIfEmpty(_contactPhoneController.text),
        contactEmail: _nullIfEmpty(_contactEmailController.text),
        assignedTo: _assignedToUid,
        assignedToName: _assignedToName,
        createdBy: _isEdit ? widget.editJob!.createdBy : user.uid,
        createdByName: _isEdit
            ? widget.editJob!.createdByName
            : (user.displayName ?? 'Unknown'),
        scheduledDate: _scheduledDate,
        scheduledTime: _nullIfEmpty(_scheduledTimeController.text),
        estimatedDuration: _nullIfEmpty(_estimatedDurationController.text),
        status: _isEdit
            ? widget.editJob!.status
            : (_assignedToUid != null
                ? DispatchedJobStatus.assigned
                : DispatchedJobStatus.created),
        createdAt: _isEdit ? widget.editJob!.createdAt : now,
        updatedAt: now,
        priority: _priority,
        systemCategory: _nullIfEmpty(_systemCategoryController.text),
        panelMake: _nullIfEmpty(_panelMakeController.text),
        panelLocation: _nullIfEmpty(_panelLocationController.text),
        numberOfZones: zonesText.isNotEmpty ? int.tryParse(zonesText) : null,
      );

      if (_isEdit) {
        await DispatchService.instance.updateJob(job);
      } else {
        await DispatchService.instance.createJob(job);
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        context.showErrorToast('Failed to save job: $e');
      }
    }
  }

  String? _nullIfEmpty(String text) {
    final trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Job' : 'Create Job'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveJob,
            child: _isLoading
                ? const AdaptiveLoadingIndicator(size: 16)
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          children: [
            _sectionHeader('Job Details'),
            const SizedBox(height: 8),
            CustomTextField(
              controller: _titleController,
              label: 'Job Title',
              hint: 'e.g. Annual Inspection',
              prefixIcon: Icon(AppIcons.clipboard),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Title is required' : null,
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _jobTypeController,
              label: 'Job Type',
              hint: 'e.g. Inspection, Fault Call Out, Installation',
              prefixIcon: Icon(AppIcons.category),
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _jobNumberController,
              label: 'Job Number',
              hint: 'Reference number (optional)',
              prefixIcon: Icon(AppIcons.tag),
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _descriptionController,
              label: 'Description',
              hint: 'Detailed notes about the job',
              prefixIcon: Icon(AppIcons.note),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            _sectionHeader('Priority'),
            const SizedBox(height: 8),
            SegmentedButton<JobPriority>(
              segments: const [
                ButtonSegment(
                  value: JobPriority.normal,
                  label: Text('Normal'),
                ),
                ButtonSegment(
                  value: JobPriority.urgent,
                  label: Text('Urgent'),
                ),
                ButtonSegment(
                  value: JobPriority.emergency,
                  label: Text('Emergency'),
                ),
              ],
              selected: {_priority},
              onSelectionChanged: (selected) {
                setState(() => _priority = selected.first);
              },
            ),
            const SizedBox(height: 24),

            _sectionHeader('Site'),
            const SizedBox(height: 8),
            CustomTextField(
              controller: _siteNameController,
              label: 'Site Name',
              hint: 'e.g. Hilton Hotel Manchester',
              prefixIcon: Icon(AppIcons.building),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Site name is required'
                  : null,
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _siteAddressController,
              label: 'Site Address',
              hint: 'Full address',
              prefixIcon: Icon(AppIcons.location),
              maxLines: 2,
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Address is required'
                  : null,
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _parkingNotesController,
              label: 'Parking Notes',
              hint: 'e.g. Park in rear car park, code 1234',
              prefixIcon: Icon(AppIcons.routing),
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _accessNotesController,
              label: 'Access Notes',
              hint: 'e.g. Report to reception, ask for John',
              prefixIcon: Icon(AppIcons.key),
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _siteNotesController,
              label: 'Site Notes',
              hint: 'Any other site information',
              prefixIcon: Icon(AppIcons.note),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            _sectionHeader('Contact'),
            const SizedBox(height: 8),
            CustomTextField(
              controller: _contactNameController,
              label: 'Contact Name',
              prefixIcon: Icon(AppIcons.user),
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _contactPhoneController,
              label: 'Contact Phone',
              prefixIcon: Icon(AppIcons.call),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _contactEmailController,
              label: 'Contact Email',
              prefixIcon: Icon(AppIcons.sms),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 24),

            _sectionHeader('Scheduling'),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(AppIcons.calendar),
              title: Text(
                _scheduledDate != null
                    ? '${_scheduledDate!.day}/${_scheduledDate!.month}/${_scheduledDate!.year}'
                    : 'Select Date',
              ),
              trailing: Icon(AppIcons.arrowRight),
              onTap: _pickDate,
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _scheduledTimeController,
              label: 'Time',
              hint: 'e.g. 09:00 or Morning',
              prefixIcon: Icon(AppIcons.clock),
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _estimatedDurationController,
              label: 'Estimated Duration',
              hint: 'e.g. 2 hours, Half day',
              prefixIcon: Icon(AppIcons.timer),
            ),
            const SizedBox(height: 24),

            _sectionHeader('Assign To'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              initialValue: _assignedToUid,
              decoration: InputDecoration(
                prefixIcon: Icon(AppIcons.user),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              hint: const Text('Unassigned'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Unassigned'),
                ),
                ..._members.map((m) => DropdownMenuItem(
                      value: m.uid,
                      child: Text('${m.displayName} (${m.role.name})'),
                    )),
              ],
              onChanged: (value) {
                final member = _members
                    .where((m) => m.uid == value)
                    .firstOrNull;
                setState(() {
                  _assignedToUid = value;
                  _assignedToName = member?.displayName;
                });
              },
            ),
            const SizedBox(height: 24),

            _sectionHeader('System Info'),
            const SizedBox(height: 8),
            CustomTextField(
              controller: _systemCategoryController,
              label: 'System Category',
              hint: 'e.g. L1, L2, M, P1',
              prefixIcon: Icon(AppIcons.category),
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _panelMakeController,
              label: 'Panel Make',
              hint: 'e.g. Advanced, Kentec',
              prefixIcon: Icon(AppIcons.element),
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _panelLocationController,
              label: 'Panel Location',
              hint: 'Where is the panel?',
              prefixIcon: Icon(AppIcons.location),
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _numberOfZonesController,
              label: 'Number of Zones',
              prefixIcon: Icon(AppIcons.grid),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: isDark ? AppTheme.darkTextSecondary : Colors.grey,
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _scheduledDate = picked);
    }
  }
}
