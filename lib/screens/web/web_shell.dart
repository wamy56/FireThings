import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../services/user_profile_service.dart';
import '../../models/permission.dart';
import '../../services/company_service.dart';
import '../../services/web_notification_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../main.dart' show themeNotifier, saveThemePreference;
import 'web_notification_feed.dart';
import 'web_notification_toast.dart';

class WebShell extends StatefulWidget {
  final Widget child;

  const WebShell({super.key, required this.child});

  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> {
  String? _companyName;
  final _toastKey = GlobalKey<WebNotificationToastManagerState>();

  @override
  void initState() {
    super.initState();
    _loadCompanyName();
    _wireUpForegroundMessages();
  }

  void _wireUpForegroundMessages() {
    WebNotificationService.instance.onForegroundMessage =
        (title, body, jobId) {
      _toastKey.currentState?.showToast(title, body, jobId);
    };
  }

  @override
  void dispose() {
    WebNotificationService.instance.onForegroundMessage = null;
    super.dispose();
  }

  Future<void> _loadCompanyName() async {
    final companyId = UserProfileService.instance.companyId;
    if (companyId == null) return;

    try {
      final company = await CompanyService.instance.getCompany(companyId);
      if (mounted && company != null) {
        setState(() => _companyName = company.name);
      }
    } catch (_) {}
  }

  Widget _buildSidebarLogo() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        'assets/images/firethings_logo_vertical.png',
        width: 36,
        height: 36,
        fit: BoxFit.contain,
      ),
    );
  }

  void _cycleTheme() {
    final current = themeNotifier.value;
    ThemeMode next;
    switch (current) {
      case ThemeMode.system:
        next = ThemeMode.light;
      case ThemeMode.light:
        next = ThemeMode.dark;
      case ThemeMode.dark:
        next = ThemeMode.system;
    }
    themeNotifier.value = next;
    saveThemePreference(next);
    setState(() {});
  }

  Widget _buildThemeToggle(bool extended, Color color) {
    final mode = themeNotifier.value;
    final IconData icon;
    final String label;
    switch (mode) {
      case ThemeMode.light:
        icon = AppIcons.sun;
        label = 'Light';
      case ThemeMode.dark:
        icon = AppIcons.moon;
        label = 'Dark';
      case ThemeMode.system:
        icon = AppIcons.lamp;
        label = 'Auto';
    }

    if (extended) {
      return TextButton.icon(
        onPressed: _cycleTheme,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: TextButton.styleFrom(foregroundColor: color),
      );
    }
    return IconButton(
      onPressed: _cycleTheme,
      icon: Icon(icon, color: color),
      tooltip: 'Theme: $label',
    );
  }

  int _selectedIndexFromPath(String path, bool canBrand) {
    if (path.startsWith('/jobs') || path == '/') return 0;
    if (path.startsWith('/schedule')) return 1;
    if (path.startsWith('/team')) return 2;
    if (path.startsWith('/sites')) return 3;
    if (path.startsWith('/customers')) return 4;
    if (canBrand && path.startsWith('/branding')) return 5;
    if (path.startsWith('/settings')) return canBrand ? 6 : 5;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final canBrand = UserProfileService.instance.hasPermission(AppPermission.pdfBranding);
    final user = FirebaseAuth.instance.currentUser;

    // Very narrow window — suggest mobile app
    if (width < 600) {
      return Scaffold(
        backgroundColor: AppTheme.primaryBlue,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(AppIcons.global, size: 48, color: AppTheme.accentOrange),
                    const SizedBox(height: 16),
                    const Text(
                      'For the best experience, use the FireThings mobile app',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => FirebaseAuth.instance.signOut(),
                      icon: Icon(AppIcons.logout),
                      label: const Text('Sign Out'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final extended = width >= 1200;
    final showDrawer = width < 900;
    final currentPath = GoRouterState.of(context).matchedLocation;
    final selectedIndex = _selectedIndexFromPath(currentPath, canBrand);

    final primaryColor = isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue;
    final unselectedColor = isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey;
    final railBg = isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite;

    final destinations = <NavigationRailDestination>[
      NavigationRailDestination(
        icon: Icon(AppIcons.taskOutline),
        selectedIcon: Icon(AppIcons.taskBold),
        label: const Text('Jobs'),
      ),
      NavigationRailDestination(
        icon: Icon(AppIcons.calendar),
        selectedIcon: Icon(AppIcons.calendar),
        label: const Text('Schedule'),
      ),
      NavigationRailDestination(
        icon: Icon(AppIcons.people),
        selectedIcon: Icon(AppIcons.peopleBold),
        label: const Text('Team'),
      ),
      NavigationRailDestination(
        icon: Icon(AppIcons.building),
        selectedIcon: Icon(AppIcons.buildingBold),
        label: const Text('Sites'),
      ),
      NavigationRailDestination(
        icon: Icon(AppIcons.user),
        selectedIcon: Icon(AppIcons.userBold),
        label: const Text('Customers'),
      ),
      if (canBrand)
        NavigationRailDestination(
          icon: Icon(AppIcons.brush),
          selectedIcon: Icon(AppIcons.brush),
          label: const Text('Branding'),
        ),
      NavigationRailDestination(
        icon: Icon(AppIcons.settingOutline),
        selectedIcon: Icon(AppIcons.settingBold),
        label: const Text('Settings'),
      ),
    ];

    final routes = [
      '/jobs',
      '/schedule',
      '/team',
      '/sites',
      '/customers',
      if (canBrand) '/branding',
      '/settings',
    ];

    void onDestinationSelected(int index) {
      if (index < routes.length) {
        context.go(routes[index]);
      }
    }

    final sidebar = NavigationRail(
      selectedIndex: selectedIndex.clamp(0, destinations.length - 1),
      onDestinationSelected: onDestinationSelected,
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
      leading: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: extended ? 20 : 8,
          vertical: 16,
        ),
        child: extended
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSidebarLogo(),
                  const SizedBox(width: 12),
                  Text(
                    'FireThings',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : AppTheme.darkGrey,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              )
            : _buildSidebarLogo(),
      ),
      trailing: Expanded(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Theme toggle
                _buildThemeToggle(extended, unselectedColor),
                const SizedBox(height: 4),
                // Sign out
                extended
                    ? TextButton.icon(
                        onPressed: () => FirebaseAuth.instance.signOut(),
                        icon: Icon(AppIcons.logout, size: 18),
                        label: const Text('Sign Out'),
                        style: TextButton.styleFrom(
                          foregroundColor: unselectedColor,
                        ),
                      )
                    : IconButton(
                        onPressed: () => FirebaseAuth.instance.signOut(),
                        icon: Icon(AppIcons.logout, color: unselectedColor),
                        tooltip: 'Sign Out',
                      ),
              ],
            ),
          ),
        ),
      ),
      destinations: destinations,
    );

    final topBar = Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppTheme.darkDivider : AppTheme.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          if (showDrawer)
            IconButton(
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: Icon(AppIcons.menu),
            ),
          Text(
            'Dispatcher Portal',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
            ),
          ),
          const Spacer(),
          const WebNotificationFeed(),
          const SizedBox(width: 8),
          if (_companyName != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                _companyName!,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
                ),
              ),
            ),
          if (user != null) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: primaryColor.withValues(alpha: 0.15),
              child: Text(
                (user.displayName ?? user.email ?? '?')[0].toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              user.displayName ?? user.email ?? '',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : AppTheme.darkGrey,
              ),
            ),
          ],
        ],
      ),
    );

    if (showDrawer) {
      return WebNotificationToastManager(
        key: _toastKey,
        child: Scaffold(
          drawer: Drawer(
            child: sidebar,
          ),
          body: Column(
            children: [
              topBar,
              Expanded(child: widget.child),
            ],
          ),
        ),
      );
    }

    return WebNotificationToastManager(
      key: _toastKey,
      child: Scaffold(
        body: Row(
          children: [
            sidebar,
            VerticalDivider(
              thickness: 1,
              width: 1,
              color: isDark ? AppTheme.darkDivider : AppTheme.dividerColor,
            ),
            Expanded(
              child: Column(
                children: [
                  topBar,
                  Expanded(child: widget.child),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
