import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:workmanager/workmanager.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/template_service.dart';
import 'services/notification_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/new_job/jobsheet_drafts_screen.dart';
import 'screens/invoicing/invoicing_hub_screen.dart';
import 'screens/jobs/jobs_hub_screen.dart';
import 'utils/theme.dart';
import 'utils/responsive.dart';
import 'utils/adaptive_widgets.dart';
import 'utils/icon_map.dart';
import 'widgets/adaptive_app_bar.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    await NotificationService.instance.initialize();
    await NotificationService.instance.checkAndNotify();
    return true;
  });
}

void main() {
  runZonedGuarded(() async {
    // Ensure Flutter is initialized (must be in same zone as runApp)
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Firebase
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);

    // Set up Crashlytics error handlers
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    // Load custom templates from database
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

    runApp(const JobsheetApp());
  }, (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
}

class JobsheetApp extends StatelessWidget {
  const JobsheetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FireThings',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      builder: (context, child) {
        final scale = AppTheme.responsiveTextScale(context.screenSize);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        );
      },
      home: const AuthWrapper(),
    );
  }
}

/// Wrapper that shows login or main screen based on auth state
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: AdaptiveLoadingIndicator(
                size: 32,
              ),
            ),
          );
        }

        // Show main screen if logged in, login screen if not
        if (snapshot.hasData) {
          return const MainNavigationScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

/// Main screen with adaptive bottom navigation
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  int _previousIndex = 0;

  static const _titles = ['Home', 'Jobs', 'Invoices', 'Settings'];

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

    // Set up notification tap routing
    NotificationService.onNotificationTap = _handleNotificationTap;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationService.onNotificationTap = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotificationService.instance.checkAndNotify();
    }
  }

  void _handleNotificationTap(String payload) {
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

  late final _screens = <Widget>[
    HomeScreen(onTabChanged: _switchTab),
    const JobsHubScreen(),
    const InvoicingHubScreen(),
    const SettingsScreen(),
  ];

  static const _navIcons = [
    AppIcons.homeOutline,
    AppIcons.briefcaseOutline,
    AppIcons.receiptOutline,
    AppIcons.settingOutline,
  ];

  static const _navSelectedIcons = [
    AppIcons.homeBold,
    AppIcons.briefcaseBold,
    AppIcons.receiptBold,
    AppIcons.settingBold,
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenSize = context.screenSize;
    final useRail = screenSize != ScreenSize.compact;

    final body = Scaffold(
      appBar: AdaptiveNavigationBar(
        title: _titles[_currentIndex],
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity > 300 && _currentIndex > 0) {
            _switchTab(_currentIndex - 1);
          } else if (velocity < -300 && _currentIndex < _screens.length - 1) {
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
            key: ValueKey(_currentIndex),
            child: _screens[_currentIndex],
          ),
        ),
      ),
      bottomNavigationBar: useRail
          ? null
          : PlatformUtils.isApple
              ? _buildCupertinoNavBar(isDark)
              : _buildMaterialNavBar(isDark),
    );

    if (!useRail) return body;

    final primaryColor = isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue;
    final unselectedColor = isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey;
    final railBg = isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite;
    final extended = screenSize == ScreenSize.expanded || screenSize == ScreenSize.large;

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
            destinations: List.generate(_titles.length, (i) {
              return NavigationRailDestination(
                icon: Icon(_navIcons[i]),
                selectedIcon: Icon(_navSelectedIcons[i]),
                label: Text(_titles[i]),
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

  Widget _buildCupertinoNavBar(bool isDark) {
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
              activeColor: isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue,
              inactiveColor: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(AppIcons.homeOutline),
                  activeIcon: Icon(AppIcons.homeBold),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(AppIcons.briefcaseOutline),
                  activeIcon: Icon(AppIcons.briefcaseBold),
                  label: 'Jobs',
                ),
                BottomNavigationBarItem(
                  icon: Icon(AppIcons.receiptOutline),
                  activeIcon: Icon(AppIcons.receiptBold),
                  label: 'Invoices',
                ),
                BottomNavigationBarItem(
                  icon: Icon(AppIcons.settingOutline),
                  activeIcon: Icon(AppIcons.settingBold),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMaterialNavBar(bool isDark) {
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
      destinations: [
        NavigationDestination(
          icon: Icon(
            AppIcons.homeOutline,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
          ),
          selectedIcon: Icon(
            AppIcons.homeBold,
            color: isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue,
          ),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(
            AppIcons.briefcaseOutline,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
          ),
          selectedIcon: Icon(
            AppIcons.briefcaseBold,
            color: isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue,
          ),
          label: 'Jobs',
        ),
        NavigationDestination(
          icon: Icon(
            AppIcons.receiptOutline,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
          ),
          selectedIcon: Icon(
            AppIcons.receiptBold,
            color: isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue,
          ),
          label: 'Invoices',
        ),
        NavigationDestination(
          icon: Icon(
            AppIcons.settingOutline,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
          ),
          selectedIcon: Icon(
            AppIcons.settingBold,
            color: isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue,
          ),
          label: 'Settings',
        ),
      ],
    );
  }
}
