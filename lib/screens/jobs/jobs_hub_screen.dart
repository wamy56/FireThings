import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/models.dart';
import '../../services/database_helper.dart';
import '../../services/auth_service.dart';
import '../../services/template_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/animate_helpers.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/background_decoration.dart';
import '../../utils/adaptive_widgets.dart';
import '../new_job/new_job_screen.dart';
import '../new_job/jobsheet_drafts_screen.dart';
import '../history/history_screen.dart';
import '../invoicing/pdf_design_screen.dart';
import 'custom_templates_screen.dart';

class JobsHubScreen extends StatefulWidget {
  const JobsHubScreen({super.key});

  @override
  State<JobsHubScreen> createState() => _JobsHubScreenState();
}

class _JobsHubScreenState extends State<JobsHubScreen> {
  final _dbHelper = DatabaseHelper.instance;
  final _authService = AuthService();
  final _templateService = TemplateService.instance;

  int _completedCount = 0;
  int _draftCount = 0;
  int _thisMonthCount = 0;
  int _historyCount = 0;
  int _customTemplateCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final user = _authService.currentUser;
      if (user == null) return;

      final allJobsheets = await _dbHelper.getJobsheetsByEngineerId(user.uid);
      final draftJobsheets = await _dbHelper.getDraftJobsheetsByEngineerId(user.uid);
      final customTemplates = _templateService.getCustomTemplates();

      final completed = allJobsheets
          .where((j) => j.status == JobsheetStatus.completed)
          .toList();

      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final thisMonth = completed
          .where((j) => j.createdAt.isAfter(startOfMonth))
          .toList();

      setState(() {
        _completedCount = completed.length;
        _draftCount = draftJobsheets.length;
        _thisMonthCount = thisMonth.length;
        _historyCount = completed.length;
        _customTemplateCount = customTemplates.length;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading jobs hub data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite;
    final shadow = isDark ? AppTheme.darkCardShadow : AppTheme.cardShadow;

    return Scaffold(
      body: Stack(
        children: [
          const BackgroundDecoration(),
          _isLoading
          ? _buildSkeleton(isDark)
          : AdaptiveRefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(AppTheme.screenPadding),
                children: [
                  // Summary stats row
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          '$_completedCount',
                          'Completed',
                          AppIcons.tickCircle,
                          AppTheme.successGreen,
                          isDark,
                          cardColor,
                          shadow,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              adaptivePageRoute(builder: (_) => const HistoryScreen()),
                            );
                            _loadData();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          '$_draftCount',
                          'Drafts',
                          AppIcons.editNote,
                          AppTheme.warningOrange,
                          isDark,
                          cardColor,
                          shadow,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              adaptivePageRoute(builder: (_) => const JobsheetDraftsScreen()),
                            );
                            _loadData();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          '$_thisMonthCount',
                          'This Month',
                          AppIcons.calendar,
                          isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue,
                          isDark,
                          cardColor,
                          shadow,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              adaptivePageRoute(builder: (_) => const HistoryScreen()),
                            );
                            _loadData();
                          },
                        ),
                      ),
                    ],
                  ).animateEntrance(),
                  const SizedBox(height: 24),

                  // Start New Job button
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue,
                      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                      boxShadow: shadow,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            adaptivePageRoute(builder: (_) => const NewJobScreen()),
                          );
                          _loadData();
                        },
                        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(AppIcons.addCircle, color: Colors.white, size: 24),
                              SizedBox(width: 10),
                              Text(
                                'Start New Job',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ).animateEntrance(delay: 80.ms),
                  const SizedBox(height: 24),

                  // Navigation tiles grid (2x2)
                  Row(
                    children: [
                      Expanded(
                        child: _buildSectionTile(
                          icon: AppIcons.editNote,
                          label: 'Drafts',
                          count: _draftCount,
                          color: AppTheme.warningOrange,
                          isDark: isDark,
                          cardColor: cardColor,
                          shadow: shadow,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              adaptivePageRoute(
                                builder: (_) => const JobsheetDraftsScreen(),
                              ),
                            );
                            _loadData();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSectionTile(
                          icon: AppIcons.clock,
                          label: 'History',
                          count: _historyCount,
                          color: isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue,
                          isDark: isDark,
                          cardColor: cardColor,
                          shadow: shadow,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              adaptivePageRoute(
                                builder: (_) => const HistoryScreen(),
                              ),
                            );
                            _loadData();
                          },
                        ),
                      ),
                    ],
                  ).animateEntrance(delay: 160.ms),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSectionTile(
                          icon: AppIcons.category,
                          label: 'Custom Templates',
                          count: _customTemplateCount,
                          color: Colors.purple,
                          isDark: isDark,
                          cardColor: cardColor,
                          shadow: shadow,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              adaptivePageRoute(
                                builder: (_) => const CustomTemplatesScreen(),
                              ),
                            );
                            _loadData();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSectionTile(
                          icon: AppIcons.designtools,
                          label: 'PDF Design',
                          color: Colors.pink,
                          isDark: isDark,
                          cardColor: cardColor,
                          shadow: shadow,
                          onTap: () => Navigator.push(
                            context,
                            adaptivePageRoute(
                              builder: (_) => const PdfDesignScreen(docType: PdfDocumentType.jobsheet),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ).animateEntrance(delay: 240.ms),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSkeleton(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      child: SkeletonShimmer(
        child: Column(
          children: [
            Row(
              children: List.generate(3, (_) => const Expanded(child: SkeletonBox(height: 80, borderRadius: 16)))
                  .expand((w) sync* { yield w; yield const SizedBox(width: 12); })
                  .toList()..removeLast(),
            ),
            const SizedBox(height: 24),
            const SkeletonBox(height: 56, borderRadius: 16),
            const SizedBox(height: 24),
            Row(
              children: const [
                Expanded(child: SkeletonBox(height: 140, borderRadius: 16)),
                SizedBox(width: 12),
                Expanded(child: SkeletonBox(height: 140, borderRadius: 16)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: const [
                Expanded(child: SkeletonBox(height: 140, borderRadius: 16)),
                SizedBox(width: 12),
                Expanded(child: SkeletonBox(height: 140, borderRadius: 16)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String value,
    String label,
    IconData icon,
    Color color,
    bool isDark,
    Color cardColor,
    List<BoxShadow> shadow, {
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: shadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Column(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTile({
    required IconData icon,
    required String label,
    int? count,
    required Color color,
    required bool isDark,
    required Color cardColor,
    required List<BoxShadow> shadow,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 140,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          boxShadow: shadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
                  if (count != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '($count)',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
