import 'package:flutter/material.dart';
import '../../models/dispatched_job.dart';
import '../../services/dispatch_service.dart';
import '../../services/user_profile_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import 'create_job_screen.dart';
import 'dispatched_job_detail_screen.dart';

class DispatchDashboardScreen extends StatefulWidget {
  const DispatchDashboardScreen({super.key});

  @override
  State<DispatchDashboardScreen> createState() =>
      _DispatchDashboardScreenState();
}

class _DispatchDashboardScreenState extends State<DispatchDashboardScreen> {
  String? _statusFilter;

  String? get _companyId => UserProfileService.instance.companyId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final companyId = _companyId;

    if (companyId == null) {
      return const Center(child: Text('No company found'));
    }

    return Scaffold(
      body: Column(
        children: [
          _buildFilterBar(isDark),
          Expanded(
            child: StreamBuilder<List<DispatchedJob>>(
              stream: DispatchService.instance.getJobsStream(companyId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: AdaptiveLoadingIndicator());
                }

                final allJobs = snapshot.data ?? [];
                final jobs = _statusFilter == null
                    ? allJobs
                    : allJobs
                        .where((j) => _statusToString(j.status) == _statusFilter)
                        .toList();

                if (jobs.isEmpty) {
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
                          'No dispatched jobs',
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

                return _buildSummaryAndList(allJobs, jobs, isDark);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            adaptivePageRoute(builder: (_) => const CreateJobScreen()),
          );
        },
        child: Icon(AppIcons.add),
      ),
    );
  }

  Widget _buildSummaryAndList(
    List<DispatchedJob> allJobs,
    List<DispatchedJob> filteredJobs,
    bool isDark,
  ) {
    final unassigned =
        allJobs.where((j) => j.status == DispatchedJobStatus.created).length;
    final inProgress = allJobs
        .where((j) =>
            j.status == DispatchedJobStatus.accepted ||
            j.status == DispatchedJobStatus.enRoute ||
            j.status == DispatchedJobStatus.onSite)
        .length;
    final completedToday = allJobs
        .where((j) =>
            j.status == DispatchedJobStatus.completed &&
            j.completedAt != null &&
            _isToday(j.completedAt!))
        .length;
    final urgent = allJobs
        .where((j) =>
            j.priority != JobPriority.normal &&
            j.status != DispatchedJobStatus.completed)
        .length;

    return ListView(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      children: [
        // Summary cards
        Row(
          children: [
            _summaryCard('Unassigned', '$unassigned', Colors.orange, isDark),
            const SizedBox(width: 8),
            _summaryCard('In Progress', '$inProgress', Colors.blue, isDark),
            const SizedBox(width: 8),
            _summaryCard('Done Today', '$completedToday', AppTheme.successGreen, isDark),
            const SizedBox(width: 8),
            _summaryCard('Urgent', '$urgent', Colors.red, isDark),
          ],
        ),
        const SizedBox(height: 24),

        // Job list
        ...filteredJobs.map((job) => _buildJobCard(job, isDark)),
      ],
    );
  }

  Widget _summaryCard(
    String label,
    String count,
    Color color,
    bool isDark,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: color),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(bool isDark) {
    final filters = [
      null,
      'created',
      'assigned',
      'accepted',
      'en_route',
      'on_site',
      'completed',
      'declined',
    ];
    final labels = [
      'All',
      'Unassigned',
      'Assigned',
      'Accepted',
      'En Route',
      'On Site',
      'Completed',
      'Declined',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: List.generate(filters.length, (i) {
          final isSelected = _statusFilter == filters[i];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(labels[i]),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _statusFilter = filters[i]);
              },
              selectedColor: (isDark
                      ? AppTheme.darkPrimaryBlue
                      : AppTheme.primaryBlue)
                  .withValues(alpha: 0.2),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildJobCard(DispatchedJob job, bool isDark) {
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
              builder: (_) => DispatchedJobDetailScreen(
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
                  if (job.assignedToName != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(AppIcons.user, size: 14, color: AppTheme.mediumGrey),
                        const SizedBox(width: 4),
                        Text(
                          job.assignedToName!,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.mediumGrey,
                          ),
                        ),
                      ],
                    ),
                  if (job.scheduledDate != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (job.assignedToName != null)
                          const SizedBox(width: 12),
                        Icon(AppIcons.calendar, size: 14, color: AppTheme.mediumGrey),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(job.scheduledDate!),
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

  String _statusToString(DispatchedJobStatus status) {
    switch (status) {
      case DispatchedJobStatus.created:
        return 'created';
      case DispatchedJobStatus.assigned:
        return 'assigned';
      case DispatchedJobStatus.accepted:
        return 'accepted';
      case DispatchedJobStatus.enRoute:
        return 'en_route';
      case DispatchedJobStatus.onSite:
        return 'on_site';
      case DispatchedJobStatus.completed:
        return 'completed';
      case DispatchedJobStatus.declined:
        return 'declined';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}
