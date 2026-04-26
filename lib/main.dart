import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'services/analytics_service.dart';
import 'services/auth_service.dart';
import 'services/remote_config_service.dart';
import 'services/firestore_sync_service.dart';
import 'services/user_profile_service.dart';
import 'models/permission.dart';
import 'utils/theme.dart';
import 'utils/theme_style.dart';
import 'utils/responsive.dart';
import 'utils/adaptive_widgets.dart';
import 'utils/icon_map.dart';
import 'services/pdf_widgets/pdf_font_registry.dart';
import 'widgets/adaptive_app_bar.dart';

// Mobile-only imports — only used behind !kIsWeb guards at runtime.
// On web builds, these files are included in the compile but the code
// paths that reference them are dead-code eliminated via kIsWeb.
import 'package:workmanager/workmanager.dart';
import 'services/template_service.dart';
import 'services/notification_service.dart';
import 'services/dispatch_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/new_job/jobsheet_drafts_screen.dart';
import 'screens/invoicing/invoicing_hub_screen.dart';
import 'screens/jobs/jobs_hub_screen.dart';
import 'screens/dispatch/dispatch_dashboard_screen.dart';
import 'screens/dispatch/dispatched_job_detail_screen.dart';
import 'screens/dispatch/engineer_job_detail_screen.dart';
import 'screens/dispatch/engineer_jobs_screen.dart';
import 'screens/dispatch/dispatch_empty_screen.dart';
import 'screens/quoting/quoting_hub_screen.dart';
import 'widgets/notification_bell.dart';

// Web-only imports
import 'package:go_router/go_router.dart';
import 'screens/web/web_router.dart';

/// Global navigator key for notification-driven navigation (mobile only).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Global theme mode notifier — allows toggling light/dark/system from anywhere.
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

/// Load persisted theme preference from SharedPreferences.
Future<void> _loadThemePreference() async {
  final prefs = await SharedPreferences.getInstance();
  final value = prefs.getString('theme_mode');
  if (value == 'light') {
    themeNotifier.value = ThemeMode.light;
  } else if (value == 'dark') {
    themeNotifier.value = ThemeMode.dark;
  }
}

/// Persist theme preference to SharedPreferences.
Future<void> saveThemePreference(ThemeMode mode) async {
  final prefs = await SharedPreferences.getInstance();
  switch (mode) {
    case ThemeMode.light:
      await prefs.setString('theme_mode', 'light');
    case ThemeMode.dark:
      await prefs.setString('theme_mode', 'dark');
    case ThemeMode.system:
      await prefs.remove('theme_mode');
  }
}

/// Handle FCM messages received while the app is in the background.
/// Must be a top-level function.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('FCM background message: ${message.messageId}');
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await NotificationService.instance.initialize();
    await NotificationService.instance.checkAndNotify();
    return true;
  });
}

void main() {
  runZonedGuarded(
    () async {
      // Ensure Flutter is initialized (must be in same zone as runApp)
      WidgetsFlutterBinding.ensureInitialized();

      // Initialize Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Disable Firestore offline persistence on web — the JS SDK has a
      // long-standing "INTERNAL ASSERTION FAILED: Unexpected state" bug
      // (firebase-js-sdk issues #4451, #7884, #8250) that's triggered by
      // the IndexedDB persistence layer interacting with multiple stream
      // subscriptions. Mobile/desktop are unaffected and keep full persistence.
      FirebaseFirestore.instance.settings = Settings(
        persistenceEnabled: !kIsWeb,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      // Initialize Remote Config
      await RemoteConfigService.instance.initialize();

      // Load persisted theme preferences
      await _loadThemePreference();
      await loadThemeStylePreference();

      await PdfFontRegistry.instance.ensureLoaded();

      // Mobile-only initialization
      if (!kIsWeb) {
        // Register FCM background handler (must be before any FCM usage)
        FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler,
        );

        // Request FCM notification permission (iOS primarily, Android 13+)
        await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );

        // Set up Crashlytics error handlers
        FlutterError.onError =
            FirebaseCrashlytics.instance.recordFlutterFatalError;
        PlatformDispatcher.instance.onError = (error, stack) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
          return true;
        };

        // Load custom templates from database (SQLite)
        await TemplateService.instance.loadCustomTemplates();

        // Initialize notifications
        await NotificationService.instance.initialize();

        // Register periodic background check
        await Workmanager().initialize(callbackDispatcher);
        await Workmanager().registerPeriodicTask(
          'draft-reminder-check',
          'checkDraftsAndOverdue',
          frequency: const Duration(hours: 12),
          constraints: Constraints(networkType: NetworkType.notRequired),
        );
      }

      runApp(const JobsheetApp());
    },
    (error, stack) {
      if (!kIsWeb) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      }
    },
  );
}

class JobsheetApp extends StatefulWidget {
  const JobsheetApp({super.key});

  @override
  State<JobsheetApp> createState() => _JobsheetAppState();
}

class _JobsheetAppState extends State<JobsheetApp> {
  late final GoRouter? _webRouter;

  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(_onThemeChanged);
    themeStyleNotifier.addListener(_onThemeChanged);
    _webRouter = kIsWeb ? createWebRouter() : null;
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onThemeChanged);
    themeStyleNotifier.removeListener(_onThemeChanged);
    _webRouter?.dispose();
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    // Web: use GoRouter for proper URL routing
    if (kIsWeb) {
      final isSiteOps = themeStyleNotifier.value == ThemeStyle.siteOps;
      return MaterialApp.router(
        title: 'FireThings - Dispatcher Portal',
        debugShowCheckedModeBanner: false,
        routerConfig: _webRouter!,
        theme: isSiteOps ? AppTheme.siteOpsTheme : AppTheme.lightTheme,
        darkTheme: isSiteOps ? AppTheme.siteOpsTheme : AppTheme.darkTheme,
        themeMode: isSiteOps ? ThemeMode.dark : themeNotifier.value,
        builder: (context, child) {
          final scale = AppTheme.responsiveTextScale(context.screenSize);
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          );
        },
      );
    }

    // Mobile: use standard Navigator with AuthWrapper
    final isSiteOps = themeStyleNotifier.value == ThemeStyle.siteOps;
    return MaterialApp(
      title: 'FireThings',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      navigatorObservers: [AnalyticsService.instance.observer],
      theme: isSiteOps ? AppTheme.siteOpsTheme : AppTheme.lightTheme,
      darkTheme: isSiteOps ? AppTheme.siteOpsTheme : AppTheme.darkTheme,
      themeMode: isSiteOps ? ThemeMode.dark : themeNotifier.value,
      builder: (context, child) {
        final scale = AppTheme.responsiveTextScale(context.screenSize);
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        );
      },
      home: const AuthWrapper(),
    );
  }
}

/// Wrapper that shows login or main screen based on auth state.
/// Also manages FCM token registration and notification listeners.
/// Used on mobile only — web uses GoRouter with auth redirect.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundMessageSub;
  StreamSubscription<RemoteMessage>? _messageOpenedSub;
  late final AuthService _authService;
  late final Stream<User?> _authStream;
  String? _lastSetupUid;
  bool _postLoginReady = false;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _authStream = _authService.authStateChanges;
  }

  @override
  void dispose() {
    _tokenRefreshSub?.cancel();
    _foregroundMessageSub?.cancel();
    _messageOpenedSub?.cancel();
    super.dispose();
  }

  /// Set up FCM token and notification listeners after login.
  Future<void> _setupFcm(String uid) async {
    if (!RemoteConfigService.instance.dispatchNotificationsEnabled) return;

    // Get and store the current FCM token
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await UserProfileService.instance.updateFcmToken(token);
      }
    } catch (e) {
      debugPrint('FCM: failed to get token: $e');
    }

    // Listen for token refresh
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((
      newToken,
    ) {
      UserProfileService.instance.updateFcmToken(newToken);
    });

    // Foreground messages — re-fire as local notification
    _foregroundMessageSub?.cancel();
    _foregroundMessageSub = FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );

    // Background/terminated tap — user tapped notification while app was in background
    _messageOpenedSub?.cancel();
    _messageOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleMessageOpenedApp,
    );

    // Check if app was opened from terminated state via notification tap
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      // Slight delay to let the navigator settle
      Future.delayed(const Duration(milliseconds: 500), () {
        _navigateToJobFromMessage(initialMessage.data);
      });
    }
  }

  /// Show a local notification for FCM messages received while app is in foreground.
  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final data = message.data;
    final payload =
        '${data['type'] ?? ''}|${data['jobId'] ?? ''}|${data['companyId'] ?? ''}';

    NotificationService.instance.showDispatchNotification(
      title: notification.title ?? 'FireThings',
      body: notification.body ?? '',
      payload: payload,
    );
  }

  /// Navigate to job detail when user taps a notification (background state).
  void _handleMessageOpenedApp(RemoteMessage message) {
    _navigateToJobFromMessage(message.data);
  }

  /// Parse FCM data payload and navigate to the appropriate dispatch job screen.
  void _navigateToJobFromMessage(Map<String, dynamic> data) {
    final jobId = data['jobId'] as String?;
    final companyId = data['companyId'] as String?;
    if (jobId == null || companyId == null) return;

    final nav = navigatorKey.currentState;
    if (nav == null) return;

    final profile = UserProfileService.instance;
    final canViewFull = profile.hasPermission(AppPermission.dispatchViewAll) ||
        profile.hasPermission(AppPermission.dispatchEdit);
    if (canViewFull) {
      nav.push(
        MaterialPageRoute(
          builder: (_) =>
              DispatchedJobDetailScreen(companyId: companyId, jobId: jobId),
        ),
      );
    } else {
      nav.push(
        MaterialPageRoute(
          builder: (_) =>
              EngineerJobDetailScreen(companyId: companyId, jobId: jobId),
        ),
      );
    }
  }

  void _teardownFcm() {
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    _foregroundMessageSub?.cancel();
    _foregroundMessageSub = null;
    _messageOpenedSub?.cancel();
    _messageOpenedSub = null;
  }

  /// Run post-login setup once per user, then trigger rebuild so
  /// MainNavigationScreen picks up dispatch flag changes.
  Future<void> _runPostLoginSetup(User user) async {
    // FirestoreSyncService uses SQLite — skip on web
    if (!kIsWeb) {
      FirestoreSyncService.instance.performFullSync(user.uid);
    }
    await UserProfileService.instance.loadProfile(user.uid);
    await RemoteConfigService.instance.refreshForUser(user.email);
    if (mounted) {
      _postLoginReady = true;
      setState(() {});
    }
    // FCM setup is non-blocking — run after UI is ready
    if (!kIsWeb) {
      _setupFcm(user.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _authStream,
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(child: AdaptiveLoadingIndicator(size: 32)),
          );
        }

        // Show main screen if logged in, login screen if not
        if (snapshot.hasData) {
          final user = snapshot.data!;
          if (_lastSetupUid != user.uid) {
            _lastSetupUid = user.uid;
            _postLoginReady = false;
            _runPostLoginSetup(user);
          }
          if (!_postLoginReady) {
            return Scaffold(
              body: Center(child: AdaptiveLoadingIndicator(size: 32)),
            );
          }
          return const MainNavigationScreen();
        } else {
          _lastSetupUid = null;
          _postLoginReady = false;
          _teardownFcm();
          UserProfileService.instance.clearProfile();
          return const LoginScreen();
        }
      },
    );
  }
}

/// Main screen with adaptive bottom navigation (mobile only)
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  int _previousIndex = 0;
  StreamSubscription<int>? _dispatchBadgeSub;
  int _dispatchBadgeCount = 0;

  Widget _maybeBadgedIcon(int index, IconData icon, {Color? color}) {
    final child = Icon(icon, color: color);
    if (index == 4 && _dispatchBadgeCount > 0) {
      return Badge(
        label: Text(
          _dispatchBadgeCount > 9 ? '9+' : '$_dispatchBadgeCount',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
        child: child,
      );
    }
    return child;
  }

  List<String> get _titles => const [
    'Home',
    'Jobs',
    'Invoices',
    'Quotes',
    'Dispatch',
  ];

  void _switchTab(int newIndex) {
    if (newIndex == _currentIndex) return;
    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex = newIndex;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Set up notification tap routing (mobile only)
    if (!kIsWeb) {
      NotificationService.onNotificationTap = _handleNotificationTap;
    }

    _subscribeToDispatchBadge();
    UserProfileService.instance.addListener(_onPermissionsChanged);
  }

  void _onPermissionsChanged() {
    if (!mounted) return;
    _dispatchBadgeSub?.cancel();
    _subscribeToDispatchBadge();
    setState(() {});
  }

  void _subscribeToDispatchBadge() {
    if (!RemoteConfigService.instance.dispatchEnabled) return;

    final companyId = UserProfileService.instance.companyId;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (companyId == null || uid == null) return;

    final profile = UserProfileService.instance;
    final hasManagementAccess =
        profile.hasPermission(AppPermission.dispatchViewAll) ||
        profile.hasPermission(AppPermission.dispatchCreate) ||
        profile.hasPermission(AppPermission.dispatchEdit) ||
        profile.hasPermission(AppPermission.dispatchDelete);

    final Stream<int> countStream;
    if (hasManagementAccess) {
      countStream =
          DispatchService.instance.streamUnassignedJobCount(companyId);
    } else {
      countStream =
          DispatchService.instance.streamPendingJobCount(companyId, uid);
    }

    _dispatchBadgeSub = countStream.listen((jobCount) {
      if (mounted && jobCount != _dispatchBadgeCount) {
        setState(() => _dispatchBadgeCount = jobCount);
      }
    });
  }

  @override
  void dispose() {
    UserProfileService.instance.removeListener(_onPermissionsChanged);
    _dispatchBadgeSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (!kIsWeb) {
      NotificationService.onNotificationTap = null;
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !kIsWeb) {
      NotificationService.instance.checkAndNotify();
    }
  }

  void _handleNotificationTap(String payload) {
    // Check for dispatch notification payload (format: type|jobId|companyId)
    if (payload.contains('|')) {
      final parts = payload.split('|');
      if (parts.length >= 3) {
        final jobId = parts[1];
        final companyId = parts[2];
        if (jobId.isNotEmpty && companyId.isNotEmpty) {
          final profile = UserProfileService.instance;
          final canViewFull = profile.hasPermission(AppPermission.dispatchViewAll) ||
              profile.hasPermission(AppPermission.dispatchEdit);
          if (canViewFull) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DispatchedJobDetailScreen(
                  companyId: companyId,
                  jobId: jobId,
                ),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    EngineerJobDetailScreen(companyId: companyId, jobId: jobId),
              ),
            );
          }
          return;
        }
      }
    }

    switch (payload) {
      case NotificationService.payloadDraftInvoice:
      case NotificationService.payloadOverdueInvoice:
        // Navigate to Invoices tab
        _switchTab(2);
        break;
      case NotificationService.payloadDraftJobsheet:
        // Navigate to Jobsheet Drafts screen
        Navigator.push(
          context,
          adaptivePageRoute(builder: (_) => const JobsheetDraftsScreen()),
        );
        break;
    }
  }

  Widget get _dispatchScreen {
    final rc = RemoteConfigService.instance;
    final profile = UserProfileService.instance;
    if (!rc.dispatchEnabled || !profile.hasCompany) {
      return const DispatchEmptyScreen();
    }

    final hasAnyDispatchAccess =
        profile.hasPermission(AppPermission.dispatchViewAll) ||
        profile.hasPermission(AppPermission.dispatchCreate) ||
        profile.hasPermission(AppPermission.dispatchEdit) ||
        profile.hasPermission(AppPermission.dispatchDelete);

    if (hasAnyDispatchAccess) {
      return const DispatchDashboardScreen();
    }
    return const EngineerJobsScreen();
  }

  List<Widget> get _screens => [
    HomeScreen(onSwitchTab: _switchTab),
    const JobsHubScreen(),
    const InvoicingHubScreen(),
    const QuotingHubScreen(),
    _dispatchScreen,
  ];

  List<IconData> get _navIcons => const [
    AppIcons.homeOutline,
    AppIcons.briefcaseOutline,
    AppIcons.receiptOutline,
    AppIcons.receiptEditOutline,
    AppIcons.taskOutline,
  ];

  List<IconData> get _navSelectedIcons => const [
    AppIcons.homeBold,
    AppIcons.briefcaseBold,
    AppIcons.receiptBold,
    AppIcons.receiptEditBold,
    AppIcons.taskBold,
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenSize = context.screenSize;
    final useRail = screenSize != ScreenSize.compact;

    final titles = _titles;
    final screens = _screens;
    final navIcons = _navIcons;
    final navSelectedIcons = _navSelectedIcons;
    // Clamp index in case dispatch tab was removed
    final safeIndex = _currentIndex.clamp(0, screens.length - 1);
    if (safeIndex != _currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _currentIndex = safeIndex);
      });
    }

    final body = Scaffold(
      appBar: AdaptiveNavigationBar(
        title: titles[safeIndex],
        actions: [
          const NotificationBell(),
          IconButton(
            icon: Icon(AppIcons.settingOutline, size: 22),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              adaptivePageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity > 300 && _currentIndex > 0) {
            _switchTab(_currentIndex - 1);
          } else if (velocity < -300 && _currentIndex < screens.length - 1) {
            _switchTab(_currentIndex + 1);
          }
        },
        child: AnimatedSwitcher(
          duration: AppTheme.normalAnimation,
          switchInCurve: AppTheme.defaultCurve,
          switchOutCurve: AppTheme.defaultCurve,
          transitionBuilder: (child, animation) {
            final key = child.key as ValueKey<int>;
            final isIncoming = key.value == _currentIndex;
            final goingRight = _currentIndex > _previousIndex;

            final offset = Tween<Offset>(
              begin: Offset(
                isIncoming
                    ? (goingRight ? 1.0 : -1.0)
                    : (goingRight ? -1.0 : 1.0),
                0,
              ),
              end: Offset.zero,
            ).animate(animation);

            return SlideTransition(position: offset, child: child);
          },
          child: KeyedSubtree(
            key: ValueKey(safeIndex),
            child: screens[safeIndex],
          ),
        ),
      ),
      bottomNavigationBar: useRail
          ? null
          : PlatformUtils.isApple
          ? _buildCupertinoNavBar(
              isDark,
              navIcons,
              navSelectedIcons,
              titles,
              screens.length,
            )
          : _buildMaterialNavBar(
              isDark,
              navIcons,
              navSelectedIcons,
              titles,
              screens.length,
            ),
    );

    if (!useRail) return body;

    final primaryColor = isDark
        ? AppTheme.darkPrimaryBlue
        : AppTheme.primaryBlue;
    final unselectedColor = isDark
        ? AppTheme.darkTextSecondary
        : AppTheme.mediumGrey;
    final railBg = isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite;
    final extended =
        screenSize == ScreenSize.expanded || screenSize == ScreenSize.large;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _currentIndex,
            onDestinationSelected: _switchTab,
            extended: extended,
            backgroundColor: railBg,
            selectedIconTheme: IconThemeData(color: primaryColor),
            unselectedIconTheme: IconThemeData(color: unselectedColor),
            selectedLabelTextStyle: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelTextStyle: TextStyle(color: unselectedColor),
            indicatorColor: primaryColor.withValues(alpha: 0.15),
            destinations: List.generate(titles.length, (i) {
              return NavigationRailDestination(
                icon: _maybeBadgedIcon(i, navIcons[i]),
                selectedIcon: _maybeBadgedIcon(i, navSelectedIcons[i]),
                label: Text(titles[i]),
              );
            }),
          ),
          VerticalDivider(
            thickness: 1,
            width: 1,
            color: isDark ? AppTheme.darkDivider : AppTheme.dividerColor,
          ),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _buildCupertinoNavBar(
    bool isDark,
    List<IconData> icons,
    List<IconData> selectedIcons,
    List<String> titles,
    int count,
  ) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? AppTheme.darkSurface.withValues(alpha: 0.8)
                : AppTheme.surfaceWhite.withValues(alpha: 0.8),
            border: Border(
              top: BorderSide(
                color: isDark ? AppTheme.darkDivider : AppTheme.dividerColor,
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: CupertinoTabBar(
              currentIndex: _currentIndex,
              onTap: _switchTab,
              backgroundColor: Colors.transparent,
              activeColor: isDark
                  ? AppTheme.darkPrimaryBlue
                  : AppTheme.primaryBlue,
              inactiveColor: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.mediumGrey,
              items: List.generate(
                count,
                (i) => BottomNavigationBarItem(
                  icon: _maybeBadgedIcon(i, icons[i]),
                  activeIcon: _maybeBadgedIcon(i, selectedIcons[i]),
                  label: titles[i],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMaterialNavBar(
    bool isDark,
    List<IconData> icons,
    List<IconData> selectedIcons,
    List<String> titles,
    int count,
  ) {
    return NavigationBar(
      selectedIndex: _currentIndex,
      onDestinationSelected: _switchTab,
      backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite,
      indicatorColor: (isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue)
          .withValues(alpha: 0.15),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      animationDuration: AppTheme.normalAnimation,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: List.generate(
        count,
        (i) => NavigationDestination(
          icon: _maybeBadgedIcon(i, icons[i],
              color:
                  isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey),
          selectedIcon: _maybeBadgedIcon(i, selectedIcons[i],
              color:
                  isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue),
          label: titles[i],
        ),
      ),
    );
  }
}
