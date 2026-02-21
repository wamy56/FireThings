import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'database_helper.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  NotificationService._init();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Fixed notification IDs (replace, not stack)
  static const _draftInvoiceId = 1;
  static const _draftJobsheetId = 2;
  static const _overdueInvoiceId = 3;

  // SharedPreferences keys
  static const _lastNotifiedPrefix = 'lastNotifiedAt_';
  static const _draftRemindersKey = 'notif_draft_reminders';
  static const _overdueRemindersKey = 'notif_overdue_reminders';

  // Notification payloads for tap routing
  static const payloadDraftInvoice = 'draft_invoices';
  static const payloadDraftJobsheet = 'draft_jobsheets';
  static const payloadOverdueInvoice = 'overdue_invoices';

  /// Callback for handling notification taps — set by the UI layer
  static void Function(String payload)? onNotificationTap;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && onNotificationTap != null) {
          onNotificationTap!(payload);
        }
      },
    );

    // Create Android notification channel
    const channel = AndroidNotificationChannel(
      'firethings_reminders',
      'Reminders',
      description: 'Draft and overdue invoice reminders',
      importance: Importance.defaultImportance,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  Future<bool> requestPermission() async {
    // Android 13+
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }

    // iOS
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    return false;
  }

  /// Check SQLite for drafts/overdue and show notifications.
  /// Called from WorkManager background task and on app resume.
  Future<void> checkAndNotify() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(hours: 24));

    final draftRemindersOn = prefs.getBool(_draftRemindersKey) ?? true;
    final overdueRemindersOn = prefs.getBool(_overdueRemindersKey) ?? true;

    final db = DatabaseHelper.instance;

    // Draft invoices idle > 24h
    if (draftRemindersOn) {
      final draftInvoices = await db.getDraftInvoicesByEngineerId(user.uid);
      final stale = draftInvoices
          .where((inv) => inv.createdAt.isBefore(cutoff))
          .length;

      if (stale > 0 && _canNotify(prefs, 'draft_invoices', now)) {
        await _showNotification(
          _draftInvoiceId,
          'Draft invoices',
          'You have $stale draft invoice${stale == 1 ? '' : 's'} waiting to be finished',
          payloadDraftInvoice,
        );
        await prefs.setString(
            '${_lastNotifiedPrefix}draft_invoices', now.toIso8601String());
      }

      // Draft jobsheets idle > 24h
      final draftJobsheets =
          await db.getDraftJobsheetsByEngineerId(user.uid);
      final staleJs = draftJobsheets
          .where((js) => js.createdAt.isBefore(cutoff))
          .length;

      if (staleJs > 0 && _canNotify(prefs, 'draft_jobsheets', now)) {
        await _showNotification(
          _draftJobsheetId,
          'Unfinished jobsheets',
          'You have $staleJs unfinished jobsheet draft${staleJs == 1 ? '' : 's'}',
          payloadDraftJobsheet,
        );
        await prefs.setString(
            '${_lastNotifiedPrefix}draft_jobsheets', now.toIso8601String());
      }
    }

    // Overdue sent invoices
    if (overdueRemindersOn) {
      final sentInvoices =
          await db.getOutstandingInvoicesByEngineerId(user.uid);
      final overdue =
          sentInvoices.where((inv) => inv.dueDate.isBefore(now)).length;

      if (overdue > 0 && _canNotify(prefs, 'overdue_invoices', now)) {
        await _showNotification(
          _overdueInvoiceId,
          'Overdue invoices',
          'You have $overdue overdue invoice${overdue == 1 ? '' : 's'} \u2014 time to chase payment?',
          payloadOverdueInvoice,
        );
        await prefs.setString(
            '${_lastNotifiedPrefix}overdue_invoices', now.toIso8601String());
      }
    }
  }

  /// Returns true if at least 24h have passed since the last notification of this type.
  bool _canNotify(SharedPreferences prefs, String type, DateTime now) {
    final lastStr = prefs.getString('$_lastNotifiedPrefix$type');
    if (lastStr == null) return true;
    final last = DateTime.tryParse(lastStr);
    if (last == null) return true;
    return now.difference(last).inHours >= 24;
  }

  Future<void> _showNotification(
      int id, String title, String body, String payload) async {
    const androidDetails = AndroidNotificationDetails(
      'firethings_reminders',
      'Reminders',
      channelDescription: 'Draft and overdue invoice reminders',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(id, title, body, details, payload: payload);
  }
}
