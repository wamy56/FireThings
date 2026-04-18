import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../utils/icon_map.dart';
import '../../utils/theme.dart';
import '../../services/quote_service.dart';
import '../../widgets/adaptive_app_bar.dart';
import '../../widgets/skeleton_loader.dart';
import 'quote_screen.dart';
import 'quote_list_screen.dart';

class QuotingHubScreen extends StatefulWidget {
  const QuotingHubScreen({super.key});

  @override
  State<QuotingHubScreen> createState() => _QuotingHubScreenState();
}

class _QuotingHubScreenState extends State<QuotingHubScreen> {
  Map<String, int> _counts = {};
  double _approvedValue = 0;
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
        _counts = counts;
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

    return Scaffold(
      appBar: AdaptiveNavigationBar(title: 'Quotes'),
      body: _isLoading
          ? _buildSkeleton()
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: EdgeInsets.all(AppTheme.screenPadding),
                children: [
                  _buildStatsGrid(isDark),
                  SizedBox(height: AppTheme.sectionGap),
                  _buildQuickActions(isDark),
                ],
              ),
            ),
    );
  }

  Widget _buildSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      child: SkeletonShimmer(
        child: Column(
          children: [
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
            const SizedBox(height: 32),
            const SkeletonBox(height: 56, borderRadius: 12),
            const SizedBox(height: 12),
            const SkeletonBox(height: 56, borderRadius: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(bool isDark) {
    final currencyFormat =
        NumberFormat.currency(symbol: '\u00A3', decimalDigits: 0);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Drafts',
                value: '${_counts['drafts'] ?? 0}',
                icon: AppIcons.edit,
                color: Colors.grey,
                isDark: isDark,
                onTap: () => _navigateToList(QuoteStatus.draft, 'Drafts'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Sent',
                value: '${_counts['sent'] ?? 0}',
                icon: AppIcons.send,
                color: Colors.blue,
                isDark: isDark,
                onTap: () => _navigateToList(QuoteStatus.sent, 'Sent'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Approved',
                value: '${_counts['approved'] ?? 0}',
                icon: AppIcons.tickCircle,
                color: AppTheme.successGreen,
                isDark: isDark,
                onTap: () =>
                    _navigateToList(QuoteStatus.approved, 'Approved'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Total Value',
                value: currencyFormat.format(_approvedValue),
                icon: AppIcons.wallet,
                color: AppTheme.primaryBlue,
                isDark: isDark,
                onTap: () =>
                    _navigateToList(QuoteStatus.approved, 'Approved'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActions(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        _QuickActionTile(
          icon: AppIcons.addCircle,
          label: 'Create New Quote',
          color: AppTheme.accentOrange,
          isDark: isDark,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QuoteScreen()),
            );
            _loadData();
          },
        ),
        const SizedBox(height: 12),
        _QuickActionTile(
          icon: AppIcons.document,
          label: 'View All Quotes',
          color: AppTheme.primaryBlue,
          isDark: isDark,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QuoteListScreen()),
            );
            _loadData();
          },
        ),
      ],
    );
  }

  void _navigateToList(QuoteStatus status, String title) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuoteListScreen(statusFilter: status, title: title),
      ),
    );
    _loadData();
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(AppTheme.cardPadding),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          boxShadow: isDark ? AppTheme.darkCardShadow : AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: isDark ? AppTheme.darkCardShadow : AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Icon(AppIcons.arrowRight, color: AppTheme.textHint, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
