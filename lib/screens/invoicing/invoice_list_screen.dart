import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/invoice.dart';
import '../../services/database_helper.dart';
import '../../services/auth_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/animate_helpers.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/premium_toast.dart';
import '../tools/invoice_screen.dart';
import '../../widgets/adaptive_app_bar.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/premium_dialog.dart';
import '../../services/invoice_export_service.dart';
import '../../widgets/premium_bottom_sheet.dart';

class InvoiceListScreen extends StatefulWidget {
  final InvoiceStatus statusFilter;
  final String title;

  const InvoiceListScreen({
    super.key,
    required this.statusFilter,
    required this.title,
  });

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  final _dbHelper = DatabaseHelper.instance;
  final _authService = AuthService();

  List<Invoice> _invoices = [];
  bool _isLoading = true;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);

    try {
      final user = _authService.currentUser;
      if (user != null) {
        List<Invoice> invoices;
        switch (widget.statusFilter) {
          case InvoiceStatus.draft:
            invoices = await _dbHelper.getDraftInvoicesByEngineerId(user.uid);
            break;
          case InvoiceStatus.sent:
            invoices = await _dbHelper.getOutstandingInvoicesByEngineerId(
              user.uid,
            );
            break;
          case InvoiceStatus.paid:
            final all = await _dbHelper.getInvoicesByEngineerId(user.uid);
            invoices = all
                .where((i) => i.status == InvoiceStatus.paid)
                .toList();
            break;
        }
        setState(() {
          _invoices = invoices;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        context.showErrorToast('Error loading invoices: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdaptiveNavigationBar(
        title: widget.title,
        actions: widget.statusFilter == InvoiceStatus.paid
            ? [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Center(
                    child: OutlinedButton(
                      onPressed: _isExporting ? null : _exportInvoices,
                      child: _isExporting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Export'),
                    ),
                  ),
                ),
              ]
            : null,
      ),
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: SkeletonList(itemCount: 5, showLeading: true),
            )
          : _invoices.isEmpty
          ? _buildEmptyState()
          : AdaptiveRefreshIndicator(
              onRefresh: _loadInvoices,
              child: _buildInvoiceList(),
            ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? AppTheme.darkTextSecondary : Colors.grey[400];
    final textColor = isDark ? AppTheme.darkTextSecondary : Colors.grey[600];

    String message;
    IconData icon;
    switch (widget.statusFilter) {
      case InvoiceStatus.draft:
        icon = AppIcons.editNote;
        message = 'No draft invoices';
        break;
      case InvoiceStatus.sent:
        icon = AppIcons.send;
        message = 'No outstanding invoices';
        break;
      case InvoiceStatus.paid:
        icon = AppIcons.tickCircle;
        message = 'No paid invoices yet';
        break;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: iconColor),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Invoices with this status will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(color: textColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceList() {
    final currencyFormat = NumberFormat.currency(
      symbol: '\u00A3',
      decimalDigits: 2,
    );
    final dateFormat = DateFormat('dd/MM/yyyy');

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _invoices.length,
      itemBuilder: (context, index) {
        final invoice = _invoices[index];
        return _buildInvoiceCard(invoice, currencyFormat, dateFormat).animateListItem(index);
      },
    );
  }

  Widget _buildInvoiceCard(
    Invoice invoice,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite;

    Color statusColor;
    String statusLabel;
    switch (invoice.status) {
      case InvoiceStatus.draft:
        statusColor = AppTheme.warningOrange;
        statusLabel = 'Draft';
        break;
      case InvoiceStatus.sent:
        statusColor = AppTheme.primaryBlue;
        statusLabel = 'Sent';
        break;
      case InvoiceStatus.paid:
        statusColor = AppTheme.successGreen;
        statusLabel = 'Paid';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: isDark ? AppTheme.darkCardShadow : AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppTheme.cardPadding,
            vertical: 8,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          ),
          leading: CircleAvatar(
            backgroundColor: statusColor.withValues(alpha: 0.1),
            child: Icon(AppIcons.receipt, color: statusColor, size: 22),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  invoice.invoiceNumber,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                invoice.customerName.isNotEmpty
                    ? invoice.customerName
                    : 'No customer',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    currencyFormat.format(invoice.total),
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.darkPrimaryBlue
                          : AppTheme.primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateFormat.format(invoice.date),
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          isThreeLine: true,
          trailing: IconButton(
            icon: Icon(AppIcons.more),
            onPressed: () => showAdaptiveActionSheet(
              context: context,
              options: [
                ActionSheetOption(
                  label: 'Edit',
                  icon: AppIcons.edit,
                  onTap: () => _openInvoice(invoice),
                ),
                if (invoice.status == InvoiceStatus.sent)
                  ActionSheetOption(
                    label: 'Mark as Paid',
                    icon: AppIcons.tickCircle,
                    onTap: () => _markAsPaid(invoice),
                  ),
                ActionSheetOption(
                  label: 'Delete',
                  icon: AppIcons.trash,
                  isDestructive: true,
                  onTap: () => _confirmDelete(invoice),
                ),
              ],
            ),
          ),
          onTap: () => _openInvoice(invoice),
        ),
      ),
    );
  }

  Future<void> _exportInvoices() async {
    final years = InvoiceExportService.getAvailableTaxYears(_invoices);

    if (years.isEmpty) {
      context.showErrorToast('No invoices to export');
      return;
    }

    int selectedYear;
    if (years.length == 1) {
      selectedYear = years.first;
    } else {
      final picked = await showSimpleBottomSheet<int>(
        context: context,
        title: 'Select Tax Year',
        child: ListView(
          shrinkWrap: true,
          children: years.map((year) {
            return ListTile(
              title: Text('${year - 1}/$year'),
              onTap: () => Navigator.of(context).pop(year),
            );
          }).toList(),
        ),
      );
      if (picked == null) return;
      selectedYear = picked;
    }

    setState(() => _isExporting = true);
    try {
      await InvoiceExportService.exportAndShare(_invoices, selectedYear);
    } catch (e) {
      if (mounted) {
        context.showErrorToast('Export failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _openInvoice(Invoice invoice) async {
    await Navigator.push(
      context,
      adaptivePageRoute(
        builder: (_) => InvoiceScreen(existingInvoice: invoice),
      ),
    );
    _loadInvoices();
  }

  Future<void> _markAsPaid(Invoice invoice) async {
    try {
      await _dbHelper.updateInvoice(
        invoice.copyWith(status: InvoiceStatus.paid),
      );
      _loadInvoices();
      if (mounted) {
        context.showSuccessToast('Invoice marked as paid');
      }
    } catch (e) {
      if (mounted) {
        context.showErrorToast('Error: $e');
      }
    }
  }

  void _confirmDelete(Invoice invoice) async {
    final confirm = await showAdaptiveAlertDialog<bool>(
      context: context,
      title: 'Delete Invoice',
      message: 'Are you sure you want to delete "${invoice.invoiceNumber}"?',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      isDestructive: true,
    );

    if (confirm == true) {
      try {
        await _dbHelper.deleteInvoice(invoice.id);
        if (mounted) {
          _loadInvoices();
          context.showSuccessToast('Invoice deleted');
        }
      } catch (e) {
        if (mounted) {
          context.showErrorToast('Error: $e');
        }
      }
    }
  }
}
