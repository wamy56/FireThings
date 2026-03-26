import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/models.dart';
import '../../services/dispatch_service.dart';
import '../../services/database_helper.dart';
import '../../services/analytics_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/premium_toast.dart';
import '../../widgets/premium_dialog.dart';
import '../new_job/new_job_screen.dart';
import '../history/job_detail_screen.dart';
import 'decline_job_dialog.dart';

class EngineerJobDetailScreen extends StatelessWidget {
  final String companyId;
  final String jobId;

  const EngineerJobDetailScreen({
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

          return _EngineerJobContent(job: job, isDark: isDark);
        },
      ),
    );
  }
}

class _EngineerJobContent extends StatelessWidget {
  final DispatchedJob job;
  final bool isDark;

  const _EngineerJobContent({required this.job, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      children: [
        // Title and priority
        Text(
          job.title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        if (job.priority != JobPriority.normal) ...[
          const SizedBox(height: 8),
          _priorityBanner(job.priority),
        ],
        if (job.jobType != null) ...[
          const SizedBox(height: 4),
          Text(
            job.jobType!,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
            ),
          ),
        ],
        const SizedBox(height: 24),

        // Site section
        _sectionCard(context, 'Site', AppIcons.building, [
          _infoRow('Name', job.siteName),
          _infoRow('Address', job.siteAddress),
          if (job.parkingNotes != null) _infoRow('Parking', job.parkingNotes!),
          if (job.accessNotes != null) _infoRow('Access', job.accessNotes!),
          if (job.siteNotes != null) _infoRow('Notes', job.siteNotes!),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openMaps(context, job.siteAddress),
              icon: Icon(AppIcons.map),
              label: const Text('Get Directions'),
            ),
          ),
        ]),
        const SizedBox(height: 16),

        // Contact section
        if (job.contactName != null ||
            job.contactPhone != null ||
            job.contactEmail != null)
          ...[
            _sectionCard(context, 'Contact', AppIcons.user, [
              if (job.contactName != null) _infoRow('Name', job.contactName!),
              if (job.contactPhone != null)
                InkWell(
                  onTap: () {
                    AnalyticsService.instance.logDispatchContactCalled(job.companyId);
                    _launchUrl('tel:${job.contactPhone}');
                  },
                  child: _infoRow('Phone', job.contactPhone!,
                      valueColor: isDark
                          ? AppTheme.darkPrimaryBlue
                          : AppTheme.primaryBlue),
                ),
              if (job.contactEmail != null)
                InkWell(
                  onTap: () => _launchUrl('mailto:${job.contactEmail}'),
                  child: _infoRow('Email', job.contactEmail!,
                      valueColor: isDark
                          ? AppTheme.darkPrimaryBlue
                          : AppTheme.primaryBlue),
                ),
            ]),
            const SizedBox(height: 16),
          ],

        // Schedule section
        if (job.scheduledDate != null || job.estimatedDuration != null)
          ...[
            _sectionCard(context, 'Schedule', AppIcons.calendar, [
              if (job.scheduledDate != null)
                _infoRow('Date',
                    '${job.scheduledDate!.day}/${job.scheduledDate!.month}/${job.scheduledDate!.year}'),
              if (job.scheduledTime != null) _infoRow('Time', job.scheduledTime!),
              if (job.estimatedDuration != null)
                _infoRow('Duration', job.estimatedDuration!),
            ]),
            const SizedBox(height: 16),
          ],

        // System info
        if (job.systemCategory != null ||
            job.panelMake != null ||
            job.panelLocation != null)
          ...[
            _sectionCard(context, 'System', AppIcons.flash, [
              if (job.systemCategory != null)
                _infoRow('Category', job.systemCategory!),
              if (job.panelMake != null) _infoRow('Panel Make', job.panelMake!),
              if (job.panelLocation != null)
                _infoRow('Panel Location', job.panelLocation!),
              if (job.numberOfZones != null)
                _infoRow('Zones', '${job.numberOfZones}'),
            ]),
            const SizedBox(height: 16),
          ],

        // Description
        if (job.description != null) ...[
          _sectionCard(context, 'Notes', AppIcons.note, [
            Text(job.description!, style: const TextStyle(fontSize: 14)),
          ]),
          const SizedBox(height: 16),
        ],

        const SizedBox(height: 8),

        // Action buttons based on current status
        ..._buildActionButtons(context),

        const SizedBox(height: 40),
      ],
    );
  }

  List<Widget> _buildActionButtons(BuildContext context) {
    switch (job.status) {
      case DispatchedJobStatus.assigned:
        return [
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
        ];
      case DispatchedJobStatus.accepted:
        return [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () =>
                  _updateStatus(context, DispatchedJobStatus.enRoute),
              icon: Icon(AppIcons.routing),
              label: const Text('En Route'),
            ),
          ),
        ];
      case DispatchedJobStatus.enRoute:
        return [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () =>
                  _updateStatus(context, DispatchedJobStatus.onSite),
              icon: Icon(AppIcons.location),
              label: const Text('Arrived On Site'),
            ),
          ),
        ];
      case DispatchedJobStatus.onSite:
        return [
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
              onPressed: () =>
                  _updateStatus(context, DispatchedJobStatus.completed),
              icon: Icon(AppIcons.tickCircle),
              label: const Text('Complete Without Jobsheet'),
            ),
          ),
        ];
      case DispatchedJobStatus.completed:
        if (job.linkedJobsheetId != null) {
          return [
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => _viewLinkedJobsheet(context, job.linkedJobsheetId!),
                icon: Icon(AppIcons.document),
                label: const Text('View Linked Jobsheet'),
              ),
            ),
          ];
        }
        return [];
      default:
        return [];
    }
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
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) context.showErrorToast('Failed to decline job');
    }
  }

  Widget _sectionCard(
    BuildContext context,
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.cardPadding),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: isDark ? null : AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.mediumGrey),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.mediumGrey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _priorityBanner(JobPriority priority) {
    final isEmergency = priority == JobPriority.emergency;
    final color = isEmergency ? Colors.red : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(AppIcons.warning, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            isEmergency ? 'Emergency Priority' : 'Urgent Priority',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _openMaps(BuildContext context, String address) {
    AnalyticsService.instance.logDispatchDirectionsOpened(job.companyId);
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
}
