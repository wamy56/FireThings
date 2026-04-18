import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/auth_service.dart';
import '../../services/database_helper.dart';
import '../../services/notification_service.dart';
import '../../utils/theme.dart';
import '../../utils/responsive.dart';
import '../../utils/icon_map.dart';
import '../../utils/animate_helpers.dart';
import '../../widgets/responsive_scaffold.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/skeleton_loader.dart';
import '../tools/dip_switch_calculator.dart';
import '../tools/decibel_meter_screen.dart';
import '../tools/battery_load_test_screen.dart';
import '../tools/bs5839_reference_screen.dart';
import '../tools/detector_spacing_calculator_screen.dart';
import '../tools/timestamp_camera/timestamp_camera_screen.dart';
import '../saved_sites/saved_sites_screen.dart';
import '../company/company_sites_screen.dart';
import '../../services/analytics_service.dart';
import '../../services/remote_config_service.dart';
import '../../services/dispatch_service.dart';
import '../../services/quote_service.dart';
import '../../services/user_profile_service.dart';
import '../../services/company_service.dart';
import '../../widgets/background_decoration.dart';
import '../../widgets/tools_disclaimer_gate.dart';
import '../quoting/quoting_hub_screen.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<int> onTabChanged;

  const HomeScreen({super.key, required this.onTabChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  final _dbHelper = DatabaseHelper.instance;

  int _siteCount = 0;
  int _pendingDispatchCount = 0;
  int _activeQuoteCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _requestNotificationPermissionOnce();
  }

  Future<void> _requestNotificationPermissionOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('notificationPermissionAsked') == true) return;
    await prefs.setBool('notificationPermissionAsked', true);
    await NotificationService.instance.requestPermission();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final user = _authService.currentUser;
      if (user == null) return;

      // Load site count — company sites if in a company, personal sites otherwise
      final companyId = UserProfileService.instance.companyId;
      final hasCompany = companyId != null && RemoteConfigService.instance.dispatchEnabled;

      int siteCount = 0;
      if (hasCompany) {
        final companySites = await CompanyService.instance
            .getSitesStream(companyId)
            .first;
        siteCount = companySites.length;
      } else {
        final sites = await _dbHelper.getSavedSitesByEngineerId(user.uid);
        siteCount = sites.length;
      }

      // Load pending dispatch count if user has a company
      int pendingCount = 0;
      if (hasCompany) {
        pendingCount = await DispatchService.instance.getPendingJobCount(
          companyId,
          user.uid,
        );
      }

      // Load active quote count if quoting is enabled
      int quoteCount = 0;
      if (RemoteConfigService.instance.quotingEnabled) {
        final counts = await QuoteService.instance.getQuoteCounts();
        quoteCount = (counts['drafts'] ?? 0) + (counts['sent'] ?? 0) + (counts['approved'] ?? 0);
      }

      setState(() {
        _siteCount = siteCount;
        _pendingDispatchCount = pendingCount;
        _activeQuoteCount = quoteCount;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    return Scaffold(
      body: _isLoading
          ? _buildSkeleton()
          : Stack(
              children: [
                const BackgroundDecoration(),
                AdaptiveRefreshIndicator(
                  onRefresh: _loadDashboardData,
                  child: ResponsiveListView(
                    children: [
                      // Welcome Header
                      _buildWelcomeHeader(user).animateEntrance(),
                      const SizedBox(height: AppTheme.sectionGap),

                      // Sites & Assets
                      if (RemoteConfigService.instance.assetRegisterEnabled)
                        _buildSitesCard().animateEntrance(delay: 100.ms),

                      // Quotes Card
                      if (RemoteConfigService.instance.quotingEnabled) ...[
                        const SizedBox(height: 16),
                        _buildQuotesCard().animateEntrance(delay: 125.ms),
                      ],

                      // Dispatched Jobs Card
                      if (_pendingDispatchCount > 0) ...[
                        const SizedBox(height: 16),
                        _buildDispatchCard().animateEntrance(delay: 150.ms),
                      ],
                      const SizedBox(height: AppTheme.sectionGap),

                      // Quick Actions
                      _buildQuickActions().animateEntrance(delay: 200.ms),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      child: SkeletonShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBox(height: 60, borderRadius: 12),
            const SizedBox(height: AppTheme.sectionGap),
            const SkeletonBox(height: 72, borderRadius: 16),
            const SizedBox(height: AppTheme.sectionGap),
            const SkeletonBox(height: 20, width: 120, borderRadius: 8),
            const SizedBox(height: 16),
            Row(
              children: const [
                Expanded(child: SkeletonBox(height: 100, borderRadius: 16)),
                SizedBox(width: 12),
                Expanded(child: SkeletonBox(height: 100, borderRadius: 16)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: const [
                Expanded(child: SkeletonBox(height: 100, borderRadius: 16)),
                SizedBox(width: 12),
                Expanded(child: SkeletonBox(height: 100, borderRadius: 16)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: const [
                Expanded(child: SkeletonBox(height: 100, borderRadius: 16)),
                SizedBox(width: 12),
                Expanded(child: SkeletonBox(height: 100, borderRadius: 16)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDispatchCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        // Navigate to dispatch tab (index 3 or 4 depending on nav layout)
        // The dispatch tab is the last tab before settings
        final hasDispatch = RemoteConfigService.instance.dispatchEnabled &&
            UserProfileService.instance.hasCompany;
        if (hasDispatch) {
          widget.onTabChanged(3);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppTheme.cardPadding),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          boxShadow: isDark ? null : AppTheme.cardShadow,
          border: Border.all(
            color: AppTheme.accentOrange.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                AppIcons.routing,
                color: AppTheme.accentOrange,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dispatched Jobs',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$_pendingDispatchCount pending ${_pendingDispatchCount == 1 ? 'job' : 'jobs'}',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(AppIcons.arrowRight, color: AppTheme.textHint),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final isWide = context.isWide;
    final analytics = AnalyticsService.instance;
    final rc = RemoteConfigService.instance;

    final actions = <Widget>[
      if (rc.dipSwitchCalculatorEnabled)
        _buildActionButton('DIP Calculator', AppIcons.toggleOn, Colors.blue, () {
          analytics.logToolOpened('dip_switch_calculator');
          Navigator.push(
            context,
            adaptivePageRoute(builder: (_) => const DipSwitchCalculatorScreen()),
          );
        }),
      if (rc.decibelMeterEnabled)
        _buildActionButton('Decibel Meter', AppIcons.volumeHigh, Colors.purple, () {
          analytics.logToolOpened('decibel_meter');
          ToolsDisclaimerGate.navigateToTool(
            context,
            const DecibelMeterScreen(),
          );
        }),
      if (rc.batteryLoadTesterEnabled)
        _buildActionButton(
          'Battery Test',
          AppIcons.batteryCharging,
          Colors.green,
          () {
            analytics.logToolOpened('battery_load_test');
            ToolsDisclaimerGate.navigateToTool(
              context,
              const BatteryLoadTestScreen(),
            );
          },
        ),
      if (rc.bs5839ReferenceEnabled)
        _buildActionButton('BS 5839', AppIcons.book, Colors.teal, () {
          analytics.logToolOpened('bs5839_reference');
          ToolsDisclaimerGate.navigateToTool(
            context,
            const BS5839ReferenceScreen(),
          );
        }),
      if (rc.detectorSpacingEnabled)
        _buildActionButton('Detector Spacing', AppIcons.grid, Colors.indigo, () {
          analytics.logToolOpened('detector_spacing_calculator');
          ToolsDisclaimerGate.navigateToTool(
            context,
            const DetectorSpacingCalculatorScreen(),
          );
        }),
      if (rc.timestampCameraEnabled)
        _buildActionButton('Timestamp Camera', AppIcons.camera, Colors.deepOrange, () {
          analytics.logToolOpened('timestamp_camera');
          Navigator.push(
            context,
            adaptivePageRoute(builder: (_) => const TimestampCameraScreen()),
          );
        }),
    ];

    if (actions.isEmpty) return const SizedBox.shrink();

    final cols = isWide ? 3 : 2;
    final rows = <Widget>[];
    for (var i = 0; i < actions.length; i += cols) {
      final rowChildren = <Widget>[];
      for (var j = i; j < i + cols; j++) {
        if (j > i) rowChildren.add(const SizedBox(width: 12));
        rowChildren.add(
          Expanded(child: j < actions.length ? actions[j] : const SizedBox()),
        );
      }
      if (rows.isNotEmpty) rows.add(const SizedBox(height: AppTheme.listItemSpacing));
      rows.add(Row(children: rowChildren));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Helpful Tools',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppTheme.listItemSpacing),
        ...rows,
      ],
    );
  }

  Widget _buildWelcomeHeader(User? user) {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good Morning';
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
    } else {
      greeting = 'Good Evening';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                user?.displayName ?? user?.email?.split('@')[0] ?? 'Engineer',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        // Logo with pulse animation
        Image.asset(
          'assets/images/app_icon.png',
          height: 56,
          width: 56,
        )
            .animate()
            .scaleXY(begin: 0.5, end: 1.0, duration: 350.ms, curve: Curves.easeOutBack)
            .then()
            .scaleXY(begin: 1.0, end: 1.05, duration: 1500.ms, curve: Curves.easeInOut)
            .then()
            .scaleXY(begin: 1.05, end: 1.0, duration: 1500.ms, curve: Curves.easeInOut),
      ],
    );
  }

  Widget _buildSitesCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final companyId = UserProfileService.instance.companyId;
    final isCompanyUser = companyId != null && RemoteConfigService.instance.dispatchEnabled;

    return GestureDetector(
      onTap: () {
        if (isCompanyUser) {
          Navigator.push(
            context,
            adaptivePageRoute(builder: (_) => CompanySitesScreen(companyId: companyId)),
          );
        } else {
          Navigator.push(
            context,
            adaptivePageRoute(builder: (_) => const SavedSitesScreen()),
          );
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppTheme.cardPadding),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          boxShadow: isDark ? null : AppTheme.cardShadow,
          border: Border.all(
            color: AppTheme.primaryBlue.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                AppIcons.location,
                color: AppTheme.primaryBlue,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sites & Assets',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isCompanyUser
                        ? '$_siteCount company ${_siteCount == 1 ? 'site' : 'sites'}'
                        : '$_siteCount saved ${_siteCount == 1 ? 'site' : 'sites'}',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(AppIcons.arrowRight, color: AppTheme.textHint),
          ],
        ),
      ),
    );
  }

  Widget _buildQuotesCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          adaptivePageRoute(builder: (_) => const QuotingHubScreen()),
        );
        _loadDashboardData();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppTheme.cardPadding),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          boxShadow: isDark ? null : AppTheme.cardShadow,
          border: Border.all(
            color: AppTheme.accentOrange.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                AppIcons.receipt,
                color: AppTheme.accentOrange,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quotes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _activeQuoteCount > 0
                        ? '$_activeQuoteCount active ${_activeQuoteCount == 1 ? 'quote' : 'quotes'}'
                        : 'Create and manage quotes',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (_activeQuoteCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_activeQuoteCount',
                  style: TextStyle(
                    color: AppTheme.accentOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Icon(AppIcons.arrowRight, color: AppTheme.textHint),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: isDark ? AppTheme.darkCardShadow : AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Icon(icon, color: color, size: 36),
                const SizedBox(height: 10),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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
