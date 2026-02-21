import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/auth_service.dart';
import '../../services/database_helper.dart';
import '../../services/notification_service.dart';
import '../../models/models.dart';
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
import '../tools/photo_logger_screen.dart';
import '../new_job/jobsheet_drafts_screen.dart';
import '../history/history_screen.dart';
import '../invoicing/invoice_list_screen.dart';
import '../../widgets/background_decoration.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<int> onTabChanged;

  const HomeScreen({super.key, required this.onTabChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  final _dbHelper = DatabaseHelper.instance;

  int _totalCompleted = 0;
  List<Invoice> _outstandingInvoices = [];
  List<Invoice> _draftInvoices = [];
  List<Jobsheet> _draftJobsheets = [];
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

      final results = await Future.wait([
        _dbHelper.getJobsheetsByEngineerId(user.uid),
        _dbHelper.getOutstandingInvoicesByEngineerId(user.uid),
        _dbHelper.getDraftJobsheetsByEngineerId(user.uid),
        _dbHelper.getDraftInvoicesByEngineerId(user.uid),
      ]);

      final allJobsheets = results[0] as List<Jobsheet>;
      final outstandingInvoices = results[1] as List<Invoice>;
      final draftJobsheets = results[2] as List<Jobsheet>;
      final draftInvoices = results[3] as List<Invoice>;

      final completedJobsheets = allJobsheets
          .where((j) => j.status == JobsheetStatus.completed)
          .toList();

      setState(() {
        _totalCompleted = completedJobsheets.length;
        _outstandingInvoices = outstandingInvoices;
        _draftInvoices = draftInvoices;
        _draftJobsheets = draftJobsheets;
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

                      // Stats Row
                      _buildStatsRow().animateEntrance(delay: 100.ms),
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
            Row(
              children: const [
                Expanded(child: SkeletonBox(height: 100, borderRadius: 16)),
                SizedBox(width: 12),
                Expanded(child: SkeletonBox(height: 100, borderRadius: 16)),
              ],
            ),
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

  Widget _buildQuickActions() {
    final isWide = context.isWide;

    final actions = [
      _buildActionButton('DIP Calculator', AppIcons.toggleOn, Colors.blue, () {
        Navigator.push(
          context,
          adaptivePageRoute(builder: (_) => const DipSwitchCalculatorScreen()),
        );
      }),
      _buildActionButton('Decibel Meter', AppIcons.volumeHigh, Colors.purple, () {
        Navigator.push(
          context,
          adaptivePageRoute(builder: (_) => const DecibelMeterScreen()),
        );
      }),
      _buildActionButton(
        'Battery Test',
        AppIcons.batteryCharging,
        Colors.green,
        () {
          Navigator.push(
            context,
            adaptivePageRoute(builder: (_) => const BatteryLoadTestScreen()),
          );
        },
      ),
      _buildActionButton('BS 5839', AppIcons.book, Colors.teal, () {
        Navigator.push(
          context,
          adaptivePageRoute(builder: (_) => const BS5839ReferenceScreen()),
        );
      }),
      _buildActionButton('Detector Spacing', AppIcons.grid, Colors.indigo, () {
        Navigator.push(
          context,
          adaptivePageRoute(builder: (_) => const DetectorSpacingCalculatorScreen()),
        );
      }),
      _buildActionButton('Photo Logger', AppIcons.camera, Colors.deepOrange, () {
        Navigator.push(
          context,
          adaptivePageRoute(builder: (_) => const PhotoLoggerScreen()),
        );
      }),
    ];

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
        if (isWide) ...[
          // Wide: 2 rows × 3 columns
          Row(
            children: [
              Expanded(child: actions[0]),
              const SizedBox(width: 12),
              Expanded(child: actions[1]),
              const SizedBox(width: 12),
              Expanded(child: actions[2]),
            ],
          ),
          const SizedBox(height: AppTheme.listItemSpacing),
          Row(
            children: [
              Expanded(child: actions[3]),
              const SizedBox(width: 12),
              Expanded(child: actions[4]),
              const SizedBox(width: 12),
              Expanded(child: actions[5]),
            ],
          ),
        ] else ...[
          // Compact: 3 rows × 2 columns
          Row(
            children: [
              Expanded(child: actions[0]),
              const SizedBox(width: 12),
              Expanded(child: actions[1]),
            ],
          ),
          const SizedBox(height: AppTheme.listItemSpacing),
          Row(
            children: [
              Expanded(child: actions[2]),
              const SizedBox(width: 12),
              Expanded(child: actions[3]),
            ],
          ),
          const SizedBox(height: AppTheme.listItemSpacing),
          Row(
            children: [
              Expanded(child: actions[4]),
              const SizedBox(width: 12),
              Expanded(child: actions[5]),
            ],
          ),
        ],
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

  Widget _buildStatsRow() {
    return Row(
      children: [
        // Jobs card
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceWhite,
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Column(
                children: [
                  Text(
                    'Jobs',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatTile(
                          AppIcons.tickCircle,
                          AppTheme.successGreen,
                          '$_totalCompleted',
                          'Completed',
                          onTap: () => Navigator.push(
                            context,
                            adaptivePageRoute(
                              builder: (_) => const HistoryScreen(),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: _buildStatTile(
                          AppIcons.editNote,
                          Colors.purple,
                          '${_draftJobsheets.length}',
                          'Job Drafts',
                          onTap: () => Navigator.push(
                            context,
                            adaptivePageRoute(
                              builder: (_) => const JobsheetDraftsScreen(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Invoices card
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceWhite,
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Column(
                children: [
                  Text(
                    'Invoices',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatTile(
                          AppIcons.receipt,
                          AppTheme.accentOrange,
                          '${_outstandingInvoices.length}',
                          'Unpaid',
                          onTap: () => Navigator.push(
                            context,
                            adaptivePageRoute(
                              builder: (_) => const InvoiceListScreen(
                                statusFilter: InvoiceStatus.sent,
                                title: 'Sent Invoices',
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: _buildStatTile(
                          AppIcons.editNote,
                          Colors.blue,
                          '${_draftInvoices.length}',
                          'Inv. Drafts',
                          onTap: () => Navigator.push(
                            context,
                            adaptivePageRoute(
                              builder: (_) => const InvoiceListScreen(
                                statusFilter: InvoiceStatus.draft,
                                title: 'Draft Invoices',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatTile(
    IconData icon,
    Color color,
    String value,
    String label, {
    VoidCallback? onTap,
  }) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }
    return content;
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: AppTheme.cardShadow,
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
