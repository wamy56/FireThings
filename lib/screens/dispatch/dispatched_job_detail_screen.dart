import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/models.dart';
import '../../services/dispatch_service.dart';
import '../../services/company_service.dart';
import '../../services/database_helper.dart';
import '../../services/user_profile_service.dart';
import '../../services/analytics_service.dart';
import '../../services/asset_service.dart';
import '../../services/remote_config_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/premium_toast.dart';
import '../../widgets/premium_dialog.dart';
import '../../widgets/site_map_preview.dart';
import '../history/job_detail_screen.dart';
import '../assets/site_asset_register_screen.dart';
import '../new_job/new_job_screen.dart';
import 'create_job_screen.dart';
import 'decline_job_dialog.dart';

class DispatchedJobDetailScreen extends StatelessWidget {
  final String companyId;
  final String jobId;

  const DispatchedJobDetailScreen({
    super.key,
    required this.companyId,
    required this.jobId,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Job Details')),
      body: StreamBuilder<DispatchedJob?>(
        stream: DispatchService.instance.getJobStream(companyId, jobId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: AdaptiveLoadingIndicator());
          }

          final job = snapshot.data;
          if (job == null) {
            return const Center(child: Text('Job not found'));
          }

          return _JobDetailContent(job: job, isDark: isDark);
        },
      ),
    );
  }
}

class _JobDetailContent extends StatelessWidget {
  final DispatchedJob job;
  final bool isDark;

  const _JobDetailContent({required this.job, required this.isDark});

  bool get _canEditJobs =>
      UserProfileService.instance.hasPermission(AppPermission.dispatchEdit);

  bool get _isAssignee =>
      FirebaseAuth.instance.currentUser?.uid == job.assignedTo;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      children: [
        // Title and status
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                job.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            _statusBadge(job.status),
          ],
        ),
        if (job.priority != JobPriority.normal) ...[
          const SizedBox(height: 8),
          _priorityBadge(job.priority),
        ],
        const SizedBox(height: 24),

        // Job Details
        if (job.jobType != null || job.jobNumber != null)
          _section('Job Info', [
            if (job.jobType != null) _detailRow(AppIcons.category, 'Type', job.jobType!),
            if (job.jobNumber != null) _detailRow(AppIcons.tag, 'Number', job.jobNumber!),
            if (job.description != null)
              _detailRow(AppIcons.note, 'Description', job.description!),
          ]),

        // Site
        _section('Site', [
          _detailRow(AppIcons.building, 'Name', job.siteName),
          _detailRow(AppIcons.location, 'Address', job.siteAddress),
          if (job.parkingNotes != null)
            _detailRow(AppIcons.routing, 'Parking', job.parkingNotes!),
          if (job.accessNotes != null)
            _detailRow(AppIcons.key, 'Access', job.accessNotes!),
          if (job.siteNotes != null)
            _detailRow(AppIcons.note, 'Notes', job.siteNotes!),
        ]),

        // Map preview
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SiteMapPreview(
            address: job.siteAddress,
            latitude: job.latitude,
            longitude: job.longitude,
            height: 180,
            onTap: () => _openMaps(context, job.siteAddress),
          ),
        ),

        // Get Directions button
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: OutlinedButton.icon(
            onPressed: () => _openMaps(context, job.siteAddress),
            icon: Icon(AppIcons.map),
            label: const Text('Get Directions'),
          ),
        ),

        // Site Assets section (conditional)
        if (job.companySiteId != null &&
            RemoteConfigService.instance.assetRegisterEnabled)
          _buildSiteAssetsSection(context),

        // Contact
        if (job.contactName != null ||
            job.contactPhone != null ||
            job.contactEmail != null)
          _section('Contact', [
            if (job.contactName != null)
              _detailRow(AppIcons.user, 'Name', job.contactName!),
            if (job.contactPhone != null)
              _tappableRow(
                context,
                AppIcons.call,
                'Phone',
                job.contactPhone!,
                () => _launchUrl('tel:${job.contactPhone}'),
              ),
            if (job.contactEmail != null)
              _tappableRow(
                context,
                AppIcons.sms,
                'Email',
                job.contactEmail!,
                () => _launchUrl('mailto:${job.contactEmail}'),
              ),
          ]),

        // Scheduling
        if (job.scheduledDate != null ||
            job.scheduledTime != null ||
            job.estimatedDuration != null)
          _section('Schedule', [
            if (job.scheduledDate != null)
              _detailRow(AppIcons.calendar, 'Date',
                  '${job.scheduledDate!.day}/${job.scheduledDate!.month}/${job.scheduledDate!.year}'),
            if (job.scheduledTime != null)
              _detailRow(AppIcons.clock, 'Time', job.scheduledTime!),
            if (job.estimatedDuration != null)
              _detailRow(AppIcons.timer, 'Duration', job.estimatedDuration!),
          ]),

        // Assignment
        _section('Assignment', [
          _detailRow(AppIcons.user, 'Assigned To',
              job.assignedToName ?? 'Unassigned'),
          _detailRow(AppIcons.user, 'Created By', job.createdByName),
        ]),

        // System Info
        if (job.systemCategory != null ||
            job.panelMake != null ||
            job.panelLocation != null)
          _section('System Info', [
            if (job.systemCategory != null)
              _detailRow(AppIcons.category, 'Category', job.systemCategory!),
            if (job.panelMake != null)
              _detailRow(AppIcons.element, 'Panel Make', job.panelMake!),
            if (job.panelLocation != null)
              _detailRow(AppIcons.location, 'Panel Location', job.panelLocation!),
            if (job.numberOfZones != null)
              _detailRow(AppIcons.grid, 'Zones', '${job.numberOfZones}'),
          ]),

        // Decline reason
        if (job.declineReason != null)
          _section('Decline Reason', [
            _detailRow(AppIcons.danger, 'Reason', job.declineReason!),
          ]),

        const SizedBox(height: 24),

        // View Linked Jobsheet
        if (job.status == DispatchedJobStatus.completed &&
            job.linkedJobsheetId != null) ...[
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => _viewLinkedJobsheet(context, job.linkedJobsheetId!),
              icon: Icon(AppIcons.document),
              label: const Text('View Linked Jobsheet'),
            ),
          ),
          const SizedBox(height: 16),
        ] else if (job.status == DispatchedJobStatus.completed &&
            job.linkedJobsheetId == null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(AppIcons.infoCircle,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('No jobsheet linked to this job yet'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Assignee actions (status progression)
        if (_isAssignee) ..._buildAssigneeActions(context),

        // Dispatcher actions
        if (_canEditJobs) ...[
          if (job.status != DispatchedJobStatus.completed)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        adaptivePageRoute(
                          builder: (_) => CreateJobScreen(editJob: job),
                        ),
                      );
                    },
                    icon: Icon(AppIcons.edit),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _reassignJob(context),
                    icon: Icon(AppIcons.people),
                    label: const Text('Reassign'),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  List<Widget> _buildAssigneeActions(BuildContext context) {
    switch (job.status) {
      case DispatchedJobStatus.assigned:
        return [
          _section('Your Assignment', []),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => _updateStatus(context, DispatchedJobStatus.accepted),
              child: const Text('Accept Job'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: () => _declineJob(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
              child: const Text('Decline'),
            ),
          ),
          const SizedBox(height: 24),
        ];
      case DispatchedJobStatus.accepted:
        return [
          _section('Your Assignment', []),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => _updateStatus(context, DispatchedJobStatus.enRoute),
              icon: Icon(AppIcons.routing),
              label: const Text('En Route'),
            ),
          ),
          const SizedBox(height: 24),
        ];
      case DispatchedJobStatus.enRoute:
        return [
          _section('Your Assignment', []),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => _updateStatus(context, DispatchedJobStatus.onSite),
              icon: Icon(AppIcons.location),
              label: const Text('Arrived On Site'),
            ),
          ),
          const SizedBox(height: 24),
        ];
      case DispatchedJobStatus.onSite:
        return [
          _section('Your Assignment', []),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  adaptivePageRoute(
                    builder: (_) => NewJobScreen(dispatchedJob: job),
                  ),
                );
              },
              icon: Icon(AppIcons.clipboardTick),
              label: const Text('Create Jobsheet'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => _updateStatus(context, DispatchedJobStatus.completed),
              icon: Icon(AppIcons.tickCircle),
              label: const Text('Complete Without Jobsheet'),
            ),
          ),
          const SizedBox(height: 24),
        ];
      case DispatchedJobStatus.completed:
        if (job.linkedJobsheetId == null) {
          return [
            _section('Your Assignment', []),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    adaptivePageRoute(
                      builder: (_) => NewJobScreen(dispatchedJob: job),
                    ),
                  );
                },
                icon: Icon(AppIcons.clipboardTick),
                label: const Text('Create Jobsheet'),
              ),
            ),
            const SizedBox(height: 24),
          ];
        }
        return [];
      default:
        return [];
    }
  }

  Future<void> _updateStatus(
    BuildContext context,
    DispatchedJobStatus newStatus,
  ) async {
    try {
      final oldStatus = job.status;
      await DispatchService.instance.updateJobStatus(
        companyId: job.companyId,
        jobId: job.id,
        newStatus: newStatus,
      );
      AnalyticsService.instance.logDispatchJobStatusChanged(
        job.companyId,
        oldStatus.name,
        newStatus.name,
      );
      if (newStatus == DispatchedJobStatus.accepted) {
        AnalyticsService.instance.logDispatchJobAccepted(
          job.companyId,
          job.id,
        );
      } else if (newStatus == DispatchedJobStatus.completed) {
        AnalyticsService.instance.logDispatchJobCompleted(
          job.companyId,
          job.id,
          job.linkedJobsheetId != null,
        );
      }
    } catch (e) {
      if (context.mounted) {
        context.showErrorToast('Failed to update status');
      }
    }
  }

  Future<void> _declineJob(BuildContext context) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const DeclineJobDialog(),
    );

    if (reason == null) return;

    try {
      await DispatchService.instance.updateJobStatus(
        companyId: job.companyId,
        jobId: job.id,
        newStatus: DispatchedJobStatus.declined,
        declineReason: reason,
      );
      AnalyticsService.instance.logDispatchJobDeclined(
        job.companyId,
        reason,
      );
    } catch (e) {
      if (context.mounted) {
        context.showErrorToast('Failed to decline job');
      }
    }
  }

  Widget _buildSiteAssetsSection(BuildContext context) {
    final basePath = 'companies/${job.companyId}';
    final siteId = job.companySiteId!;

    return FutureBuilder<List<Asset>>(
      future: AssetService.instance.getAssetsStream(basePath, siteId).first,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: AdaptiveLoadingIndicator()),
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

        return _section('Site Assets', [
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
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SiteAssetRegisterScreen(
                      siteId: siteId,
                      siteName: job.siteName,
                      siteAddress: job.siteAddress,
                      basePath: basePath,
                    ),
                  ),
                );
              },
              icon: Icon(AppIcons.clipboard),
              label: const Text('View Asset Register'),
            ),
          ),
        ]);
      },
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(AppTheme.cardPadding),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceElevated : AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(
          color: isDark ? AppTheme.darkDivider : AppTheme.dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.darkTextSecondary : Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.mediumGrey),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _tappableRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppTheme.mediumGrey),
            const SizedBox(width: 12),
            SizedBox(
              width: 120,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.mediumGrey,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? AppTheme.darkPrimaryBlue
                      : AppTheme.primaryBlue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(DispatchedJobStatus status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _priorityBadge(JobPriority priority) {
    final isEmergency = priority == JobPriority.emergency;
    final color = isEmergency ? Colors.red : Colors.orange;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          isEmergency ? 'EMERGENCY' : 'URGENT',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  Future<void> _viewLinkedJobsheet(BuildContext context, String jobsheetId) async {
    try {
      // Try local DB first
      var jobsheet = await DatabaseHelper.instance.getJobsheetById(jobsheetId);

      // Firestore fallback for jobsheets created on another device
      if (jobsheet == null) {
        final companyId = UserProfileService.instance.companyId;
        if (companyId != null) {
          final doc = await FirebaseFirestore.instance
              .collection('companies')
              .doc(companyId)
              .collection('completed_jobsheets')
              .doc(jobsheetId)
              .get();
          if (doc.exists && doc.data() != null) {
            jobsheet = Jobsheet.fromJson(doc.data()!);
          }
        }
      }

      if (jobsheet != null && context.mounted) {
        Navigator.push(
          context,
          adaptivePageRoute(
            builder: (_) => JobDetailScreen(jobsheet: jobsheet!),
          ),
        );
      } else if (context.mounted) {
        context.showErrorToast('Jobsheet not found');
      }
    } catch (e) {
      if (context.mounted) {
        context.showErrorToast('Failed to load jobsheet');
      }
    }
  }

  Future<void> _reassignJob(BuildContext context) async {
    final companyId = UserProfileService.instance.companyId;
    if (companyId == null) return;

    final members =
        await CompanyService.instance.getCompanyMembers(companyId);

    if (!context.mounted) return;

    final selected = await showDialog<CompanyMember>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Assign To'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Unassigned'),
          ),
          ...members.map((m) => SimpleDialogOption(
                onPressed: () => Navigator.of(ctx).pop(m),
                child: Text('${m.displayName} (${m.role.name})'),
              )),
        ],
      ),
    );

    // User cancelled the dialog
    if (!context.mounted) return;

    try {
      if (selected == null) {
        // Unassign
        await DispatchService.instance.updateJob(
          job.copyWith(
            assignedTo: null,
            assignedToName: null,
            status: DispatchedJobStatus.created,
            updatedAt: DateTime.now(),
          ),
        );
      } else {
        await DispatchService.instance.assignJob(
          companyId: companyId,
          jobId: job.id,
          engineerUid: selected.uid,
          engineerName: selected.displayName,
        );
        AnalyticsService.instance.logDispatchJobAssigned(
          companyId,
          job.jobType,
        );
      }
    } catch (e) {
      if (context.mounted) {
        context.showErrorToast('Failed to reassign job');
      }
    }
  }

  void _openMaps(BuildContext context, String address) {
    final encodedAddress = Uri.encodeComponent(address);

    final options = <ActionSheetOption>[
      if (PlatformUtils.isApple)
        ActionSheetOption(
          label: 'Apple Maps',
          icon: AppIcons.map,
          onTap: () => _launchUrl('https://maps.apple.com/?daddr=$encodedAddress'),
        ),
      ActionSheetOption(
        label: 'Google Maps',
        icon: AppIcons.location,
        onTap: () => _launchUrl('https://www.google.com/maps/search/?api=1&query=$encodedAddress'),
      ),
      ActionSheetOption(
        label: 'Waze',
        icon: AppIcons.routing,
        onTap: () => _launchUrl('https://waze.com/ul?q=$encodedAddress&navigate=yes'),
      ),
    ];

    showAdaptiveActionSheet(
      context: context,
      title: 'Open with',
      options: options,
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Color _statusColor(DispatchedJobStatus status) {
    switch (status) {
      case DispatchedJobStatus.created:
        return Colors.orange;
      case DispatchedJobStatus.assigned:
        return Colors.blue;
      case DispatchedJobStatus.accepted:
        return Colors.teal;
      case DispatchedJobStatus.enRoute:
        return Colors.indigo;
      case DispatchedJobStatus.onSite:
        return Colors.purple;
      case DispatchedJobStatus.completed:
        return AppTheme.successGreen;
      case DispatchedJobStatus.declined:
        return Colors.red;
    }
  }

  String _statusLabel(DispatchedJobStatus status) {
    switch (status) {
      case DispatchedJobStatus.created:
        return 'Unassigned';
      case DispatchedJobStatus.assigned:
        return 'Assigned';
      case DispatchedJobStatus.accepted:
        return 'Accepted';
      case DispatchedJobStatus.enRoute:
        return 'En Route';
      case DispatchedJobStatus.onSite:
        return 'On Site';
      case DispatchedJobStatus.completed:
        return 'Completed';
      case DispatchedJobStatus.declined:
        return 'Declined';
    }
  }
}
