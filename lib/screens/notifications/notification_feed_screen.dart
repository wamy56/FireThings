import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/dispatched_job.dart';
import '../../models/permission.dart';
import '../../services/user_profile_service.dart';
import '../../services/remote_config_service.dart';
import '../../services/database_helper.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/adaptive_app_bar.dart';
import '../../widgets/background_decoration.dart';
import '../dispatch/dispatched_job_detail_screen.dart';
import '../dispatch/engineer_job_detail_screen.dart';
import '../invoicing/invoicing_hub_screen.dart';
import '../new_job/jobsheet_drafts_screen.dart';

class NotificationFeedScreen extends StatefulWidget {
  const NotificationFeedScreen({super.key});

  @override
  State<NotificationFeedScreen> createState() => _NotificationFeedScreenState();
}

class _NotificationFeedScreenState extends State<NotificationFeedScreen> {
  static const _lastSeenKey = 'notification_feed_last_seen';

  DateTime? _lastSeenAt;
  List<_FeedItem> _localItems = [];
  bool _loadingLocal = true;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSeenStr = prefs.getString(_lastSeenKey);
    final lastSeen = lastSeenStr != null ? DateTime.tryParse(lastSeenStr) : null;

    final localItems = await _buildLocalReminderItems();

    setState(() {
      _lastSeenAt = lastSeen;
      _localItems = localItems;
      _loadingLocal = false;
    });

    // Mark as seen now
    await prefs.setString(_lastSeenKey, DateTime.now().toIso8601String());
  }

  Future<List<_FeedItem>> _buildLocalReminderItems() async {
    final items = <_FeedItem>[];
    final prefs = await SharedPreferences.getInstance();

    final draftInvoiceStr = prefs.getString('lastNotifiedAt_draft_invoices');
    if (draftInvoiceStr != null) {
      final dt = DateTime.tryParse(draftInvoiceStr);
      if (dt != null && DateTime.now().difference(dt).inHours < 48) {
        final user = FirebaseAuth.instance.currentUser;
        int count = 0;
        if (user != null) {
          final drafts = await DatabaseHelper.instance
              .getDraftInvoicesByEngineerId(user.uid);
          count = drafts.length;
        }
        if (count > 0) {
          items.add(_FeedItem(
            type: _FeedItemType.draftInvoice,
            title: 'Draft invoices',
            subtitle: '$count draft${count == 1 ? '' : 's'} waiting to be finished',
            timestamp: dt,
            icon: AppIcons.receiptOutline,
            color: AppTheme.warningOrange,
          ));
        }
      }
    }

    final draftJobsheetStr = prefs.getString('lastNotifiedAt_draft_jobsheets');
    if (draftJobsheetStr != null) {
      final dt = DateTime.tryParse(draftJobsheetStr);
      if (dt != null && DateTime.now().difference(dt).inHours < 48) {
        final user = FirebaseAuth.instance.currentUser;
        int count = 0;
        if (user != null) {
          final drafts = await DatabaseHelper.instance
              .getDraftJobsheetsByEngineerId(user.uid);
          count = drafts.length;
        }
        if (count > 0) {
          items.add(_FeedItem(
            type: _FeedItemType.draftJobsheet,
            title: 'Unfinished jobsheets',
            subtitle: '$count draft${count == 1 ? '' : 's'} to complete',
            timestamp: dt,
            icon: AppIcons.briefcaseOutline,
            color: AppTheme.primaryBlue,
          ));
        }
      }
    }

    final overdueStr = prefs.getString('lastNotifiedAt_overdue_invoices');
    if (overdueStr != null) {
      final dt = DateTime.tryParse(overdueStr);
      if (dt != null && DateTime.now().difference(dt).inHours < 48) {
        final user = FirebaseAuth.instance.currentUser;
        int count = 0;
        if (user != null) {
          final sent = await DatabaseHelper.instance
              .getOutstandingInvoicesByEngineerId(user.uid);
          count = sent.where((inv) => inv.dueDate.isBefore(DateTime.now())).length;
        }
        if (count > 0) {
          items.add(_FeedItem(
            type: _FeedItemType.overdueInvoice,
            title: 'Overdue invoices',
            subtitle: '$count overdue \u2014 time to chase payment?',
            timestamp: dt,
            icon: AppIcons.warning,
            color: AppTheme.errorRed,
          ));
        }
      }
    }

    return items;
  }

  String? get _companyId => UserProfileService.instance.companyId;

  Stream<List<DispatchedJob>>? _recentJobsStream() {
    final companyId = _companyId;
    if (companyId == null || !RemoteConfigService.instance.dispatchEnabled) {
      return null;
    }

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

  bool _isUnread(DateTime timestamp) {
    if (_lastSeenAt == null) return true;
    return timestamp.isAfter(_lastSeenAt!);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stream = _recentJobsStream();

    return Scaffold(
      appBar: AdaptiveNavigationBar(title: 'Notifications'),
      body: Stack(
        children: [
          const BackgroundDecoration(),
          _loadingLocal
              ? const Center(child: AdaptiveLoadingIndicator())
              : stream != null
                  ? StreamBuilder<List<DispatchedJob>>(
                      stream: stream,
                      builder: (context, snapshot) {
                        final dispatchJobs = snapshot.data ?? [];
                        return _buildList(dispatchJobs, isDark);
                      },
                    )
                  : _buildList([], isDark),
        ],
      ),
    );
  }

  Widget _buildList(List<DispatchedJob> dispatchJobs, bool isDark) {
    final dispatchItems = dispatchJobs.map((job) => _FeedItem(
      type: _FeedItemType.dispatch,
      title: job.title,
      subtitle: '${_statusLabel(job.status)}'
          '${job.assignedToName != null ? ' \u2022 ${job.assignedToName}' : ''}',
      timestamp: job.updatedAt,
      icon: AppIcons.taskOutline,
      color: _statusColor(job.status),
      dispatchJob: job,
    ));

    final allItems = [...dispatchItems, ..._localItems]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (allItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              AppIcons.notification,
              size: 48,
              color: isDark ? AppTheme.darkTextHint : AppTheme.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              'No recent notifications',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Dispatch updates and reminders will appear here',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppTheme.darkTextHint : AppTheme.textHint,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.screenPadding,
        vertical: 12,
      ),
      itemCount: allItems.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        indent: 52,
        color: isDark ? AppTheme.darkDivider : AppTheme.dividerColor,
      ),
      itemBuilder: (context, index) => _buildFeedItem(allItems[index], isDark),
    );
  }

  Widget _buildFeedItem(_FeedItem item, bool isDark) {
    final unread = _isUnread(item.timestamp);

    return InkWell(
      onTap: () => _onItemTap(item),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, size: 20, color: item.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _relativeTime(item.timestamp),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppTheme.darkTextHint : AppTheme.textHint,
                  ),
                ),
                if (unread)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryBlue,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onItemTap(_FeedItem item) {
    switch (item.type) {
      case _FeedItemType.dispatch:
        final profile = UserProfileService.instance;
        final job = item.dispatchJob;
        if (job == null) return;
        final companyId = _companyId;
        if (companyId == null) return;

        if (profile.hasPermission(AppPermission.dispatchViewAll)) {
          Navigator.push(
            context,
            adaptivePageRoute(
              builder: (_) => DispatchedJobDetailScreen(
                jobId: job.id,
                companyId: companyId,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            adaptivePageRoute(
              builder: (_) => EngineerJobDetailScreen(
                jobId: job.id,
                companyId: companyId,
              ),
            ),
          );
        }
      case _FeedItemType.draftInvoice:
      case _FeedItemType.overdueInvoice:
        Navigator.push(
          context,
          adaptivePageRoute(builder: (_) => const InvoicingHubScreen()),
        );
      case _FeedItemType.draftJobsheet:
        Navigator.push(
          context,
          adaptivePageRoute(builder: (_) => const JobsheetDraftsScreen()),
        );
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
}

enum _FeedItemType { dispatch, draftInvoice, draftJobsheet, overdueInvoice }

class _FeedItem {
  final _FeedItemType type;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final IconData icon;
  final Color color;
  final DispatchedJob? dispatchJob;

  const _FeedItem({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.icon,
    required this.color,
    this.dispatchJob,
  });
}
