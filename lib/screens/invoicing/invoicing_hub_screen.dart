import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/invoice.dart';
import '../../services/database_helper.dart';
import '../../services/auth_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/animate_helpers.dart';
import '../../widgets/skeleton_loader.dart';
import '../../utils/adaptive_widgets.dart';
import '../tools/invoice_screen.dart';
import '../saved_customers/saved_customers_screen.dart';
import 'invoice_list_screen.dart';
import 'bank_details_screen.dart';
import 'pdf_design_screen.dart';

class InvoicingHubScreen extends StatefulWidget {
  const InvoicingHubScreen({super.key});

  @override
  State<InvoicingHubScreen> createState() => _InvoicingHubScreenState();
}

class _InvoicingHubScreenState extends State<InvoicingHubScreen> {
  final _dbHelper = DatabaseHelper.instance;
  final _authService = AuthService();

  int _draftCount = 0;
  int _sentCount = 0;
  int _paidCount = 0;
  int _customerCount = 0;
  double _outstandingTotal = 0;
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

      final allInvoices = await _dbHelper.getInvoicesByEngineerId(user.uid);
      final customers = await _dbHelper.getSavedCustomersByEngineerId(user.uid);

      final drafts = allInvoices.where((i) => i.status == InvoiceStatus.draft).toList();
      final sent = allInvoices.where((i) => i.status == InvoiceStatus.sent).toList();
      final paid = allInvoices.where((i) => i.status == InvoiceStatus.paid).toList();
      final outstanding = sent.fold<double>(0, (sum, inv) => sum + inv.total);

      setState(() {
        _draftCount = drafts.length;
        _sentCount = sent.length;
        _paidCount = paid.length;
        _customerCount = customers.length;
        _outstandingTotal = outstanding;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading invoicing data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite;
    final shadow = isDark ? AppTheme.darkCardShadow : AppTheme.cardShadow;

    return Scaffold(
      body: _isLoading
          ? _buildSkeleton()
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
                          '\u00A3${_outstandingTotal.toStringAsFixed(0)}',
                          'Outstanding',
                          AppIcons.wallet,
                          AppTheme.accentOrange,
                          isDark,
                          cardColor,
                          shadow,
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
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          '$_sentCount',
                          'Sent',
                          AppIcons.send,
                          isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue,
                          isDark,
                          cardColor,
                          shadow,
                        ),
                      ),
                    ],
                  ).animateEntrance(),
                  const SizedBox(height: 24),

                  // Create New Invoice button
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
                            adaptivePageRoute(builder: (_) => const InvoiceScreen()),
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
                                'Create New Invoice',
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

                  // Section tiles grid
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
                                builder: (_) => const InvoiceListScreen(
                                  statusFilter: InvoiceStatus.draft,
                                  title: 'Draft Invoices',
                                ),
                              ),
                            );
                            _loadData();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSectionTile(
                          icon: AppIcons.send,
                          label: 'Sent',
                          count: _sentCount,
                          color: isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue,
                          isDark: isDark,
                          cardColor: cardColor,
                          shadow: shadow,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              adaptivePageRoute(
                                builder: (_) => const InvoiceListScreen(
                                  statusFilter: InvoiceStatus.sent,
                                  title: 'Sent Invoices',
                                ),
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
                          icon: AppIcons.tickCircle,
                          label: 'Paid',
                          count: _paidCount,
                          color: AppTheme.successGreen,
                          isDark: isDark,
                          cardColor: cardColor,
                          shadow: shadow,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              adaptivePageRoute(
                                builder: (_) => const InvoiceListScreen(
                                  statusFilter: InvoiceStatus.paid,
                                  title: 'Paid Invoices',
                                ),
                              ),
                            );
                            _loadData();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSectionTile(
                          icon: AppIcons.people,
                          label: 'Customers',
                          count: _customerCount,
                          color: Colors.purple,
                          isDark: isDark,
                          cardColor: cardColor,
                          shadow: shadow,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              adaptivePageRoute(
                                builder: (_) => const SavedCustomersScreen(),
                              ),
                            );
                            _loadData();
                          },
                        ),
                      ),
                    ],
                  ).animateEntrance(delay: 240.ms),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSectionTile(
                          icon: AppIcons.bank,
                          label: 'Bank Details',
                          color: const Color(0xFF009688),
                          isDark: isDark,
                          cardColor: cardColor,
                          shadow: shadow,
                          onTap: () => Navigator.push(
                            context,
                            adaptivePageRoute(
                              builder: (_) => const BankDetailsScreen(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSectionTile(
                          icon: AppIcons.document,
                          label: 'PDF Design',
                          color: Colors.deepOrange,
                          isDark: isDark,
                          cardColor: cardColor,
                          shadow: shadow,
                          onTap: () => Navigator.push(
                            context,
                            adaptivePageRoute(
                              builder: (_) => const PdfDesignScreen(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ).animateEntrance(delay: 320.ms),
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
              children: List.generate(3, (_) => const Expanded(child: SkeletonBox(height: 80, borderRadius: 16)))
                  .expand((w) sync* { yield w; yield const SizedBox(width: 12); })
                  .toList()..removeLast(),
            ),
            const SizedBox(height: 24),
            const SkeletonBox(height: 56, borderRadius: 16),
            const SizedBox(height: 24),
            for (int i = 0; i < 3; i++) ...[
              Row(
                children: const [
                  Expanded(child: SkeletonBox(height: 140, borderRadius: 16)),
                  SizedBox(width: 12),
                  Expanded(child: SkeletonBox(height: 140, borderRadius: 16)),
                ],
              ),
              if (i < 2) const SizedBox(height: 12),
            ],
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
    List<BoxShadow> shadow,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: shadow,
      ),
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
