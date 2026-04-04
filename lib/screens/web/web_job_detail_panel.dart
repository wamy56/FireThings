import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/dispatched_job.dart';
import '../../models/jobsheet.dart';
import '../../services/dispatch_service.dart';
import '../../services/company_service.dart';
import '../../services/pdf_service.dart' show PDFService;
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/premium_toast.dart';
import '../../widgets/site_map_preview.dart';
import '../../services/analytics_service.dart';
import '../../utils/print_stub.dart' if (dart.library.html) '../../utils/print_web.dart';
import '../../utils/download_stub.dart' if (dart.library.html) '../../utils/download_web.dart';
import 'cancel_job_dialog.dart';
import '../../models/asset.dart';
import '../../services/asset_service.dart';
import '../../services/remote_config_service.dart';
import 'package:go_router/go_router.dart';

class WebJobDetailPanel extends StatefulWidget {
  final String companyId;
  final String jobId;
  final VoidCallback onClose;
  final void Function(DispatchedJob job) onEdit;
  final bool animateIn;

  const WebJobDetailPanel({
    super.key,
    required this.companyId,
    required this.jobId,
    required this.onClose,
    required this.onEdit,
    this.animateIn = true,
  });

  @override
  State<WebJobDetailPanel> createState() => _WebJobDetailPanelState();
}

class _WebJobDetailPanelState extends State<WebJobDetailPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: AppTheme.normalAnimation,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: AppTheme.defaultCurve,
    ));
    if (widget.animateIn) {
      _slideController.forward();
    } else {
      _slideController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _closePanel() async {
    _slideController.reverse();
    widget.onClose();
  }

  Future<void> _openDirections(String address) async {
    final encodedAddress = Uri.encodeComponent(address);
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$encodedAddress',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SlideTransition(
      position: _slideAnimation,
      child: Material(
        elevation: 8,
        color: isDark ? AppTheme.darkSurface : Colors.white,
        child: StreamBuilder<DispatchedJob?>(
          stream: DispatchService.instance.getJobStream(widget.companyId, widget.jobId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: AdaptiveLoadingIndicator());
            }

            final job = snapshot.data;
            if (job == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(AppIcons.warning, size: 32, color: AppTheme.mediumGrey),
                    const SizedBox(height: 8),
                    const Text('Job not found'),
                    const SizedBox(height: 16),
                    TextButton(onPressed: _closePanel, child: const Text('Close')),
                  ],
                ),
              );
            }

            return Column(
              children: [
                _buildPanelHeader(job, isDark),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildStatusTimeline(job, isDark),
                      const SizedBox(height: 20),
                      _buildSection('Job Details', [
                        _detailRow('Title', job.title, isDark),
                        if (job.jobType != null) _detailRow('Type', job.jobType!, isDark),
                        if (job.jobNumber != null) _detailRow('Job #', job.jobNumber!, isDark),
                        if (job.description != null) _detailRow('Description', job.description!, isDark),
                        _detailRow('Priority', _priorityLabel(job.priority), isDark),
                      ], isDark),
                      const SizedBox(height: 16),
                      _buildSection('Site', [
                        _detailRow('Name', job.siteName, isDark),
                        _detailRow('Address', job.siteAddress, isDark),
                        if (job.parkingNotes != null) _detailRow('Parking', job.parkingNotes!, isDark),
                        if (job.accessNotes != null) _detailRow('Access', job.accessNotes!, isDark),
                        if (job.siteNotes != null) _detailRow('Notes', job.siteNotes!, isDark),
                      ], isDark),
                      const SizedBox(height: 12),
                      SiteMapPreview(
                        address: job.siteAddress,
                        latitude: job.latitude,
                        longitude: job.longitude,
                        height: 200,
                        onTap: () => _openDirections(job.siteAddress),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _openDirections(job.siteAddress),
                          icon: Icon(AppIcons.map, size: 18),
                          label: const Text('Get Directions'),
                        ),
                      ),
                      if (job.companySiteId != null &&
                          RemoteConfigService.instance.assetRegisterEnabled) ...[
                        const SizedBox(height: 16),
                        _buildSiteAssetsSection(job, isDark),
                      ],
                      const SizedBox(height: 16),
                      if (job.contactName != null || job.contactPhone != null || job.contactEmail != null)
                        ...[
                          _buildSection('Contact', [
                            if (job.contactName != null) _detailRow('Name', job.contactName!, isDark),
                            if (job.contactPhone != null) _detailRow('Phone', job.contactPhone!, isDark),
                            if (job.contactEmail != null) _detailRow('Email', job.contactEmail!, isDark),
                          ], isDark),
                          const SizedBox(height: 16),
                        ],
                      _buildSection('Scheduling', [
                        _detailRow(
                          'Date',
                          job.scheduledDate != null
                              ? DateFormat('EEEE, dd MMMM yyyy').format(job.scheduledDate!)
                              : 'Not set',
                          isDark,
                        ),
                        if (job.scheduledTime != null) _detailRow('Time', job.scheduledTime!, isDark),
                        if (job.estimatedDuration != null) _detailRow('Duration', job.estimatedDuration!, isDark),
                      ], isDark),
                      const SizedBox(height: 16),
                      _buildSection('Assignment', [
                        _detailRow(
                          'Engineer',
                          job.assignedToName ?? 'Unassigned',
                          isDark,
                        ),
                        _detailRow('Created by', job.createdByName, isDark),
                      ], isDark),
                      if (job.systemCategory != null || job.panelMake != null) ...[
                        const SizedBox(height: 16),
                        _buildSection('System Info', [
                          if (job.systemCategory != null) _detailRow('Category', job.systemCategory!, isDark),
                          if (job.panelMake != null) _detailRow('Panel', job.panelMake!, isDark),
                          if (job.panelLocation != null) _detailRow('Panel Location', job.panelLocation!, isDark),
                          if (job.numberOfZones != null) _detailRow('Zones', '${job.numberOfZones}', isDark),
                        ], isDark),
                      ],
                      if (job.linkedJobsheetId != null) ...[
                        const SizedBox(height: 16),
                        _buildLinkedJobsheetSection(job, isDark),
                      ],
                      const SizedBox(height: 24),
                      _buildActionButtons(job, isDark),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPanelHeader(DispatchedJob job, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceElevated : Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppTheme.darkDivider : AppTheme.dividerColor,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              job.title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: _closePanel,
            icon: const Icon(Icons.close),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTimeline(DispatchedJob job, bool isDark) {
    final statuses = [
      DispatchedJobStatus.created,
      DispatchedJobStatus.assigned,
      DispatchedJobStatus.accepted,
      DispatchedJobStatus.enRoute,
      DispatchedJobStatus.onSite,
      DispatchedJobStatus.completed,
    ];

    final currentIndex = statuses.indexOf(job.status);
    final isDeclined = job.status == DispatchedJobStatus.declined;

    return SizedBox(
      height: 56,
      child: Row(
        children: List.generate(statuses.length, (i) {
          final isActive = !isDeclined && i <= currentIndex;
          final isCurrent = !isDeclined && i == currentIndex;
          final color = isDeclined && i == 0
              ? Colors.red
              : isActive
                  ? _statusColor(statuses[i])
                  : (isDark ? AppTheme.darkDivider : Colors.grey.shade300);

          return Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (i > 0)
                      Expanded(
                        child: Container(height: 2, color: color),
                      ),
                    Container(
                      width: isCurrent ? 14 : 10,
                      height: isCurrent ? 14 : 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive ? color : Colors.transparent,
                        border: Border.all(color: color, width: 2),
                      ),
                    ),
                    if (i < statuses.length - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: !isDeclined && i < currentIndex
                              ? _statusColor(statuses[i + 1])
                              : (isDark ? AppTheme.darkDivider : Colors.grey.shade300),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _shortStatusLabel(statuses[i]),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                    color: isActive
                        ? (isDark ? Colors.white : AppTheme.darkGrey)
                        : (isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSiteAssetsSection(DispatchedJob job, bool isDark) {
    final basePath = 'companies/${job.companyId}';
    final siteId = job.companySiteId!;

    return FutureBuilder<List<Asset>>(
      future: AssetService.instance.getAssetsStream(basePath, siteId).first,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final assets = snapshot.data ?? [];
        if (assets.isEmpty) return const SizedBox.shrink();

        final active = assets.where((a) => a.complianceStatus != Asset.statusDecommissioned).toList();
        final pass = active.where((a) => a.complianceStatus == Asset.statusPass).length;
        final fail = active.where((a) => a.complianceStatus == Asset.statusFail).length;
        final untested = active.where((a) => a.complianceStatus == Asset.statusUntested).length;

        final now = DateTime.now();
        final lifecycleWarnings = active.where((a) {
          if (a.installDate == null || a.expectedLifespanYears == null) return false;
          final age = now.difference(a.installDate!).inDays / 365.25;
          return (a.expectedLifespanYears! - age) < 1;
        }).length;

        return _buildSection('Site Assets', [
          Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 14),
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
          if (lifecycleWarnings > 0) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(AppIcons.danger, size: 14, color: AppTheme.accentOrange),
                const SizedBox(width: 4),
                Text(
                  '$lifecycleWarnings asset${lifecycleWarnings == 1 ? '' : 's'} approaching end of life',
                  style: TextStyle(fontSize: 13, color: AppTheme.accentOrange, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                context.push('/sites/$siteId/assets', extra: {
                  'siteName': job.siteName,
                  'siteAddress': job.siteAddress,
                });
              },
              icon: Icon(AppIcons.clipboard, size: 18),
              label: const Text('View Asset Register'),
            ),
          ),
        ], isDark);
      },
    );
  }

  Widget _buildSection(String title, List<Widget> children, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _detailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(DispatchedJob job, bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (job.status != DispatchedJobStatus.completed && job.status != DispatchedJobStatus.declined)
          OutlinedButton.icon(
            onPressed: () => widget.onEdit(job),
            icon: Icon(AppIcons.edit, size: 16),
            label: const Text('Edit'),
          ),
        OutlinedButton.icon(
          onPressed: () => _duplicateJob(job),
          icon: Icon(AppIcons.copy, size: 16),
          label: const Text('Duplicate'),
        ),
        if (job.status != DispatchedJobStatus.completed)
          OutlinedButton.icon(
            onPressed: () => _showReassignDialog(job),
            icon: Icon(AppIcons.userAdd, size: 16),
            label: const Text('Reassign'),
          ),
        if (job.status != DispatchedJobStatus.completed && job.status != DispatchedJobStatus.declined)
          OutlinedButton.icon(
            onPressed: () => _cancelJob(job),
            icon: Icon(AppIcons.close, size: 16),
            label: const Text('Cancel'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
          ),
        OutlinedButton.icon(
          onPressed: () => _deleteJob(job),
          icon: Icon(AppIcons.trash, size: 16),
          label: const Text('Delete'),
          style: OutlinedButton.styleFrom(foregroundColor: AppTheme.errorRed),
        ),
        OutlinedButton.icon(
          onPressed: () {
            printPage();
            AnalyticsService.instance.logWebPrintUsed();
          },
          icon: Icon(AppIcons.printer, size: 16),
          label: const Text('Print'),
        ),
      ],
    );
  }

  void _duplicateJob(DispatchedJob job) {
    final duplicate = DispatchedJob(
      id: '',
      companyId: job.companyId,
      title: '${job.title} (Copy)',
      description: job.description,
      jobNumber: null,
      jobType: job.jobType,
      siteName: job.siteName,
      siteAddress: job.siteAddress,
      companySiteId: job.companySiteId,
      latitude: job.latitude,
      longitude: job.longitude,
      parkingNotes: job.parkingNotes,
      accessNotes: job.accessNotes,
      siteNotes: job.siteNotes,
      contactName: job.contactName,
      contactPhone: job.contactPhone,
      contactEmail: job.contactEmail,
      assignedTo: null,
      assignedToName: null,
      createdBy: '',
      createdByName: '',
      scheduledDate: null,
      scheduledTime: null,
      estimatedDuration: job.estimatedDuration,
      status: DispatchedJobStatus.created,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      priority: job.priority,
      systemCategory: job.systemCategory,
      panelMake: job.panelMake,
      panelLocation: job.panelLocation,
      numberOfZones: job.numberOfZones,
    );
    context.push('/jobs/create', extra: duplicate);
  }

  Future<void> _showReassignDialog(DispatchedJob job) async {
    final companyId = widget.companyId;
    final members = await CompanyService.instance.getCompanyMembers(companyId);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        String? selectedUid;
        String? selectedName;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Reassign Job'),
              content: DropdownButtonFormField<String?>(
                decoration: InputDecoration(
                  labelText: 'Engineer',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Unassigned')),
                  ...members.map((m) => DropdownMenuItem(
                    value: m.uid,
                    child: Text(m.displayName),
                  )),
                ],
                onChanged: (v) {
                  final member = members.where((m) => m.uid == v).firstOrNull;
                  setDialogState(() {
                    selectedUid = v;
                    selectedName = member?.displayName;
                  });
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedUid != null) {
                      await DispatchService.instance.assignJob(
                        companyId: companyId,
                        jobId: job.id,
                        engineerUid: selectedUid!,
                        engineerName: selectedName!,
                      );
                      AnalyticsService.instance.logWebJobAssigned();
                    }
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  child: const Text('Reassign'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _cancelJob(DispatchedJob job) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const CancelJobDialog(),
    );

    if (reason != null) {
      await DispatchService.instance.updateJobStatus(
        companyId: widget.companyId,
        jobId: job.id,
        newStatus: DispatchedJobStatus.declined,
        declineReason: reason,
      );
    }
  }

  Future<void> _deleteJob(DispatchedJob job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Job?'),
        content: Text('This will permanently delete "${job.title}". This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DispatchService.instance.deleteJob(widget.companyId, job.id);
      _closePanel();
    }
  }

  Color _statusColor(DispatchedJobStatus status) {
    switch (status) {
      case DispatchedJobStatus.created: return Colors.orange;
      case DispatchedJobStatus.assigned: return Colors.blue;
      case DispatchedJobStatus.accepted: return Colors.teal;
      case DispatchedJobStatus.enRoute: return Colors.indigo;
      case DispatchedJobStatus.onSite: return Colors.purple;
      case DispatchedJobStatus.completed: return AppTheme.successGreen;
      case DispatchedJobStatus.declined: return Colors.red;
    }
  }

  String _shortStatusLabel(DispatchedJobStatus status) {
    switch (status) {
      case DispatchedJobStatus.created: return 'New';
      case DispatchedJobStatus.assigned: return 'Assigned';
      case DispatchedJobStatus.accepted: return 'Accepted';
      case DispatchedJobStatus.enRoute: return 'En Route';
      case DispatchedJobStatus.onSite: return 'On Site';
      case DispatchedJobStatus.completed: return 'Done';
      case DispatchedJobStatus.declined: return 'Declined';
    }
  }

  String _priorityLabel(JobPriority priority) {
    switch (priority) {
      case JobPriority.normal: return 'Normal';
      case JobPriority.urgent: return 'Urgent';
      case JobPriority.emergency: return 'Emergency';
    }
  }

  Widget _buildLinkedJobsheetSection(DispatchedJob job, bool isDark) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('completed_jobsheets')
          .doc(job.linkedJobsheetId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurfaceElevated : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? AppTheme.darkDivider : AppTheme.dividerColor,
              ),
            ),
            child: const Row(
              children: [
                SizedBox(width: 16, height: 16, child: AdaptiveLoadingIndicator()),
                SizedBox(width: 12),
                Text('Loading jobsheet...', style: TextStyle(fontSize: 13)),
              ],
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.successGreen.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(AppIcons.document, color: AppTheme.successGreen, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Jobsheet completed and linked (data not yet synced)',
                    style: TextStyle(fontSize: 13, color: AppTheme.successGreen),
                  ),
                ),
              ],
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final jobsheet = Jobsheet.fromJson(data);

        return _buildJobsheetCard(jobsheet, job, isDark);
      },
    );
  }

  Widget _buildJobsheetCard(Jobsheet jobsheet, DispatchedJob job, bool isDark) {
    return StatefulBuilder(
      builder: (context, setCardState) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurfaceElevated : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.successGreen.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                ),
                child: Row(
                  children: [
                    Icon(AppIcons.document, color: AppTheme.successGreen, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Completed Jobsheet',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.successGreen,
                            ),
                          ),
                          Text(
                            '${jobsheet.engineerName} — ${DateFormat('dd MMM yyyy').format(jobsheet.date)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Jobsheet details
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detailRow('Customer', jobsheet.customerName, isDark),
                    _detailRow('Site', jobsheet.siteAddress, isDark),
                    _detailRow('Job #', jobsheet.jobNumber, isDark),
                    _detailRow('Category', jobsheet.systemCategory, isDark),
                    _detailRow('Template', jobsheet.templateType, isDark),

                    // Form data
                    if (jobsheet.formData.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'FORM DATA',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...jobsheet.formData.entries.map((entry) {
                        final label = jobsheet.fieldLabels[entry.key] ?? entry.key;
                        final value = entry.value?.toString() ?? '';
                        if (value.isEmpty) return const SizedBox.shrink();
                        // Handle checkbox/boolean values
                        final displayValue = value == 'true'
                            ? 'Yes'
                            : value == 'false'
                                ? 'No'
                                : value;
                        return _detailRow(label, displayValue, isDark);
                      }),
                    ],

                    // Notes
                    if (jobsheet.notes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'NOTES',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(jobsheet.notes, style: const TextStyle(fontSize: 13)),
                    ],

                    // Defects
                    if (jobsheet.defects.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'DEFECTS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.errorRed,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...jobsheet.defects.map((d) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• ', style: TextStyle(color: AppTheme.errorRed, fontSize: 13)),
                            Expanded(child: Text(d, style: const TextStyle(fontSize: 13))),
                          ],
                        ),
                      )),
                    ],

                    // Signatures
                    if (jobsheet.engineerSignature != null || jobsheet.customerSignature != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'SIGNATURES',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (jobsheet.engineerSignature != null)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Engineer', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey)),
                                  const SizedBox(height: 4),
                                  Container(
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: isDark ? AppTheme.darkDivider : AppTheme.dividerColor),
                                    ),
                                    child: Center(
                                      child: Image.memory(
                                        base64Decode(jobsheet.engineerSignature!),
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (jobsheet.engineerSignature != null && jobsheet.customerSignature != null)
                            const SizedBox(width: 12),
                          if (jobsheet.customerSignature != null)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    jobsheet.customerSignatureName ?? 'Customer',
                                    style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: isDark ? AppTheme.darkDivider : AppTheme.dividerColor),
                                    ),
                                    child: Center(
                                      child: Image.memory(
                                        base64Decode(jobsheet.customerSignature!),
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],

                    // Action buttons
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _JobsheetActionButton(
                            icon: AppIcons.download,
                            label: 'Download PDF',
                            onPressed: () => _downloadJobsheetPdf(jobsheet),
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _JobsheetActionButton(
                            icon: AppIcons.send,
                            label: 'Email to Client',
                            onPressed: () => _emailJobsheet(jobsheet, job),
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _downloadJobsheetPdf(Jobsheet jobsheet) async {
    try {
      showPremiumToast(context: context, message: 'Generating PDF...');
      final pdfBytes = await PDFService.generateJobsheetPDF(jobsheet);
      final filename = 'Jobsheet_${jobsheet.jobNumber}_${DateFormat('yyyyMMdd').format(jobsheet.date)}.pdf';
      downloadFile(pdfBytes, filename);
    } catch (e) {
      if (mounted) {
        showPremiumToast(context: context, message: 'Failed to generate PDF', variant: ToastVariant.error);
      }
    }
  }

  Future<void> _emailJobsheet(Jobsheet jobsheet, DispatchedJob job) async {
    final prefilledEmail = job.contactEmail ?? '';

    final emailController = TextEditingController(text: prefilledEmail);

    final shouldSend = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Email Jobsheet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will open your email client with a pre-filled message. Download the PDF first and attach it to the email.',
              style: TextStyle(fontSize: 13, color: AppTheme.mediumGrey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Recipient Email',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: Icon(AppIcons.send, size: 18),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop(false);
              _downloadJobsheetPdf(jobsheet);
            },
            icon: Icon(AppIcons.download, size: 16),
            label: const Text('Download PDF'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Open Email'),
          ),
        ],
      ),
    );

    if (shouldSend == true) {
      final email = emailController.text.trim();
      final subject = Uri.encodeComponent(
        'Jobsheet - ${jobsheet.customerName} - ${jobsheet.jobNumber}',
      );
      final body = Uri.encodeComponent(
        'Hi,\n\nPlease find the completed jobsheet for:\n\n'
        'Customer: ${jobsheet.customerName}\n'
        'Site: ${jobsheet.siteAddress}\n'
        'Job Number: ${jobsheet.jobNumber}\n'
        'Date: ${DateFormat('dd/MM/yyyy').format(jobsheet.date)}\n'
        'Engineer: ${jobsheet.engineerName}\n\n'
        'Please see the attached PDF.\n\n'
        'Kind regards',
      );
      final mailto = Uri.parse('mailto:$email?subject=$subject&body=$body');
      if (await canLaunchUrl(mailto)) {
        await launchUrl(mailto);
      }
    }

    emailController.dispose();
  }
}

class _JobsheetActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isDark;

  const _JobsheetActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        side: BorderSide(
          color: isDark ? AppTheme.darkDivider : AppTheme.dividerColor,
        ),
      ),
    );
  }
}
