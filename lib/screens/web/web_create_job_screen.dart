import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/premium_toast.dart';

class WebCreateJobScreen extends StatefulWidget {
  final DispatchedJob? editJob;

  const WebCreateJobScreen({super.key, this.editJob});

  @override
  State<WebCreateJobScreen> createState() => _WebCreateJobScreenState();
}

class _WebCreateJobScreenState extends State<WebCreateJobScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isEdit = false;
  bool _createAnother = false;

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

  // Site ID and coordinates tracking
  String? _selectedSiteId;
  double? _siteLatitude;
  double? _siteLongitude;

  // Autocomplete
  List<CompanySite> _companySites = [];
  List<CompanyCustomer> _companyCustomers = [];
  StreamSubscription? _sitesSubscription;
  StreamSubscription? _customersSubscription;

  @override
  void initState() {
    super.initState();
    _loadMembers();
    _loadSharedData();
    if (widget.editJob != null) {
      if (widget.editJob!.id.isNotEmpty) {
        _isEdit = true;
      }
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
    _numberOfZonesController.text = job.numberOfZones?.toString() ?? '';
    _scheduledTimeController.text = job.scheduledTime ?? '';
    _estimatedDurationController.text = job.estimatedDuration ?? '';
    _scheduledDate = job.scheduledDate;
    _priority = job.priority;
    _assignedToUid = job.assignedTo;
    _assignedToName = job.assignedToName;
    _selectedSiteId = job.companySiteId;
    _siteLatitude = job.latitude;
    _siteLongitude = job.longitude;
  }

  Future<void> _loadMembers() async {
    final companyId = UserProfileService.instance.companyId;
    if (companyId == null) return;
    final members = await CompanyService.instance.getCompanyMembers(companyId);
    if (mounted) setState(() => _members = members);
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
        latitude: _siteLatitude,
        longitude: _siteLongitude,
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
        AnalyticsService.instance.logWebJobEdited();
      } else {
        await DispatchService.instance.createJob(job);
        AnalyticsService.instance.logDispatchJobCreated(
          companyId,
          job.jobType,
          job.assignedTo != null,
        );
        AnalyticsService.instance.logWebJobCreated();
      }

      if (mounted) {
        if (!_isEdit && _createAnother) {
          context.showSuccessToast('Job created — ready for next job');
          setState(() {
            _isLoading = false;
            _titleController.clear();
            _descriptionController.clear();
            _jobNumberController.clear();
            _jobTypeController.clear();
            _scheduledDate = null;
            _scheduledTimeController.clear();
            _estimatedDurationController.clear();
            _assignedToUid = null;
            _assignedToName = null;
            _priority = JobPriority.normal;
            // Keep site + contact pre-filled for batch creation
          });
        } else {
          context.showSuccessToast(_isEdit ? 'Job updated' : 'Job created');
          Navigator.of(context).pop(true);
        }
      }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
          if (!_isLoading) _saveJob();
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppTheme.darkDivider : AppTheme.dividerColor,
                ),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(AppIcons.arrowLeft),
                  tooltip: 'Back',
                ),
                const SizedBox(width: 8),
                Text(
                  _isEdit ? 'Edit Job' : 'Create New Job',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveJob,
                  child: Text(_isEdit ? 'Update Job' : 'Create Job'),
                ),
              ],
            ),
          ),

          // Form body — two columns
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left column
                            Expanded(child: _buildLeftColumn(isDark)),
                            const SizedBox(width: 32),
                            // Right column
                            Expanded(child: _buildRightColumn(isDark)),
                          ],
                        ),
                        if (!_isEdit) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Checkbox(
                                value: _createAnother,
                                onChanged: (v) => setState(() => _createAnother = v ?? false),
                              ),
                              GestureDetector(
                                onTap: () => setState(() => _createAnother = !_createAnother),
                                child: const Text('Create another job after saving (keeps site & contact)'),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: OutlinedButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: SizedBox(
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
                                      ? const SizedBox(
                                          width: 20, height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : Text(
                                          _isEdit ? 'Update Job' : 'Create Job',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
      ),
    );
  }

  Widget _buildLeftColumn(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionCard(
          title: 'Job Details',
          isDark: isDark,
          children: [
            CustomTextField(
              controller: _titleController,
              label: 'Job Title',
              hint: 'e.g. Annual Inspection',
              prefixIcon: Icon(AppIcons.clipboard),
              validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _jobTypeController,
              label: 'Job Type',
              hint: 'e.g. Inspection, Fault Call Out, Installation',
              prefixIcon: Icon(AppIcons.category),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _jobNumberController,
              label: 'Job Number',
              hint: 'Reference number (optional)',
              prefixIcon: Icon(AppIcons.tag),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _descriptionController,
              label: 'Description',
              hint: 'Detailed notes about the job',
              prefixIcon: Icon(AppIcons.note),
              maxLines: 3,
            ),
          ],
        ),
        const SizedBox(height: 20),

        _sectionCard(
          title: 'Priority',
          isDark: isDark,
          children: [
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<JobPriority>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: JobPriority.normal, label: Text('Normal')),
                  ButtonSegment(value: JobPriority.urgent, label: Text('Urgent')),
                  ButtonSegment(value: JobPriority.emergency, label: Text('Emergency')),
                ],
                selected: {_priority},
                onSelectionChanged: (s) => setState(() => _priority = s.first),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        _sectionCard(
          title: 'System Info',
          isDark: isDark,
          children: [
            CustomTextField(
              controller: _systemCategoryController,
              label: 'System Category',
              hint: 'e.g. L1, L2, M, P1',
              prefixIcon: Icon(AppIcons.category),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _panelMakeController,
              label: 'Panel Make',
              hint: 'e.g. Advanced, Kentec',
              prefixIcon: Icon(AppIcons.element),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _panelLocationController,
              label: 'Panel Location',
              hint: 'Where is the panel?',
              prefixIcon: Icon(AppIcons.location),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _numberOfZonesController,
              label: 'Number of Zones',
              prefixIcon: Icon(AppIcons.grid),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        const SizedBox(height: 20),

        _sectionCard(
          title: 'Assign To',
          isDark: isDark,
          children: [
            DropdownButtonFormField<String?>(
              initialValue: _assignedToUid,
              decoration: InputDecoration(
                prefixIcon: Icon(AppIcons.user),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              hint: const Text('Unassigned'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Unassigned')),
                ..._members.map((m) => DropdownMenuItem(
                  value: m.uid,
                  child: Text('${m.displayName} (${m.role.name})'),
                )),
              ],
              onChanged: (value) {
                final member = _members.where((m) => m.uid == value).firstOrNull;
                setState(() {
                  _assignedToUid = value;
                  _assignedToName = member?.displayName;
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRightColumn(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionCard(
          title: 'Site',
          isDark: isDark,
          children: [
            _buildSiteAutocomplete(),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _siteAddressController,
              label: 'Site Address',
              hint: 'Full address',
              prefixIcon: Icon(AppIcons.location),
              maxLines: 2,
              validator: (v) => v == null || v.trim().isEmpty ? 'Address is required' : null,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _parkingNotesController,
              label: 'Parking Notes',
              hint: 'e.g. Park in rear car park, code 1234',
              prefixIcon: Icon(AppIcons.routing),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _accessNotesController,
              label: 'Access Notes',
              hint: 'e.g. Report to reception, ask for John',
              prefixIcon: Icon(AppIcons.key),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _siteNotesController,
              label: 'Site Notes',
              hint: 'Any other site information',
              prefixIcon: Icon(AppIcons.note),
              maxLines: 2,
            ),
          ],
        ),
        const SizedBox(height: 20),

        _sectionCard(
          title: 'Contact',
          isDark: isDark,
          children: [
            _buildCustomerAutocomplete(),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _contactPhoneController,
              label: 'Contact Phone',
              prefixIcon: Icon(AppIcons.call),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _contactEmailController,
              label: 'Contact Email',
              prefixIcon: Icon(AppIcons.sms),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        const SizedBox(height: 20),

        _sectionCard(
          title: 'Scheduling',
          isDark: isDark,
          children: [
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Scheduled Date',
                  prefixIcon: Icon(AppIcons.calendar),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  _scheduledDate != null
                      ? '${_scheduledDate!.day}/${_scheduledDate!.month}/${_scheduledDate!.year}'
                      : 'Select date',
                  style: TextStyle(
                    color: _scheduledDate != null ? null : AppTheme.mediumGrey,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _scheduledTimeController,
              label: 'Time',
              hint: 'e.g. 09:00 or Morning',
              prefixIcon: Icon(AppIcons.clock),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _estimatedDurationController,
              label: 'Estimated Duration',
              hint: 'e.g. 2 hours, Half day',
              prefixIcon: Icon(AppIcons.timer),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSiteAutocomplete() {
    return Autocomplete<CompanySite>(
      displayStringForOption: (site) => site.name,
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.toLowerCase();
        if (query.isEmpty) return const Iterable.empty();
        return _companySites.where((s) => s.name.toLowerCase().contains(query));
      },
      onSelected: (site) {
        _siteNameController.text = site.name;
        _siteAddressController.text = site.address;
        _selectedSiteId = site.id;
        _siteLatitude = site.latitude;
        _siteLongitude = site.longitude;
        if (site.notes != null && site.notes!.isNotEmpty) {
          _siteNotesController.text = site.notes!;
        }
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        if (controller.text.isEmpty && _siteNameController.text.isNotEmpty) {
          controller.text = _siteNameController.text;
        }
        controller.addListener(() {
          _siteNameController.text = controller.text;
          // Clear site ID if user manually edits away from autocomplete match
          if (_selectedSiteId != null) {
            final matchesSite = _companySites.any((s) => s.name == controller.text);
            if (!matchesSite) {
              _selectedSiteId = null;
              _siteLatitude = null;
              _siteLongitude = null;
            }
          }
        });
        return CustomTextField(
          controller: controller,
          focusNode: focusNode,
          label: 'Site Name',
          hint: 'e.g. Hilton Hotel Manchester',
          prefixIcon: Icon(AppIcons.building),
          validator: (v) => v == null || v.trim().isEmpty ? 'Site name is required' : null,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 400),
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
                    subtitle: Text(site.address, maxLines: 1, overflow: TextOverflow.ellipsis),
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

  Widget _buildCustomerAutocomplete() {
    return Autocomplete<CompanyCustomer>(
      displayStringForOption: (customer) => customer.name,
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.toLowerCase();
        if (query.isEmpty) return const Iterable.empty();
        return _companyCustomers.where((c) => c.name.toLowerCase().contains(query));
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
        if (controller.text.isEmpty && _contactNameController.text.isNotEmpty) {
          controller.text = _contactNameController.text;
        }
        controller.addListener(() => _contactNameController.text = controller.text);
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
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 400),
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
                    subtitle: customer.phone != null ? Text(customer.phone!) : null,
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

  Widget _sectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required bool isDark,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? AppTheme.darkDivider : Colors.grey.shade300,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(title, isDark),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
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
    if (picked != null) setState(() => _scheduledDate = picked);
  }
}
