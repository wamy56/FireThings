import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../models/dispatched_job.dart';
import '../../services/user_profile_service.dart';
import '../../theme/web_theme.dart';
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
  DateTime? _clearedAt;

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
      case DispatchedJobStatus.created: return FtColors.accent;
      case DispatchedJobStatus.assigned: return FtColors.info;
      case DispatchedJobStatus.accepted: return const Color(0xFF0D9488);
      case DispatchedJobStatus.enRoute: return FtColors.primary;
      case DispatchedJobStatus.onSite: return const Color(0xFF7C3AED);
      case DispatchedJobStatus.completed: return FtColors.success;
      case DispatchedJobStatus.declined: return FtColors.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
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
            overlayChildBuilder: (context) => _buildOverlay(jobs),
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
                  color: FtColors.fg2,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverlay(List<DispatchedJob> allJobs) {
    final jobs = _clearedAt != null
        ? allJobs.where((j) => j.updatedAt.isAfter(_clearedAt!)).toList()
        : allJobs;

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
              onTap: () {},
              child: Container(
                width: 420,
                constraints: const BoxConstraints(maxHeight: 500),
                decoration: BoxDecoration(
                  color: FtColors.bg,
                  borderRadius: FtRadii.lgAll,
                  boxShadow: FtShadows.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                      child: Row(
                        children: [
                          Text(
                            'Recent Updates',
                            style: FtText.inter(size: 14, weight: FontWeight.w700, color: FtColors.fg1),
                          ),
                          const Spacer(),
                          if (jobs.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                setState(() => _clearedAt = DateTime.now());
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: FtColors.fg2,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                minimumSize: const Size(0, 32),
                              ),
                              child: Text(
                                'Clear',
                                style: FtText.inter(size: 12, color: FtColors.fg2),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: FtColors.border),
                    if (jobs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'No updates in the last 24 hours',
                            style: FtText.bodySoft,
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: jobs.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 1,
                            indent: 48,
                            color: FtColors.border,
                          ),
                          itemBuilder: (context, index) {
                            final job = jobs[index];
                            return _buildFeedItem(job);
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedItem(DispatchedJob job) {
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FtText.inter(size: 13, weight: FontWeight.w500, color: FtColors.fg1),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_statusLabel(job.status)}${job.assignedToName != null ? ' • ${job.assignedToName}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FtText.inter(size: 11, color: FtColors.hint),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _relativeTime(job.updatedAt),
              style: FtText.inter(size: 11, color: FtColors.hint),
            ),
          ],
        ),
      ),
    );
  }
}
