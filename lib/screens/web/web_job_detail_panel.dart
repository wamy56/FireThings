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
import '../../theme/web_theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/premium_toast.dart';
import '../../widgets/site_map_preview.dart';
import '../../services/analytics_service.dart';
import '../../utils/print_stub.dart'
    if (dart.library.html) '../../utils/print_web.dart';
import '../../utils/download_stub.dart'
    if (dart.library.html) '../../utils/download_web.dart';
import 'cancel_job_dialog.dart';
import '../../models/asset.dart';
import '../../services/asset_service.dart';
import '../../services/remote_config_service.dart';
import 'package:go_router/go_router.dart';
import 'dashboard/job_helpers.dart';

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
      duration: FtMotion.slow,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: FtMotion.standardCurve,
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
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        decoration: const BoxDecoration(
          color: FtColors.bg,
          boxShadow: FtShadows.lg,
          border: Border(
              left: BorderSide(color: FtColors.border, width: 1.5)),
        ),
        child: StreamBuilder<DispatchedJob?>(
          stream: DispatchService.instance
              .getJobStream(widget.companyId, widget.jobId),
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
                    Icon(AppIcons.warning, size: 32, color: FtColors.hint),
                    const SizedBox(height: 8),
                    Text('Job not found', style: FtText.bodySoft),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _closePanel,
                      style: TextButton.styleFrom(
                          foregroundColor: FtColors.fg2),
                      child: Text('Close', style: FtText.button),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                _buildPanelHeader(job),
                Expanded(
                  child: ListView(
                    padding: FtSpacing.cardBody,
                    children: [
                      _buildStatusTimeline(job),
                      const SizedBox(height: 20),
                      _buildSection('Job Details', [
                        _detailRow('Title', job.title),
                        if (job.jobType != null)
                          _detailRow('Type', job.jobType!),
                        if (job.jobNumber != null)
                          _detailRow('Job #', job.jobNumber!),
                        if (job.description != null)
                          _detailRow('Description', job.description!),
                        _detailRow(
                            'Priority', _priorityLabel(job.priority)),
                      ]),
                      const SizedBox(height: 16),
                      _buildSection('Site', [
                        _detailRow('Name', job.siteName),
                        _detailRow('Address', job.siteAddress),
                        if (job.parkingNotes != null)
                          _detailRow('Parking', job.parkingNotes!),
                        if (job.accessNotes != null)
                          _detailRow('Access', job.accessNotes!),
                        if (job.siteNotes != null)
                          _detailRow('Notes', job.siteNotes!),
                      ]),
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
                          onPressed: () =>
                              _openDirections(job.siteAddress),
                          icon: Icon(AppIcons.map, size: 18),
                          label: Text('Get Directions',
                              style: FtText.button),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: FtColors.fg1,
                            side: const BorderSide(
                                color: FtColors.border, width: 1.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: FtRadii.mdAll),
                          ),
                        ),
                      ),
                      if (job.companySiteId != null &&
                          RemoteConfigService
                              .instance.assetRegisterEnabled) ...[
                        const SizedBox(height: 16),
                        _buildSiteAssetsSection(job),
                      ],
                      const SizedBox(height: 16),
                      if (job.contactName != null ||
                          job.contactPhone != null ||
                          job.contactEmail != null) ...[
                        _buildSection('Contact', [
                          if (job.contactName != null)
                            _detailRow('Name', job.contactName!),
                          if (job.contactPhone != null)
                            _detailRow('Phone', job.contactPhone!),
                          if (job.contactEmail != null)
                            _detailRow('Email', job.contactEmail!),
                        ]),
                        const SizedBox(height: 16),
                      ],
                      _buildSection('Scheduling', [
                        _detailRow(
                          'Date',
                          job.scheduledDate != null
                              ? DateFormat('EEEE, dd MMMM yyyy')
                                  .format(job.scheduledDate!)
                              : 'Not set',
                        ),
                        if (job.scheduledTime != null)
                          _detailRow('Time', job.scheduledTime!),
                        if (job.estimatedDuration != null)
                          _detailRow(
                              'Duration', job.estimatedDuration!),
                      ]),
                      const SizedBox(height: 16),
                      _buildSection('Assignment', [
                        _detailRow(
                          'Engineer',
                          job.assignedToName ?? 'Unassigned',
                        ),
                        _detailRow('Created by', job.createdByName),
                      ]),
                      if (job.systemCategory != null ||
                          job.panelMake != null) ...[
                        const SizedBox(height: 16),
                        _buildSection('System Info', [
                          if (job.systemCategory != null)
                            _detailRow(
                                'Category', job.systemCategory!),
                          if (job.panelMake != null)
                            _detailRow('Panel', job.panelMake!),
                          if (job.panelLocation != null)
                            _detailRow('Panel Location',
                                job.panelLocation!),
                          if (job.numberOfZones != null)
                            _detailRow(
                                'Zones', '${job.numberOfZones}'),
                        ]),
                      ],
                      if (job.linkedJobsheetId != null) ...[
                        const SizedBox(height: 16),
                        _buildLinkedJobsheetSection(job),
                      ],
                      const SizedBox(height: 24),
                      _buildActionButtons(job),
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

  Widget _buildPanelHeader(DispatchedJob job) {
    return Container(
      padding: FtSpacing.cardHeader,
      decoration: const BoxDecoration(
        color: FtColors.bgAlt,
        border:
            Border(bottom: BorderSide(color: FtColors.border, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(job.title,
                    style: FtText.cardTitle,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Row(
                  children: [
                    jobStatusBadge(job.status),
                    const SizedBox(width: 8),
                    if (job.priority != JobPriority.normal)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: jobPriorityBadge(job.priority),
                      ),
                    if (job.jobNumber != null)
                      Text(job.jobNumber!, style: FtText.monoSmall),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _closePanel,
            icon: Icon(AppIcons.close, color: FtColors.fg2),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTimeline(DispatchedJob job) {
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
              ? FtColors.danger
              : isActive
                  ? jobStatusColor(statuses[i])
                  : FtColors.border;

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
                        color:
                            isActive ? color : Colors.transparent,
                        border:
                            Border.all(color: color, width: 2),
                      ),
                    ),
                    if (i < statuses.length - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: !isDeclined && i < currentIndex
                              ? jobStatusColor(statuses[i + 1])
                              : FtColors.border,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _shortStatusLabel(statuses[i]),
                  style: FtText.inter(
                    size: 9,
                    weight: isCurrent
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color:
                        isActive ? FtColors.fg1 : FtColors.hint,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSiteAssetsSection(DispatchedJob job) {
    final basePath = 'companies/${job.companyId}';
    final siteId = job.companySiteId!;

    return FutureBuilder<List<Asset>>(
      future:
          AssetService.instance.getAssetsStream(basePath, siteId).first,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child:
                Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final assets = snapshot.data ?? [];
        if (assets.isEmpty) return const SizedBox.shrink();

        final active = assets
            .where((a) =>
                a.complianceStatus !=
                AssetComplianceStatus.decommissioned)
            .toList();
        final pass = active
            .where((a) =>
                a.complianceStatus == AssetComplianceStatus.pass)
            .length;
        final fail = active
            .where((a) =>
                a.complianceStatus == AssetComplianceStatus.fail)
            .length;
        final untested = active
            .where((a) =>
                a.complianceStatus == AssetComplianceStatus.untested)
            .length;

        final now = DateTime.now();
        final lifecycleWarnings = active.where((a) {
          if (a.installDate == null || a.expectedLifespanYears == null) {
            return false;
          }
          final age = now.difference(a.installDate!).inDays / 365.25;
          return (a.expectedLifespanYears! - age) < 1;
        }).length;

        return _buildSection('Site Assets', [
          Text.rich(
            TextSpan(
              style: FtText.body,
              children: [
                TextSpan(
                  text: '${active.length} assets: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(
                  text: '$pass pass',
                  style: TextStyle(
                      color: FtColors.success,
                      fontWeight: FontWeight.w600),
                ),
                if (fail > 0) ...[
                  const TextSpan(text: ', '),
                  TextSpan(
                    text: '$fail fail',
                    style: TextStyle(
                        color: FtColors.danger,
                        fontWeight: FontWeight.w600),
                  ),
                ],
                if (untested > 0) ...[
                  const TextSpan(text: ', '),
                  TextSpan(
                    text: '$untested untested',
                    style: TextStyle(
                        color: FtColors.warning,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
          if (lifecycleWarnings > 0) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(AppIcons.danger,
                    size: 14, color: FtColors.warning),
                const SizedBox(width: 4),
                Text(
                  '$lifecycleWarnings asset${lifecycleWarnings == 1 ? '' : 's'} approaching end of life',
                  style: FtText.inter(
                      size: 13,
                      weight: FontWeight.w500,
                      color: FtColors.warning),
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
              label:
                  Text('View Asset Register', style: FtText.button),
              style: OutlinedButton.styleFrom(
                foregroundColor: FtColors.fg1,
                side: const BorderSide(
                    color: FtColors.border, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: FtRadii.mdAll),
              ),
            ),
          ),
        ]);
      },
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      padding: FtSpacing.cardBody,
      decoration: FtDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: FtText.label),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: FtText.helper),
          ),
          Expanded(
            child: Text(value,
                style: FtText.inter(
                    size: 13,
                    weight: FontWeight.w500,
                    color: FtColors.fg1)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(DispatchedJob job) {
    final btnStyle = OutlinedButton.styleFrom(
      foregroundColor: FtColors.fg1,
      side: const BorderSide(color: FtColors.border, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: FtRadii.mdAll),
      textStyle: FtText.button,
    );

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (job.status != DispatchedJobStatus.completed &&
            job.status != DispatchedJobStatus.declined)
          OutlinedButton.icon(
            onPressed: () => widget.onEdit(job),
            icon: Icon(AppIcons.edit, size: 16),
            label: const Text('Edit'),
            style: btnStyle,
          ),
        OutlinedButton.icon(
          onPressed: () => _duplicateJob(job),
          icon: Icon(AppIcons.copy, size: 16),
          label: const Text('Duplicate'),
          style: btnStyle,
        ),
        if (job.status != DispatchedJobStatus.completed)
          OutlinedButton.icon(
            onPressed: () => _showReassignDialog(job),
            icon: Icon(AppIcons.userAdd, size: 16),
            label: const Text('Reassign'),
            style: btnStyle,
          ),
        if (job.status != DispatchedJobStatus.completed &&
            job.status != DispatchedJobStatus.declined)
          OutlinedButton.icon(
            onPressed: () => _cancelJob(job),
            icon: Icon(AppIcons.close, size: 16),
            label: const Text('Cancel'),
            style: OutlinedButton.styleFrom(
              foregroundColor: FtColors.warning,
              side: BorderSide(
                  color: FtColors.warning.withValues(alpha: 0.3),
                  width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: FtRadii.mdAll),
              textStyle: FtText.button,
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => _deleteJob(job),
          icon: Icon(AppIcons.trash, size: 16),
          label: const Text('Delete'),
          style: OutlinedButton.styleFrom(
            foregroundColor: FtColors.danger,
            side: BorderSide(
                color: FtColors.danger.withValues(alpha: 0.3),
                width: 1.5),
            shape: RoundedRectangleBorder(
                borderRadius: FtRadii.mdAll),
            textStyle: FtText.button,
          ),
        ),
        OutlinedButton.icon(
          onPressed: () {
            printPage();
            AnalyticsService.instance.logWebPrintUsed();
          },
          icon: Icon(AppIcons.printer, size: 16),
          label: const Text('Print'),
          style: btnStyle,
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
    final members =
        await CompanyService.instance.getCompanyMembers(companyId);

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
                  border: OutlineInputBorder(
                      borderRadius: FtRadii.mdAll),
                ),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('Unassigned')),
                  ...members.map((m) => DropdownMenuItem(
                        value: m.uid,
                        child: Text(m.displayName),
                      )),
                ],
                onChanged: (v) {
                  final member =
                      members.where((m) => m.uid == v).firstOrNull;
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
        content: Text(
            'This will permanently delete "${job.title}". This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: FtColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DispatchService.instance
          .deleteJob(widget.companyId, job.id);
      _closePanel();
    }
  }

  String _shortStatusLabel(DispatchedJobStatus status) {
    switch (status) {
      case DispatchedJobStatus.created:
        return 'New';
      case DispatchedJobStatus.assigned:
        return 'Assigned';
      case DispatchedJobStatus.accepted:
        return 'Accepted';
      case DispatchedJobStatus.enRoute:
        return 'En Route';
      case DispatchedJobStatus.onSite:
        return 'On Site';
      case DispatchedJobStatus.completed:
        return 'Done';
      case DispatchedJobStatus.declined:
        return 'Declined';
    }
  }

  String _priorityLabel(JobPriority priority) {
    switch (priority) {
      case JobPriority.normal:
        return 'Normal';
      case JobPriority.urgent:
        return 'Urgent';
      case JobPriority.emergency:
        return 'Emergency';
    }
  }

  Widget _buildLinkedJobsheetSection(DispatchedJob job) {
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
            padding: FtSpacing.cardBody,
            decoration: BoxDecoration(
              color: FtColors.bgAlt,
              borderRadius: FtRadii.mdAll,
              border: Border.all(color: FtColors.border, width: 1.5),
            ),
            child: Row(
              children: [
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: AdaptiveLoadingIndicator()),
                const SizedBox(width: 12),
                Text('Loading jobsheet...', style: FtText.helper),
              ],
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Container(
            padding: FtSpacing.cardBody,
            decoration: BoxDecoration(
              color: FtColors.successSoft,
              borderRadius: FtRadii.mdAll,
              border: Border.all(
                  color: FtColors.success.withValues(alpha: 0.3),
                  width: 1.5),
            ),
            child: Row(
              children: [
                Icon(AppIcons.document,
                    color: FtColors.success, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Jobsheet completed and linked (data not yet synced)',
                    style:
                        FtText.helper.copyWith(color: FtColors.success),
                  ),
                ),
              ],
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final jobsheet = Jobsheet.fromJson(data);

        return _buildJobsheetCard(jobsheet, job);
      },
    );
  }

  Widget _buildJobsheetCard(Jobsheet jobsheet, DispatchedJob job) {
    return StatefulBuilder(
      builder: (context, setCardState) {
        return Container(
          decoration: BoxDecoration(
            color: FtColors.bgAlt,
            borderRadius: FtRadii.lgAll,
            border: Border.all(
                color: FtColors.success.withValues(alpha: 0.4),
                width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: FtSpacing.cardHeader,
                decoration: const BoxDecoration(
                  color: FtColors.successSoft,
                ),
                child: Row(
                  children: [
                    Icon(AppIcons.document,
                        color: FtColors.success, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Completed Jobsheet',
                            style: FtText.inter(
                                size: 13,
                                weight: FontWeight.w600,
                                color: FtColors.success),
                          ),
                          Text(
                            '${jobsheet.engineerName} — ${DateFormat('dd MMM yyyy').format(jobsheet.date)}',
                            style: FtText.helper,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: FtSpacing.cardBody,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detailRow('Customer', jobsheet.customerName),
                    _detailRow('Site', jobsheet.siteAddress),
                    _detailRow('Job #', jobsheet.jobNumber),
                    _detailRow('Category', jobsheet.systemCategory),
                    _detailRow('Template', jobsheet.templateType),
                    if (jobsheet.formData.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('FORM DATA', style: FtText.label),
                      const SizedBox(height: 6),
                      ...jobsheet.formData.entries.map((entry) {
                        final label =
                            jobsheet.fieldLabels[entry.key] ??
                                entry.key;
                        final value =
                            entry.value?.toString() ?? '';
                        if (value.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        final displayValue = value == 'true'
                            ? 'Yes'
                            : value == 'false'
                                ? 'No'
                                : value;
                        return _detailRow(label, displayValue);
                      }),
                    ],
                    if (jobsheet.notes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('NOTES', style: FtText.label),
                      const SizedBox(height: 4),
                      Text(jobsheet.notes,
                          style: FtText.inter(
                              size: 13,
                              weight: FontWeight.w500,
                              color: FtColors.fg1)),
                    ],
                    if (jobsheet.defects.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('DEFECTS',
                          style: FtText.label
                              .copyWith(color: FtColors.danger)),
                      const SizedBox(height: 4),
                      ...jobsheet.defects.map((d) => Padding(
                            padding:
                                const EdgeInsets.only(bottom: 2),
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text('• ',
                                    style: FtText.inter(
                                        size: 13,
                                        color: FtColors.danger)),
                                Expanded(
                                    child: Text(d,
                                        style: FtText.inter(
                                            size: 13,
                                            weight:
                                                FontWeight.w500,
                                            color:
                                                FtColors.fg1))),
                              ],
                            ),
                          )),
                    ],
                    if (jobsheet.engineerSignature != null ||
                        jobsheet.customerSignature != null) ...[
                      const SizedBox(height: 12),
                      Text('SIGNATURES', style: FtText.label),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (jobsheet.engineerSignature != null)
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text('Engineer',
                                      style: FtText.label),
                                  const SizedBox(height: 4),
                                  Container(
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: FtColors.bg,
                                      borderRadius:
                                          FtRadii.smAll,
                                      border: Border.all(
                                          color:
                                              FtColors.border,
                                          width: 1.5),
                                    ),
                                    child: Center(
                                      child: Image.memory(
                                        base64Decode(jobsheet
                                            .engineerSignature!),
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (jobsheet.engineerSignature !=
                                  null &&
                              jobsheet.customerSignature !=
                                  null)
                            const SizedBox(width: 12),
                          if (jobsheet.customerSignature != null)
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    jobsheet.customerSignatureName ??
                                        'Customer',
                                    style: FtText.label,
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: FtColors.bg,
                                      borderRadius:
                                          FtRadii.smAll,
                                      border: Border.all(
                                          color:
                                              FtColors.border,
                                          width: 1.5),
                                    ),
                                    child: Center(
                                      child: Image.memory(
                                        base64Decode(jobsheet
                                            .customerSignature!),
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
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _JobsheetActionButton(
                            icon: AppIcons.download,
                            label: 'Download PDF',
                            onPressed: () =>
                                _downloadJobsheetPdf(jobsheet),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _JobsheetActionButton(
                            icon: AppIcons.send,
                            label: 'Email to Client',
                            onPressed: () =>
                                _emailJobsheet(jobsheet, job),
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
      final pdfBytes =
          await PDFService.generateJobsheetPDF(jobsheet);
      final filename =
          'Jobsheet_${jobsheet.jobNumber}_${DateFormat('yyyyMMdd').format(jobsheet.date)}.pdf';
      downloadFile(pdfBytes, filename);
    } catch (e) {
      if (mounted) {
        showPremiumToast(
            context: context,
            message: 'Failed to generate PDF',
            variant: ToastVariant.error);
      }
    }
  }

  Future<void> _emailJobsheet(
      Jobsheet jobsheet, DispatchedJob job) async {
    final prefilledEmail = job.contactEmail ?? '';

    final emailController =
        TextEditingController(text: prefilledEmail);

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
              style: FtText.helper,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Recipient Email',
                border: OutlineInputBorder(
                    borderRadius: FtRadii.mdAll),
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
      final mailto =
          Uri.parse('mailto:$email?subject=$subject&body=$body');
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

  const _JobsheetActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: FtText.button.copyWith(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: FtColors.fg1,
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        side: const BorderSide(color: FtColors.border, width: 1.5),
        shape:
            RoundedRectangleBorder(borderRadius: FtRadii.mdAll),
      ),
    );
  }
}
