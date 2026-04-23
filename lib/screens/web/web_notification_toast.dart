import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/web_theme.dart';
import '../../utils/icon_map.dart';

class _ToastEntry {
  final String title;
  final String body;
  final String? jobId;
  final DateTime createdAt;
  final AnimationController controller;

  _ToastEntry({
    required this.title,
    required this.body,
    this.jobId,
    required this.createdAt,
    required this.controller,
  });
}

/// Manages a stack of slide-in toast notifications in the top-right corner.
class WebNotificationToastManager extends StatefulWidget {
  final Widget child;

  const WebNotificationToastManager({super.key, required this.child});

  static WebNotificationToastManagerState? of(BuildContext context) {
    return context.findAncestorStateOfType<WebNotificationToastManagerState>();
  }

  @override
  State<WebNotificationToastManager> createState() =>
      WebNotificationToastManagerState();
}

class WebNotificationToastManagerState
    extends State<WebNotificationToastManager> with TickerProviderStateMixin {
  final List<_ToastEntry> _toasts = [];
  static const _maxToasts = 3;
  static const _autoDismissDuration = Duration(seconds: 5);
  static const _animDuration = Duration(milliseconds: 300);

  void showToast(String title, String body, String? jobId) {
    // Remove oldest if at max
    if (_toasts.length >= _maxToasts) {
      _dismissToast(_toasts.first);
    }

    final controller = AnimationController(
      vsync: this,
      duration: _animDuration,
    );

    final entry = _ToastEntry(
      title: title,
      body: body,
      jobId: jobId,
      createdAt: DateTime.now(),
      controller: controller,
    );

    setState(() => _toasts.add(entry));
    controller.forward();

    // Auto-dismiss after 5 seconds
    Future.delayed(_autoDismissDuration, () {
      if (_toasts.contains(entry)) {
        _dismissToast(entry);
      }
    });
  }

  void _dismissToast(_ToastEntry entry) {
    entry.controller.reverse().then((_) {
      if (mounted) {
        setState(() => _toasts.remove(entry));
        entry.controller.dispose();
      }
    });
  }

  @override
  void dispose() {
    for (final toast in _toasts) {
      toast.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 64,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: _toasts
                .map((entry) => _buildToastCard(entry))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildToastCard(_ToastEntry entry) {
    final animation = CurvedAnimation(
      parent: entry.controller,
      curve: Curves.easeOutCubic,
    );

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(animation),
      child: FadeTransition(
        opacity: animation,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            width: 340,
            decoration: BoxDecoration(
              color: FtColors.bg,
              borderRadius: FtRadii.lgAll,
              boxShadow: FtShadows.lg,
              border: Border(
                left: BorderSide(
                  color: FtColors.accent,
                  width: 4,
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: FtColors.accentSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    AppIcons.notification,
                    size: 18,
                    color: FtColors.accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FtText.inter(size: 13, weight: FontWeight.w600, color: FtColors.fg1),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: FtText.inter(size: 12, color: FtColors.hint),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                if (entry.jobId != null)
                  TextButton(
                    onPressed: () {
                      _dismissToast(entry);
                      context.go('/jobs/${entry.jobId}');
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: FtColors.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                    ),
                    child: Text('View', style: FtText.inter(size: 12, color: FtColors.accent)),
                  ),
                IconButton(
                  onPressed: () => _dismissToast(entry),
                  icon: Icon(AppIcons.close, size: 14, color: FtColors.fg2),
                  iconSize: 14,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
