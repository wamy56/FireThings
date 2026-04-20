import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dispatched_job.dart';
import '../models/permission.dart';
import '../services/user_profile_service.dart';
import '../services/remote_config_service.dart';
import '../services/database_helper.dart';
import '../utils/theme.dart';
import '../utils/icon_map.dart';
import '../utils/adaptive_widgets.dart';
import '../screens/dispatch/dispatched_job_detail_screen.dart';
import '../screens/dispatch/engineer_job_detail_screen.dart';
import '../screens/invoicing/invoicing_hub_screen.dart';
import '../screens/new_job/jobsheet_drafts_screen.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell>
    with SingleTickerProviderStateMixin {
  static const _lastSeenKey = 'notification_feed_last_seen';
  static const _clearedAtKey = 'notification_feed_cleared_at';

  final _overlayController = OverlayPortalController();
  late final AnimationController _animController;
  double _bellBottom = 0;

  StreamSubscription<List<DispatchedJob>>? _dispatchSub;
  List<DispatchedJob> _dispatchJobs = [];
  List<_FeedItem> _localItems = [];
  int _unreadCount = 0;
  DateTime? _lastSeenAt;
  DateTime? _clearedAt;
  bool _isOpen = false;

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;
  String? get _companyId => UserProfileService.instance.companyId;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: AppTheme.normalAnimation,
    );
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSeenStr = prefs.getString(_lastSeenKey);
    final clearedAtStr = prefs.getString(_clearedAtKey);
    _lastSeenAt = lastSeenStr != null ? DateTime.tryParse(lastSeenStr) : null;
    _clearedAt = clearedAtStr != null ? DateTime.tryParse(clearedAtStr) : null;
    _subscribeToDispatch();
    await _loadLocalItems();
  }

  void _subscribeToDispatch() {
    final companyId = _companyId;
    if (companyId == null || !RemoteConfigService.instance.dispatchEnabled) {
      return;
    }

    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    final stream = FirebaseFirestore.instance
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

    _dispatchSub = stream.listen((jobs) {
      if (!mounted) return;
      _dispatchJobs = jobs;
      _updateUnreadCount();
    });
  }

  Future<void> _loadLocalItems() async {
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
            subtitle:
                '$count draft${count == 1 ? '' : 's'} waiting to be finished',
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
          count =
              sent.where((inv) => inv.dueDate.isBefore(DateTime.now())).length;
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

    if (mounted) {
      setState(() => _localItems = items);
      _updateUnreadCount();
    }
  }

  List<_FeedItem> _buildFilteredItems() {
    final uid = _currentUid;

    final dispatchItems = _dispatchJobs
        .where((job) => job.lastUpdatedBy != uid)
        .map((job) => _FeedItem(
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

    if (_clearedAt != null) {
      allItems.removeWhere((item) => item.timestamp.isBefore(_clearedAt!));
    }

    return allItems;
  }

  void _updateUnreadCount() {
    final items = _buildFilteredItems();
    final count = _lastSeenAt == null
        ? items.length
        : items.where((i) => i.timestamp.isAfter(_lastSeenAt!)).length;
    if (count != _unreadCount && mounted) {
      setState(() => _unreadCount = count);
    }
  }

  void _toggleFeed() {
    if (_isOpen) {
      _closeOverlay();
    } else {
      _openOverlay();
    }
  }

  Future<void> _openOverlay() async {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null) {
      final pos = box.localToGlobal(Offset.zero);
      _bellBottom = pos.dy + box.size.height;
    }
    await _loadLocalItems();
    _overlayController.show();
    _animController.forward();
    setState(() => _isOpen = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSeenKey, DateTime.now().toIso8601String());
    _lastSeenAt = DateTime.now();
    _unreadCount = 0;
    if (mounted) setState(() {});
  }

  void _closeOverlay() {
    _animController.reverse().then((_) {
      if (mounted) {
        _overlayController.hide();
        setState(() => _isOpen = false);
      }
    });
  }

  Future<void> _clearAll() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clearedAtKey, now.toIso8601String());
    setState(() {
      _clearedAt = now;
      _unreadCount = 0;
    });
  }

  void _onItemTap(_FeedItem item) {
    _closeOverlay();

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

  @override
  void dispose() {
    _dispatchSub?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isOpen) _closeOverlay();
      },
      child: OverlayPortal(
        controller: _overlayController,
        overlayChildBuilder: (_) => _buildOverlay(),
        child: IconButton(
          onPressed: _toggleFeed,
          tooltip: 'Notifications',
          icon: Badge(
            isLabelVisible: _unreadCount > 0,
            label: Text(
              _unreadCount > 9 ? '9+' : '$_unreadCount',
              style: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.bold),
            ),
            child: Icon(AppIcons.notification, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = _buildFilteredItems();

    final slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.02),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: AppTheme.defaultCurve,
    ));

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _closeOverlay,
      child: Stack(
        children: [
          Positioned.fill(
            child: FadeTransition(
              opacity: _animController,
              child: const ColoredBox(color: Colors.black26),
            ),
          ),
          Positioned(
            top: _bellBottom + 4,
            right: 16,
            child: GestureDetector(
              onTap: () {},
              child: FadeTransition(
                opacity: _animController,
                child: SlideTransition(
                  position: slideAnim,
                  child: _buildPanel(items, isDark),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanel(List<_FeedItem> items, bool isDark) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: isDark ? AppTheme.darkSurface : Colors.white,
      child: Container(
        width: screenWidth - 32 > 400 ? 400 : screenWidth - 32,
        constraints: BoxConstraints(maxHeight: screenHeight * 0.6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Text(
                    'Notifications',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : AppTheme.darkGrey,
                    ),
                  ),
                  const Spacer(),
                  if (items.isNotEmpty)
                    TextButton(
                      onPressed: _clearAll,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 32),
                      ),
                      child: Text(
                        'Clear All',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.mediumGrey,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: isDark ? AppTheme.darkDivider : AppTheme.dividerColor,
            ),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        AppIcons.notification,
                        size: 36,
                        color: isDark
                            ? AppTheme.darkTextHint
                            : AppTheme.textHint,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No recent notifications',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.mediumGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    indent: 56,
                    color:
                        isDark ? AppTheme.darkDivider : AppTheme.dividerColor,
                  ),
                  itemBuilder: (context, index) =>
                      _buildFeedItem(items[index], isDark),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedItem(_FeedItem item, bool isDark) {
    final unread = _lastSeenAt == null || item.timestamp.isAfter(_lastSeenAt!);

    return InkWell(
      onTap: () => _onItemTap(item),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
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
                      fontSize: 15,
                      fontWeight:
                          unread ? FontWeight.w600 : FontWeight.w400,
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textSecondary,
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
                    fontSize: 12,
                    color: isDark ? AppTheme.darkTextHint : AppTheme.textHint,
                  ),
                ),
                if (unread)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
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

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _statusLabel(DispatchedJobStatus status) {
    switch (status) {
      case DispatchedJobStatus.created:
        return 'Created';
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
