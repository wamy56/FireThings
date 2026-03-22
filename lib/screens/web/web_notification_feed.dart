import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../models/dispatched_job.dart';
import '../../services/user_profile_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';

/// Notification bell icon with unread count badge and dropdown feed.
/// Shows recently updated dispatched jobs from the last 24 hours.
class WebNotificationFeed extends StatefulWidget {
  const WebNotificationFeed({super.key});

  @override
  State<WebNotificationFeed> createState() => _WebNotificationFeedState();
}

class _WebNotificationFeedState extends State<WebNotificationFeed> {
  final _overlayController = OverlayPortalController();
  final _layerLink = LayerLink();
  DateTime? _lastSeenAt;

  String? get _companyId => UserProfileService.instance.companyId;

  Stream<List<DispatchedJob>>? _recentJobsStream() {
    final companyId = _companyId;
    if (companyId == null) return null;

    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    return FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('dispatched_jobs')
        .where('updatedAt', isGreaterThan: cutoff.toIso8601String())
        .orderBy('updatedAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => DispatchedJob.fromJson(doc.data()))
            .toList());
  }

  int _unreadCount(List<DispatchedJob> jobs) {
    if (_lastSeenAt == null) return jobs.length;
    return jobs.where((j) => j.updatedAt.isAfter(_lastSeenAt!)).length;
  }

  void _toggleFeed() {
    if (_overlayController.isShowing) {
      _overlayController.hide();
    } else {
      _overlayController.show();
      setState(() => _lastSeenAt = DateTime.now());
    }
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _statusLabel(DispatchedJobStatus status) {
    switch (status) {
      case DispatchedJobStatus.created: return 'Created';
      case DispatchedJobStatus.assigned: return 'Assigned';
      case DispatchedJobStatus.accepted: return 'Accepted';
      case DispatchedJobStatus.enRoute: return 'En Route';
      case DispatchedJobStatus.onSite: return 'On Site';
      case DispatchedJobStatus.completed: return 'Completed';
      case DispatchedJobStatus.declined: return 'Declined';
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stream = _recentJobsStream();

    if (stream == null) return const SizedBox.shrink();

    return StreamBuilder<List<DispatchedJob>>(
      stream: stream,
      builder: (context, snapshot) {
        final jobs = snapshot.data ?? [];
        final unread = _unreadCount(jobs);

        return CompositedTransformTarget(
          link: _layerLink,
          child: OverlayPortal(
            controller: _overlayController,
            overlayChildBuilder: (context) => _buildOverlay(jobs, isDark),
            child: IconButton(
              onPressed: _toggleFeed,
              tooltip: 'Notifications',
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text(
                  unread > 9 ? '9+' : '$unread',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
                child: Icon(
                  AppIcons.notification,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverlay(List<DispatchedJob> jobs, bool isDark) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => _overlayController.hide(),
      child: Stack(
        children: [
          CompositedTransformFollower(
            link: _layerLink,
            targetAnchor: Alignment.bottomRight,
            followerAnchor: Alignment.topRight,
            offset: const Offset(0, 4),
            child: GestureDetector(
              onTap: () {}, // Prevent closing when tapping inside
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                color: isDark ? AppTheme.darkSurface : Colors.white,
                child: Container(
                  width: 360,
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Text(
                          'Recent Updates',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDark ? Colors.white : AppTheme.darkGrey,
                          ),
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: isDark ? AppTheme.darkDivider : AppTheme.dividerColor,
                      ),
                      if (jobs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'No updates in the last 24 hours',
                              style: TextStyle(
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        )
                      else
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: jobs.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              indent: 48,
                              color: isDark ? AppTheme.darkDivider : AppTheme.dividerColor,
                            ),
                            itemBuilder: (context, index) {
                              final job = jobs[index];
                              return _buildFeedItem(job, isDark);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedItem(DispatchedJob job, bool isDark) {
    final color = _statusColor(job.status);

    return InkWell(
      onTap: () {
        _overlayController.hide();
        context.go('/jobs/${job.id}');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Status icon
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(AppIcons.taskOutline, size: 16, color: color),
            ),
            const SizedBox(width: 10),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : AppTheme.darkGrey,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_statusLabel(job.status)}${job.assignedToName != null ? ' • ${job.assignedToName}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Time
            Text(
              _relativeTime(job.updatedAt),
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppTheme.darkTextHint : AppTheme.mediumGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
