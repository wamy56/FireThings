import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/dispatched_job.dart';
import '../../services/dispatch_service.dart';
import '../../services/user_profile_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import 'engineer_job_detail_screen.dart';

class EngineerJobsScreen extends StatelessWidget {
  const EngineerJobsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final companyId = UserProfileService.instance.companyId;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (companyId == null || uid == null) {
      return const Center(child: Text('No company found'));
    }

    return Scaffold(
      body: StreamBuilder<List<DispatchedJob>>(
        stream: DispatchService.instance.getEngineerJobsStream(companyId, uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: AdaptiveLoadingIndicator());
          }

          final allJobs = snapshot.data ?? [];
          if (allJobs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    AppIcons.clipboard,
                    size: 48,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.mediumGrey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No jobs assigned to you',
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.mediumGrey,
                    ),
                  ),
                ],
              ),
            );
          }

          final active = allJobs.where((j) =>
              j.status == DispatchedJobStatus.accepted ||
              j.status == DispatchedJobStatus.enRoute ||
              j.status == DispatchedJobStatus.onSite).toList();
          final upcoming = allJobs
              .where((j) => j.status == DispatchedJobStatus.assigned)
              .toList();
          final completed = allJobs
              .where((j) => j.status == DispatchedJobStatus.completed)
              .toList();

          return ListView(
            padding: const EdgeInsets.all(AppTheme.screenPadding),
            children: [
              if (active.isNotEmpty) ...[
                _sectionTitle('Active', isDark),
                const SizedBox(height: 8),
                ...active.map((j) => _buildJobCard(context, j, isDark)),
                const SizedBox(height: 16),
              ],
              if (upcoming.isNotEmpty) ...[
                _sectionTitle('Upcoming', isDark),
                const SizedBox(height: 8),
                ...upcoming.map((j) => _buildJobCard(context, j, isDark)),
                const SizedBox(height: 16),
              ],
              if (completed.isNotEmpty) ...[
                _sectionTitle('Completed', isDark),
                const SizedBox(height: 8),
                ...completed.map((j) => _buildJobCard(context, j, isDark)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: isDark ? AppTheme.darkTextSecondary : Colors.grey,
      ),
    );
  }

  Widget _buildJobCard(
    BuildContext context,
    DispatchedJob job,
    bool isDark,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      elevation: isDark ? 0 : 1,
      color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        onTap: () {
          Navigator.push(
            context,
            adaptivePageRoute(
              builder: (_) => EngineerJobDetailScreen(
                companyId: job.companyId,
                jobId: job.id,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      job.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  _priorityBadge(job.priority),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(AppIcons.location, size: 14, color: AppTheme.mediumGrey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${job.siteName} — ${job.siteAddress}',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.mediumGrey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _statusBadge(job.status),
                  const Spacer(),
                  if (job.scheduledDate != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(AppIcons.calendar, size: 14, color: AppTheme.mediumGrey),
                        const SizedBox(width: 4),
                        Text(
                          '${job.scheduledDate!.day}/${job.scheduledDate!.month}/${job.scheduledDate!.year}',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.mediumGrey,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(DispatchedJobStatus status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
    if (priority == JobPriority.normal) return const SizedBox.shrink();
    final isEmergency = priority == JobPriority.emergency;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (isEmergency ? Colors.red : Colors.orange).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isEmergency ? 'EMERGENCY' : 'URGENT',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isEmergency ? Colors.red : Colors.orange,
        ),
      ),
    );
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
