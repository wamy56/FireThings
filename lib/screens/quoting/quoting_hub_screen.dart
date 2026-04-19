import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/models.dart';
import '../../utils/icon_map.dart';
import '../../utils/theme.dart';
import '../../utils/animate_helpers.dart';
import '../../utils/adaptive_widgets.dart';
import '../../services/quote_service.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/background_decoration.dart';
import 'quote_screen.dart';
import 'quote_list_screen.dart';

class QuotingHubScreen extends StatefulWidget {
  const QuotingHubScreen({super.key});

  @override
  State<QuotingHubScreen> createState() => _QuotingHubScreenState();
}

class _QuotingHubScreenState extends State<QuotingHubScreen> {
  int _draftCount = 0;
  int _sentCount = 0;
  int _approvedCount = 0;
  double _approvedValue = 0;
  int _totalCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final counts = await QuoteService.instance.getQuoteCounts();
      final value = await QuoteService.instance.getApprovedValue();
      setState(() {
        _draftCount = counts['drafts'] ?? 0;
        _sentCount = counts['sent'] ?? 0;
        _approvedCount = counts['approved'] ?? 0;
        _totalCount = counts.values.fold(0, (a, b) => a + b);
        _approvedValue = value;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading quote data: $e');
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
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              '\u00A3${_approvedValue.toStringAsFixed(0)}',
                              'Approved',
                              AppIcons.wallet,
                              AppTheme.accentOrange,
                              isDark,
                              cardColor,
                              shadow,
                              onTap: () => _navigateToList(
                                  QuoteStatus.approved, 'Approved Quotes'),
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
                              onTap: () => _navigateToList(
                                  QuoteStatus.draft, 'Draft Quotes'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              '$_sentCount',
                              'Sent',
                              AppIcons.send,
                              isDark
                                  ? AppTheme.darkPrimaryBlue
                                  : AppTheme.primaryBlue,
                              isDark,
                              cardColor,
                              shadow,
                              onTap: () => _navigateToList(
                                  QuoteStatus.sent, 'Sent Quotes'),
                            ),
                          ),
                        ],
                      ).animateEntrance(),
                      const SizedBox(height: 24),

                      // Create New Quote button
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.darkPrimaryBlue
                              : AppTheme.primaryBlue,
                          borderRadius:
                              BorderRadius.circular(AppTheme.cardRadius),
                          boxShadow: shadow,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                adaptivePageRoute(
                                    builder: (_) => const QuoteScreen()),
                              );
                              _loadData();
                            },
                            borderRadius:
                                BorderRadius.circular(AppTheme.cardRadius),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 18),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(AppIcons.addCircle,
                                      color: Colors.white, size: 24),
                                  SizedBox(width: 10),
                                  Text(
                                    'Create New Quote',
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

                      // Section tiles row 1
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
                              onTap: () => _navigateToList(
                                  QuoteStatus.draft, 'Draft Quotes'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSectionTile(
                              icon: AppIcons.send,
                              label: 'Sent',
                              count: _sentCount,
                              color: isDark
                                  ? AppTheme.darkPrimaryBlue
                                  : AppTheme.primaryBlue,
                              isDark: isDark,
                              cardColor: cardColor,
                              shadow: shadow,
                              onTap: () => _navigateToList(
                                  QuoteStatus.sent, 'Sent Quotes'),
                            ),
                          ),
                        ],
                      ).animateEntrance(delay: 160.ms),
                      const SizedBox(height: 12),

                      // Section tiles row 2
                      Row(
                        children: [
                          Expanded(
                            child: _buildSectionTile(
                              icon: AppIcons.tickCircle,
                              label: 'Approved',
                              count: _approvedCount,
                              color: AppTheme.successGreen,
                              isDark: isDark,
                              cardColor: cardColor,
                              shadow: shadow,
                              onTap: () => _navigateToList(
                                  QuoteStatus.approved, 'Approved Quotes'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSectionTile(
                              icon: AppIcons.document,
                              label: 'All Quotes',
                              count: _totalCount,
                              color: Colors.deepOrange,
                              isDark: isDark,
                              cardColor: cardColor,
                              shadow: shadow,
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  adaptivePageRoute(
                                      builder: (_) =>
                                          const QuoteListScreen()),
                                );
                                _loadData();
                              },
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

  void _navigateToList(QuoteStatus status, String title) async {
    await Navigator.push(
      context,
      adaptivePageRoute(
        builder: (_) => QuoteListScreen(statusFilter: status, title: title),
      ),
    );
    _loadData();
  }

  Widget _buildSkeleton(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      child: SkeletonShimmer(
        child: Column(
          children: [
            Row(
              children: List.generate(
                      3,
                      (_) => const Expanded(
                          child: SkeletonBox(height: 80, borderRadius: 16)))
                  .expand((w) sync* {
                    yield w;
                    yield const SizedBox(width: 12);
                  })
                  .toList()
                ..removeLast(),
            ),
            const SizedBox(height: 24),
            const SkeletonBox(height: 56, borderRadius: 16),
            const SizedBox(height: 24),
            Row(
              children: const [
                Expanded(
                    child: SkeletonBox(height: 140, borderRadius: 16)),
                SizedBox(width: 12),
                Expanded(
                    child: SkeletonBox(height: 140, borderRadius: 16)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: const [
                Expanded(
                    child: SkeletonBox(height: 140, borderRadius: 16)),
                SizedBox(width: 12),
                Expanded(
                    child: SkeletonBox(height: 140, borderRadius: 16)),
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
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textSecondary,
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
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textSecondary,
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
