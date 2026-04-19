import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dispatched_job.dart';
import '../services/user_profile_service.dart';
import '../services/remote_config_service.dart';
import '../utils/icon_map.dart';
import '../utils/adaptive_widgets.dart';
import '../screens/notifications/notification_feed_screen.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  static const _lastSeenKey = 'notification_feed_last_seen';

  StreamSubscription<List<DispatchedJob>>? _dispatchSub;
  int _unreadCount = 0;
  DateTime? _lastSeenAt;

  @override
  void initState() {
    super.initState();
    _loadLastSeen();
  }

  Future<void> _loadLastSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSeenStr = prefs.getString(_lastSeenKey);
    _lastSeenAt = lastSeenStr != null ? DateTime.tryParse(lastSeenStr) : null;
    _subscribeToDispatch();
  }

  void _subscribeToDispatch() {
    final companyId = UserProfileService.instance.companyId;
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
      final count = _lastSeenAt == null
          ? jobs.length
          : jobs.where((j) => j.updatedAt.isAfter(_lastSeenAt!)).length;
      if (count != _unreadCount) {
        setState(() => _unreadCount = count);
      }
    });
  }

  @override
  void dispose() {
    _dispatchSub?.cancel();
    super.dispose();
  }

  Future<void> _openFeed() async {
    await Navigator.push(
      context,
      adaptivePageRoute(builder: (_) => const NotificationFeedScreen()),
    );
    // Refresh last seen after returning from feed
    final prefs = await SharedPreferences.getInstance();
    final lastSeenStr = prefs.getString(_lastSeenKey);
    setState(() {
      _lastSeenAt = lastSeenStr != null ? DateTime.tryParse(lastSeenStr) : null;
      _unreadCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: _openFeed,
      tooltip: 'Notifications',
      icon: Badge(
        isLabelVisible: _unreadCount > 0,
        label: Text(
          _unreadCount > 9 ? '9+' : '$_unreadCount',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
        child: Icon(AppIcons.notification, size: 22),
      ),
    );
  }
}
