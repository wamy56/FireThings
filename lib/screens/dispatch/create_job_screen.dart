import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../../models/dispatched_job.dart';
import '../../models/company_member.dart';
import '../../models/company_site.dart';
import '../../models/company_customer.dart';
import '../../services/dispatch_service.dart';
import '../../services/company_service.dart';
import '../../services/user_profile_service.dart';
import '../../services/analytics_service.dart';
import '../../services/asset_service.dart';
import '../../services/remote_config_service.dart';
import '../../services/bs5839_config_service.dart';
import '../../services/inspection_visit_service.dart';
import '../../models/asset.dart';
import '../../models/bs5839_system_config.dart';
import '../../models/bs5839_variation.dart';
import '../../models/inspection_visit.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/keyboard_dismiss_wrapper.dart';
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

  // Autocomplete data
  List<CompanySite> _companySites = [];
  List<CompanyCustomer> _companyCustomers = [];
  String? _selectedSiteId;
  StreamSubscription? _sitesSubscription;
  StreamSubscription? _customersSubscription;

  @override
  void initState() {
    super.initState();
    _loadMembers();
    _loadSharedData();

    if (widget.editJob != null) {
      _isEdit = true;
      _populateFromJob(widget.editJob!);
    }
  }

  void _loadSharedData() {
    final companyId = UserProfileService.instance.companyId;
    if (companyId == null) return;

    _sitesSubscription = CompanyService.instance
        .getSitesStream(companyId)
        .listen((sites) {
      if (mounted) setState(() => _companySites = sites);
    });

    _customersSubscription = CompanyService.instance
        .getCustomersStream(companyId)
        .listen((customers) {
      if (mounted) setState(() => _companyCustomers = customers);
    });
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
    _selectedSiteId = job.companySiteId;
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
    _sitesSubscription?.cancel();
    _customersSubscription?.cancel();
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
        companySiteId: _selectedSiteId,
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
        AnalyticsService.instance.logDispatchJobCreated(
          companyId,
          job.jobType,
          job.assignedTo != null,
        );
        if (job.assignedTo != null) {
          AnalyticsService.instance.logDispatchJobAssigned(
            companyId,
            job.jobType,
          );
        }
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
      ),
      body: KeyboardDismissWrapper(
        child: Form(
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
              segments: [
                ButtonSegment(
                  value: JobPriority.normal,
                  label: FittedBox(fit: BoxFit.scaleDown, child: Text('Normal')),
                ),
                ButtonSegment(
                  value: JobPriority.urgent,
                  label: FittedBox(fit: BoxFit.scaleDown, child: Text('Urgent')),
                ),
                ButtonSegment(
                  value: JobPriority.emergency,
                  label: FittedBox(fit: BoxFit.scaleDown, child: Text('Emergency')),
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
            _buildSiteAutocomplete(),
            if (_selectedSiteId != null &&
                RemoteConfigService.instance.assetRegisterEnabled) ...[
              const SizedBox(height: 8),
              _buildComplianceSummary(),
            ],
            if (_selectedSiteId != null &&
                RemoteConfigService.instance.bs5839ModeEnabled) ...[
              const SizedBox(height: 8),
              _buildBs5839Summary(),
            ],
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
            _buildCustomerAutocomplete(),
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
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveJob,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const AdaptiveLoadingIndicator(size: 20, color: Colors.white)
                    : Text(
                        _isEdit ? 'Update Job' : 'Create Job',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildSiteAutocomplete() {
    return Autocomplete<CompanySite>(
      displayStringForOption: (site) => site.name,
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.toLowerCase();
        if (query.isEmpty) return const Iterable.empty();
        return _companySites.where(
            (s) => s.name.toLowerCase().contains(query));
      },
      onSelected: (site) {
        setState(() {
          _siteNameController.text = site.name;
          _siteAddressController.text = site.address;
          if (site.notes != null && site.notes!.isNotEmpty) {
            _siteNotesController.text = site.notes!;
          }
          _selectedSiteId = site.id;
        });
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        // Sync with our own controller
        if (controller.text.isEmpty && _siteNameController.text.isNotEmpty) {
          controller.text = _siteNameController.text;
        }
        controller.addListener(() {
          _siteNameController.text = controller.text;
          // Clear site ID if user manually edits the field
          if (_selectedSiteId != null) {
            final matchesSite = _companySites.any(
                (s) => s.id == _selectedSiteId && s.name == controller.text);
            if (!matchesSite) {
              setState(() => _selectedSiteId = null);
            }
          }
        });
        return CustomTextField(
          controller: controller,
          focusNode: focusNode,
          label: 'Site Name',
          hint: 'e.g. Hilton Hotel Manchester',
          prefixIcon: Icon(AppIcons.building),
          validator: (v) => v == null || v.trim().isEmpty
              ? 'Site name is required'
              : null,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final site = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    leading: Icon(AppIcons.building, size: 18),
                    title: Text(site.name),
                    subtitle: Text(
                      site.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => onSelected(site),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildComplianceSummary() {
    final companyId = UserProfileService.instance.companyId;
    if (companyId == null || _selectedSiteId == null) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final basePath = 'companies/$companyId';

    return FutureBuilder<List<Asset>>(
      future: AssetService.instance
          .getAssetsStream(basePath, _selectedSiteId!)
          .first,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: LinearProgressIndicator(
              backgroundColor: isDark ? AppTheme.darkSurfaceElevated : Colors.grey[200],
            ),
          );
        }

        final assets = snapshot.data ?? [];
        if (assets.isEmpty) return const SizedBox.shrink();

        final active = assets.where((a) => a.complianceStatus != AssetComplianceStatus.decommissioned).toList();
        final pass = active.where((a) => a.complianceStatus == AssetComplianceStatus.pass).length;
        final fail = active.where((a) => a.complianceStatus == AssetComplianceStatus.fail).length;
        final untested = active.where((a) => a.complianceStatus == AssetComplianceStatus.untested).length;
        final hasWarning = fail > 0 || untested > 0;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: hasWarning
                ? (fail > 0
                    ? AppTheme.errorRed.withValues(alpha: 0.08)
                    : AppTheme.accentOrange.withValues(alpha: 0.08))
                : AppTheme.successGreen.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasWarning
                  ? (fail > 0
                      ? AppTheme.errorRed.withValues(alpha: 0.3)
                      : AppTheme.accentOrange.withValues(alpha: 0.3))
                  : AppTheme.successGreen.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                AppIcons.clipboard,
                size: 18,
                color: hasWarning
                    ? (fail > 0 ? AppTheme.errorRed : AppTheme.accentOrange)
                    : AppTheme.successGreen,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 13),
                    children: [
                      TextSpan(
                        text: '${active.length} assets: ',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(
                        text: '$pass pass',
                        style: TextStyle(color: AppTheme.successGreen, fontWeight: FontWeight.w600),
                      ),
                      if (fail > 0) ...[
                        const TextSpan(text: ', '),
                        TextSpan(
                          text: '$fail fail',
                          style: TextStyle(color: AppTheme.errorRed, fontWeight: FontWeight.w600),
                        ),
                      ],
                      if (untested > 0) ...[
                        const TextSpan(text: ', '),
                        TextSpan(
                          text: '$untested untested',
                          style: TextStyle(color: AppTheme.accentOrange, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBs5839Summary() {
    final companyId = UserProfileService.instance.companyId;
    if (companyId == null || _selectedSiteId == null) {
      return const SizedBox.shrink();
    }

    final basePath = 'companies/$companyId';
    final siteId = _selectedSiteId!;

    return FutureBuilder<Bs5839SystemConfig?>(
      future: Bs5839ConfigService.instance.getConfig(basePath, siteId),
      builder: (context, configSnap) {
        if (configSnap.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final config = configSnap.data;
        if (config == null) return const SizedBox.shrink();

        return FutureBuilder<List<dynamic>>(
          future: Future.wait([
            InspectionVisitService.instance.getLastVisit(basePath, siteId),
            Bs5839ConfigService.instance
                .getActiveVariations(basePath, siteId)
                .first,
          ]),
          builder: (context, snap) {
            final lastVisit = snap.data?[0] as InspectionVisit?;
            final variations =
                (snap.data?[1] as List?)?.cast<Bs5839Variation>() ?? [];
            final prohibitedCount =
                variations.where((v) => v.isProhibited).length;

            final declaration = lastVisit?.declaration;
            final isUnsatisfactory =
                declaration == InspectionDeclaration.unsatisfactory;
            final hasProhibited = prohibitedCount > 0;
            final hasWarning = isUnsatisfactory || hasProhibited;

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasWarning
                    ? AppTheme.errorRed.withValues(alpha: 0.08)
                    : AppTheme.primaryBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasWarning
                      ? AppTheme.errorRed.withValues(alpha: 0.3)
                      : AppTheme.primaryBlue.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(AppIcons.shield, size: 18,
                          color: hasWarning
                              ? AppTheme.errorRed
                              : AppTheme.primaryBlue),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          config.category.displayLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'BS 5839-1:2025',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (hasProhibited)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.errorRed,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$prohibitedCount prohibited',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (lastVisit != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Last: ${declaration?.displayLabel ?? 'Not declared'}'
                      '${lastVisit.nextServiceDueDate != null ? ' · Next service: ${_formatDate(lastVisit.nextServiceDueDate!)}' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isUnsatisfactory
                            ? AppTheme.errorRed
                            : Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.color,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildCustomerAutocomplete() {
    return Autocomplete<CompanyCustomer>(
      displayStringForOption: (customer) => customer.name,
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.toLowerCase();
        if (query.isEmpty) return const Iterable.empty();
        return _companyCustomers.where(
            (c) => c.name.toLowerCase().contains(query));
      },
      onSelected: (customer) {
        _contactNameController.text = customer.name;
        if (customer.phone != null && customer.phone!.isNotEmpty) {
          _contactPhoneController.text = customer.phone!;
        }
        if (customer.email != null && customer.email!.isNotEmpty) {
          _contactEmailController.text = customer.email!;
        }
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        if (controller.text.isEmpty &&
            _contactNameController.text.isNotEmpty) {
          controller.text = _contactNameController.text;
        }
        controller.addListener(() {
          _contactNameController.text = controller.text;
        });
        return CustomTextField(
          controller: controller,
          focusNode: focusNode,
          label: 'Contact Name',
          prefixIcon: Icon(AppIcons.user),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final customer = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    leading: Icon(AppIcons.user, size: 18),
                    title: Text(customer.name),
                    subtitle: customer.phone != null
                        ? Text(customer.phone!)
                        : null,
                    onTap: () => onSelected(customer),
                  );
                },
              ),
            ),
          ),
        );
      },
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
