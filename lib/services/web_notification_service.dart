import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'user_profile_service.dart';

/// Web push notification service.
/// Handles permission, token registration, and foreground message display.
/// Mobile uses NotificationService instead.
class WebNotificationService {
  static final WebNotificationService instance = WebNotificationService._();
  WebNotificationService._();

  bool _permissionGranted = false;
  bool get permissionGranted => _permissionGranted;

  /// Whether the browser has permanently denied notifications (user must change in browser settings).
  bool _permissionDenied = false;
  bool get permissionDenied => _permissionDenied;

  bool _initialized = false;

  static const _vapidKey =
      'BOD5Er4TJjOYNRQAuUP2THRrpi8mJiWGjLbma14LO5tUxJRHN2TS4Rm4YvvmpuWOJ9BVMZ-50X6An2e3HznESf4';

  /// Callback for showing in-app foreground notifications.
  /// Set by the web shell or dashboard to display SnackBars.
  void Function(String title, String body, String? jobId)? onForegroundMessage;

  /// Call after login on web. Sets up listeners and checks existing permission.
  /// Does NOT prompt for permission — call [requestPermission] from a user gesture.
  Future<void> initialize(String companyId, String uid) async {
    if (!kIsWeb || _initialized) return;
    _initialized = true;

    try {
      // Check if permission was already granted (no prompt shown)
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      _permissionGranted =
          settings.authorizationStatus == AuthorizationStatus.authorized;
      _permissionDenied =
          settings.authorizationStatus == AuthorizationStatus.denied;

      if (_permissionGranted) {
        await _getAndStoreToken();
      }

      // Listen for token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        UserProfileService.instance.updateFcmToken(newToken);
      });

      // Foreground messages — show in-app toast instead of browser notification
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    } catch (e) {
      debugPrint('Web push: initialization failed: $e');
    }
  }

  /// Request notification permission. Must be called from a user gesture (button click).
  /// Returns true if permission was granted.
  Future<bool> requestPermission() async {
    if (!kIsWeb) return false;

    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      _permissionGranted =
          settings.authorizationStatus == AuthorizationStatus.authorized;
      _permissionDenied =
          settings.authorizationStatus == AuthorizationStatus.denied;

      if (_permissionGranted) {
        await _getAndStoreToken();
      } else {
        debugPrint('Web push: permission denied');
      }

      return _permissionGranted;
    } catch (e) {
      debugPrint('Web push: requestPermission failed: $e');
      return false;
    }
  }

  Future<void> _getAndStoreToken() async {
    final token = await FirebaseMessaging.instance.getToken(
      vapidKey: _vapidKey,
    );

    if (token != null) {
      await UserProfileService.instance.updateFcmToken(token);
      debugPrint('Web push: token stored');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final title = notification.title ?? 'FireThings';
    final body = notification.body ?? '';
    final jobId = message.data['jobId'] as String?;

    onForegroundMessage?.call(title, body, jobId);
  }

  /// Reset state on sign out.
  void reset() {
    _initialized = false;
    _permissionGranted = false;
    _permissionDenied = false;
    onForegroundMessage = null;
  }
}
