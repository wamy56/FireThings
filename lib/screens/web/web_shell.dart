import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../services/user_profile_service.dart';
import '../../services/remote_config_service.dart';
import '../../models/permission.dart';
import '../../services/company_service.dart';
import '../../services/web_notification_service.dart';
import '../../theme/web_theme.dart';
import '../../utils/theme_style.dart';
import '../../utils/icon_map.dart';
import '../../main.dart' show themeNotifier, saveThemePreference;
import 'web_notification_feed.dart';
import 'web_notification_toast.dart';

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
  });
}

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

  void _cycleTheme() {
    if (themeStyleNotifier.value == ThemeStyle.siteOps) {
      themeStyleNotifier.value = ThemeStyle.classic;
      saveThemeStylePreference(ThemeStyle.classic);
      setState(() {});
      return;
    }
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

  void _toggleSiteOps() {
    final isSiteOps = themeStyleNotifier.value == ThemeStyle.siteOps;
    themeStyleNotifier.value =
        isSiteOps ? ThemeStyle.classic : ThemeStyle.siteOps;
    saveThemeStylePreference(themeStyleNotifier.value);
    setState(() {});
  }

  int _selectedIndexFromPath(String path, bool canBrand, bool quotingEnabled) {
    if (path.startsWith('/jobs') || path == '/') return 0;
    if (path.startsWith('/schedule')) return 1;
    if (path.startsWith('/team')) return 2;
    if (path.startsWith('/sites')) return 3;
    if (path.startsWith('/customers')) return 4;
    int idx = 5;
    if (quotingEnabled) {
      if (path.startsWith('/quotes')) return idx;
      idx++;
    }
    if (path.startsWith('/invoices')) return idx;
    idx++;
    if (canBrand) {
      if (path.startsWith('/branding')) return idx;
      idx++;
    }
    if (path.startsWith('/settings')) return idx;
    return 0;
  }

  // ── Topbar ─────────────────────────────────────────────────────────────

  Widget _buildBrandMark() {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        gradient: FtColors.primaryGradient,
        borderRadius: FtRadii.mdAll,
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F1A1A2E),
            offset: Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        'F',
        style: FtText.outfit(
          size: 17,
          weight: FontWeight.w800,
          color: FtColors.accent,
          letterSpacing: -0.3,
        ),
      ),
    );
  }

  Widget _buildSearchPlaceholder() {
    return _HoverContainer(
      defaultColor: FtColors.bgAlt,
      hoverColor: FtColors.bgSunken,
      borderRadius: FtRadii.mdAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            Icon(AppIcons.search, size: 16, color: FtColors.hint),
            const SizedBox(width: 10),
            Text(
              'Search jobs, sites, engineers…',
              style: FtText.body
                  .copyWith(color: FtColors.hint, fontWeight: FontWeight.w400),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: FtColors.bg,
                border: Border.all(color: FtColors.border),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                '⌘K',
                style: FtText.mono(
                    size: 11, weight: FontWeight.w500, color: FtColors.fg2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserChip(User user) {
    final initial = (user.displayName ?? user.email ?? '?')[0].toUpperCase();
    final name = user.displayName ?? user.email ?? '';
    return _HoverContainer(
      defaultColor: Colors.transparent,
      hoverColor: FtColors.bgAlt,
      borderRadius: FtRadii.mdAll,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(5, 5, 12, 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                gradient: FtColors.accentGradient,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: FtText.inter(
                    size: 11, weight: FontWeight.w700, color: Colors.white),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              name,
              style: FtText.inter(
                  size: 14, weight: FontWeight.w600, color: FtColors.fg1),
            ),
            const SizedBox(width: 4),
            Icon(AppIcons.arrowDown, size: 14, color: FtColors.hint),
          ],
        ),
      ),
    );
  }

  Widget _buildTopbar({required bool showDrawer}) {
    final user = FirebaseAuth.instance.currentUser;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: FtColors.bg.withValues(alpha: 0.9),
            border: const Border(
              bottom: BorderSide(color: FtColors.border, width: 1),
            ),
          ),
          child: Row(
            children: [
              if (showDrawer) ...[
                _FtIconButton(
                  icon: AppIcons.menu,
                  onTap: () => Scaffold.of(context).openDrawer(),
                  tooltip: 'Menu',
                ),
                const SizedBox(width: 8),
              ],
              _buildBrandMark(),
              const SizedBox(width: 10),
              Text(
                'FireThings',
                style: FtText.inter(
                  size: 19,
                  weight: FontWeight.w800,
                  color: FtColors.primary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: _buildSearchPlaceholder(),
                  ),
                ),
              ),
              const SizedBox(width: 32),
              const WebNotificationFeed(),
              const SizedBox(width: 8),
              if (_companyName != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(
                    _companyName!,
                    style: FtText.inter(
                        size: 13, weight: FontWeight.w500, color: FtColors.fg2),
                  ),
                ),
              if (user != null) _buildUserChip(user),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sidebar ────────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 20, 16, 8),
      child: Text(
        label,
        style: FtText.inter(
          size: 11,
          weight: FontWeight.w700,
          color: FtColors.hint,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildThemeToggle() {
    final isSiteOps = themeStyleNotifier.value == ThemeStyle.siteOps;

    if (isSiteOps) {
      return _FtNavItem(
        item: _NavItem(
          label: 'SiteOps',
          icon: AppIcons.colorSwatch,
          activeIcon: AppIcons.colorSwatch,
          route: '',
        ),
        isActive: false,
        onTap: _toggleSiteOps,
        iconColorOverride: FtColors.accent,
        labelColorOverride: FtColors.accent,
      );
    }

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
    return _FtNavItem(
      item: _NavItem(label: label, icon: icon, activeIcon: icon, route: ''),
      isActive: false,
      onTap: _cycleTheme,
    );
  }

  Widget _buildSidebar({
    required List<_NavItem> topSection,
    required List<_NavItem> workspaceSection,
    required List<_NavItem> financeSection,
    required List<_NavItem> bottomSection,
    required int selectedIndex,
    required void Function(int) onSelect,
  }) {
    int idx = 0;

    Widget navItem(_NavItem item) {
      final i = idx;
      idx++;
      return _FtNavItem(
        item: item,
        isActive: selectedIndex == i,
        onTap: () => onSelect(i),
      );
    }

    return Container(
      width: 236,
      decoration: const BoxDecoration(
        color: FtColors.bg,
        border: Border(
          right: BorderSide(color: FtColors.border, width: 1),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: FtSpacing.xl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [for (final item in topSection) navItem(item)],
            ),
          ),
          _buildSectionLabel('WORKSPACE'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [for (final item in workspaceSection) navItem(item)],
            ),
          ),
          _buildSectionLabel('FINANCE'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [for (final item in financeSection) navItem(item)],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (final item in bottomSection) navItem(item),
                _buildThemeToggle(),
                _FtNavItem(
                  item: const _NavItem(
                    label: 'Sign Out',
                    icon: AppIcons.logout,
                    activeIcon: AppIcons.logout,
                    route: '',
                  ),
                  isActive: false,
                  onTap: () => FirebaseAuth.instance.signOut(),
                ),
              ],
            ),
          ),
          const SizedBox(height: FtSpacing.base),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final canBrand =
        UserProfileService.instance.hasPermission(AppPermission.pdfBranding);
    final quotingEnabled = RemoteConfigService.instance.quotingEnabled;

    if (width < 600) {
      return Scaffold(
        backgroundColor: FtColors.primary,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Container(
              decoration: FtDecorations.card(),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(AppIcons.global, size: 48, color: FtColors.accent),
                    const SizedBox(height: 16),
                    Text(
                      'For the best experience, use the FireThings mobile app',
                      textAlign: TextAlign.center,
                      style: FtText.body,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => FirebaseAuth.instance.signOut(),
                      icon: Icon(AppIcons.logout),
                      label: Text('Sign Out', style: FtText.button),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: FtColors.fg1,
                        side: const BorderSide(
                            color: FtColors.border, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: FtRadii.mdAll),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final showDrawer = width < 900;
    final currentPath = GoRouterState.of(context).matchedLocation;
    final selectedIndex =
        _selectedIndexFromPath(currentPath, canBrand, quotingEnabled);

    final topSection = [
      const _NavItem(
          label: 'Jobs',
          icon: AppIcons.taskOutline,
          activeIcon: AppIcons.taskBold,
          route: '/jobs'),
      const _NavItem(
          label: 'Schedule',
          icon: AppIcons.calendar,
          activeIcon: AppIcons.calendar,
          route: '/schedule'),
    ];
    final workspaceSection = [
      const _NavItem(
          label: 'Team',
          icon: AppIcons.people,
          activeIcon: AppIcons.peopleBold,
          route: '/team'),
      const _NavItem(
          label: 'Sites',
          icon: AppIcons.building,
          activeIcon: AppIcons.buildingBold,
          route: '/sites'),
      const _NavItem(
          label: 'Customers',
          icon: AppIcons.user,
          activeIcon: AppIcons.userBold,
          route: '/customers'),
    ];
    final financeSection = [
      if (quotingEnabled)
        const _NavItem(
            label: 'Quotes',
            icon: AppIcons.receipt,
            activeIcon: AppIcons.receiptBold,
            route: '/quotes'),
      const _NavItem(
          label: 'Invoices',
          icon: AppIcons.wallet,
          activeIcon: AppIcons.walletBold,
          route: '/invoices'),
    ];
    final bottomSection = [
      if (canBrand)
        const _NavItem(
            label: 'Branding',
            icon: AppIcons.brush,
            activeIcon: AppIcons.brush,
            route: '/branding'),
      const _NavItem(
          label: 'Settings',
          icon: AppIcons.settingOutline,
          activeIcon: AppIcons.settingBold,
          route: '/settings'),
    ];

    final routes = [
      ...topSection.map((e) => e.route),
      ...workspaceSection.map((e) => e.route),
      ...financeSection.map((e) => e.route),
      ...bottomSection.map((e) => e.route),
    ];

    void onDestinationSelected(int index) {
      if (index < routes.length) {
        context.go(routes[index]);
      }
    }

    Widget sidebar() => _buildSidebar(
          topSection: topSection,
          workspaceSection: workspaceSection,
          financeSection: financeSection,
          bottomSection: bottomSection,
          selectedIndex: selectedIndex,
          onSelect: onDestinationSelected,
        );

    if (showDrawer) {
      return WebNotificationToastManager(
        key: _toastKey,
        child: Scaffold(
          backgroundColor: FtColors.bgAlt,
          drawer: Drawer(
            width: 236,
            backgroundColor: FtColors.bg,
            shape: const RoundedRectangleBorder(),
            child: sidebar(),
          ),
          body: Column(
            children: [
              _buildTopbar(showDrawer: true),
              Expanded(child: widget.child),
            ],
          ),
        ),
      );
    }

    return WebNotificationToastManager(
      key: _toastKey,
      child: Scaffold(
        backgroundColor: FtColors.bgAlt,
        body: Column(
          children: [
            _buildTopbar(showDrawer: false),
            Expanded(
              child: Row(
                children: [
                  sidebar(),
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

// ═══════════════════════════════════════════════════════════════════════════
// Private widgets
// ═══════════════════════════════════════════════════════════════════════════

class _FtNavItem extends StatefulWidget {
  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;
  final Color? iconColorOverride;
  final Color? labelColorOverride;

  const _FtNavItem({
    required this.item,
    required this.isActive,
    required this.onTap,
    this.iconColorOverride,
    this.labelColorOverride,
  });

  @override
  State<_FtNavItem> createState() => _FtNavItemState();
}

class _FtNavItemState extends State<_FtNavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isActive;
    final hovered = _hovered;

    final iconColor = widget.iconColorOverride ??
        (active
            ? FtColors.accent
            : (hovered ? FtColors.fg2 : FtColors.hint));
    final labelColor = widget.labelColorOverride ??
        (active
            ? Colors.white
            : (hovered ? FtColors.primary : FtColors.fg2));

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: FtMotion.fast,
            curve: FtMotion.standardCurve,
            padding:
                const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
            decoration: BoxDecoration(
              color: active
                  ? FtColors.primary
                  : (hovered ? FtColors.bgAlt : Colors.transparent),
              borderRadius: FtRadii.mdAll,
              boxShadow: active ? FtShadows.navyDepth : null,
            ),
            child: Row(
              children: [
                Icon(
                  active ? widget.item.activeIcon : widget.item.icon,
                  size: 18,
                  color: iconColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.item.label,
                    style: FtText.navItem.copyWith(
                      color: labelColor,
                      fontWeight:
                          active ? FontWeight.w600 : FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (active)
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: FtColors.accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: FtColors.accent.withValues(alpha: 0.25),
                          blurRadius: 0,
                          spreadRadius: 3,
                        ),
                      ],
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

class _FtIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  const _FtIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  @override
  State<_FtIconButton> createState() => _FtIconButtonState();
}

class _FtIconButtonState extends State<_FtIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final btn = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: FtMotion.fast,
          curve: FtMotion.standardCurve,
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _hovered ? FtColors.bgAlt : Colors.transparent,
            borderRadius: FtRadii.mdAll,
          ),
          alignment: Alignment.center,
          child: Icon(
            widget.icon,
            size: 20,
            color: _hovered ? FtColors.primary : FtColors.fg2,
          ),
        ),
      ),
    );
    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: btn);
    }
    return btn;
  }
}

class _HoverContainer extends StatefulWidget {
  final Color defaultColor;
  final Color hoverColor;
  final BorderRadius borderRadius;
  final Widget child;

  const _HoverContainer({
    required this.defaultColor,
    required this.hoverColor,
    required this.borderRadius,
    required this.child,
  });

  @override
  State<_HoverContainer> createState() => _HoverContainerState();
}

class _HoverContainerState extends State<_HoverContainer> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: FtMotion.fast,
        curve: FtMotion.standardCurve,
        decoration: BoxDecoration(
          color: _hovered ? widget.hoverColor : widget.defaultColor,
          borderRadius: widget.borderRadius,
        ),
        child: widget.child,
      ),
    );
  }
}
