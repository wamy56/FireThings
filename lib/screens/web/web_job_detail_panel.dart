import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/dispatched_job.dart';
import '../../models/company_member.dart';
import '../../services/dispatch_service.dart';
import '../../services/company_service.dart';
import '../../services/user_profile_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/premium_toast.dart';
import '../../services/analytics_service.dart';
import '../../utils/print_stub.dart' if (dart.library.html) '../../utils/print_web.dart';

class WebJobDetailPanel extends StatefulWidget {
  final String companyId;
  final String jobId;
  final VoidCallback onClose;
  final void Function(DispatchedJob job) onEdit;

  const WebJobDetailPanel({
    super.key,
    required this.companyId,
    required this.jobId,
    required this.onClose,
    required this.onEdit,
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
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _closePanel() async {
    await _slideController.reverse();
    widget.onClose();
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
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.successGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(AppIcons.clipboardTick, color: AppTheme.successGreen, size: 18),
                              const SizedBox(width: 8),
                              const Text('Jobsheet completed and linked'),
                            ],
                          ),
                        ),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Job?'),
        content: Text('Are you sure you want to cancel "${job.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('No')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Cancel Job'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DispatchService.instance.updateJobStatus(
        companyId: widget.companyId,
        jobId: job.id,
        newStatus: DispatchedJobStatus.declined,
        declineReason: 'Cancelled by dispatcher',
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
}
