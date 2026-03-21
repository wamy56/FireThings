import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/models.dart';
import '../../services/dispatch_service.dart';
import '../../services/company_service.dart';
import '../../services/database_helper.dart';
import '../../services/user_profile_service.dart';
import '../../services/analytics_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/premium_toast.dart';
import '../history/job_detail_screen.dart';
import 'create_job_screen.dart';

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

  bool get _isDispatcherOrAdmin =>
      UserProfileService.instance.isDispatcherOrAdmin;

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

        // Get Directions button
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: OutlinedButton.icon(
            onPressed: () => _openMaps(context, job.siteAddress),
            icon: Icon(AppIcons.map),
            label: const Text('Get Directions'),
          ),
        ),
        const SizedBox(height: 8),

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
        ],

        // Actions
        if (_isDispatcherOrAdmin) ...[
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

  Widget _section(String title, List<Widget> children) {
    return Column(
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
        const SizedBox(height: 16),
      ],
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
            width: 80,
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
              width: 80,
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
      final jobsheet = await DatabaseHelper.instance.getJobsheetById(jobsheetId);
      if (jobsheet != null && context.mounted) {
        Navigator.push(
          context,
          adaptivePageRoute(
            builder: (_) => JobDetailScreen(jobsheet: jobsheet),
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
    _launchUrl('https://www.google.com/maps/search/?api=1&query=$encodedAddress');
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
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
