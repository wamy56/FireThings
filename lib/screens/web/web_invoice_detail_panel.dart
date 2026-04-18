import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/invoice.dart';
import '../../services/firestore_sync_service.dart';
import '../../services/invoice_pdf_service.dart';
import '../../services/payment_settings_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/premium_toast.dart';
import '../../utils/download_stub.dart' if (dart.library.html) '../../utils/download_web.dart';
import 'dashboard/invoice_helpers.dart';

class WebInvoiceDetailPanel extends StatefulWidget {
  final String engineerId;
  final String invoiceId;
  final VoidCallback onClose;
  final void Function(Invoice invoice) onEdit;
  final bool animateIn;

  const WebInvoiceDetailPanel({
    super.key,
    required this.engineerId,
    required this.invoiceId,
    required this.onClose,
    required this.onEdit,
    this.animateIn = true,
  });

  @override
  State<WebInvoiceDetailPanel> createState() => _WebInvoiceDetailPanelState();
}

class _WebInvoiceDetailPanelState extends State<WebInvoiceDetailPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: AppTheme.normalAnimation,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: AppTheme.defaultCurve,
    ));
    if (widget.animateIn) {
      _slideController.forward();
    } else {
      _slideController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _closePanel() async {
    _slideController.reverse();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFmt = NumberFormat.currency(symbol: '\u00A3', decimalDigits: 2);

    return SlideTransition(
      position: _slideAnimation,
      child: Material(
        elevation: 8,
        color: isDark ? AppTheme.darkSurface : Colors.white,
        child: StreamBuilder<Invoice?>(
          stream: FirestoreSyncService.instance.getInvoiceStream(widget.engineerId, widget.invoiceId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: AdaptiveLoadingIndicator());
            }

            final invoice = snapshot.data;
            if (invoice == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(AppIcons.warning, size: 32, color: AppTheme.mediumGrey),
                    const SizedBox(height: 8),
                    const Text('Invoice not found'),
                    const SizedBox(height: 16),
                    TextButton(onPressed: _closePanel, child: const Text('Close')),
                  ],
                ),
              );
            }

            return Column(
              children: [
                _buildPanelHeader(invoice, isDark),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildStatusSection(invoice, isDark),
                      const SizedBox(height: 16),
                      _buildSection('Invoice Details', [
                        _detailRow('Invoice #', invoice.invoiceNumber, isDark),
                        _detailRow('Date', DateFormat('dd MMM yyyy').format(invoice.date), isDark),
                        _detailRow('Due Date', DateFormat('dd MMM yyyy').format(invoice.dueDate), isDark),
                        if (invoice.includeVat)
                          _detailRow('VAT', 'Included (20%)', isDark),
                      ], isDark),
                      const SizedBox(height: 16),
                      _buildSection('Customer', [
                        _detailRow('Name', invoice.customerName, isDark),
                        _detailRow('Address', invoice.customerAddress, isDark),
                        if (invoice.customerEmail != null)
                          _detailRow('Email', invoice.customerEmail!, isDark),
                      ], isDark),
                      const SizedBox(height: 16),
                      _buildItemsTable(invoice, isDark, currencyFmt),
                      const SizedBox(height: 16),
                      _buildSection('Engineer', [
                        _detailRow('Name', invoice.engineerName, isDark),
                      ], isDark),
                      if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildSection('Notes', [
                          Text(invoice.notes!, style: const TextStyle(fontSize: 13)),
                        ], isDark),
                      ],
                      const SizedBox(height: 24),
                      _buildActionButtons(invoice, isDark),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPanelHeader(Invoice invoice, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceElevated : Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppTheme.darkDivider : AppTheme.dividerColor,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invoice.invoiceNumber,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text(
                  invoice.customerName,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
                  ),
                ),
              ],
            ),
          ),
          invoiceStatusBadge(invoice.status),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _closePanel,
            icon: const Icon(Icons.close),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection(Invoice invoice, bool isDark) {
    final statuses = [InvoiceStatus.draft, InvoiceStatus.sent, InvoiceStatus.paid];
    final currentIndex = statuses.indexOf(invoice.status);

    return SizedBox(
      height: 56,
      child: Row(
        children: List.generate(statuses.length, (i) {
          final isActive = i <= currentIndex;
          final isCurrent = i == currentIndex;
          final color = isActive
              ? invoiceStatusColor(statuses[i])
              : (isDark ? AppTheme.darkDivider : Colors.grey.shade300);

          return Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (i > 0)
                      Expanded(child: Container(height: 2, color: color)),
                    Container(
                      width: isCurrent ? 14 : 10,
                      height: isCurrent ? 14 : 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive ? color : Colors.transparent,
                        border: Border.all(color: color, width: 2),
                      ),
                    ),
                    if (i < statuses.length - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: i < currentIndex
                              ? invoiceStatusColor(statuses[i + 1])
                              : (isDark ? AppTheme.darkDivider : Colors.grey.shade300),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  invoiceStatusLabel(statuses[i]),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                    color: isActive
                        ? (isDark ? Colors.white : AppTheme.darkGrey)
                        : (isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildItemsTable(Invoice invoice, bool isDark, NumberFormat currencyFmt) {
    return _buildSection('Items', [
      Table(
        columnWidths: const {
          0: FlexColumnWidth(3),
          1: FixedColumnWidth(50),
          2: FixedColumnWidth(80),
          3: FixedColumnWidth(90),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppTheme.darkDivider : AppTheme.dividerColor,
                ),
              ),
            ),
            children: [
              _tableHeader('Description', isDark),
              _tableHeader('Qty', isDark),
              _tableHeader('Price', isDark),
              _tableHeader('Total', isDark),
            ],
          ),
          ...invoice.items.map((item) => TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(item.description, style: const TextStyle(fontSize: 13)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text('${item.quantity}', style: const TextStyle(fontSize: 13)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(currencyFmt.format(item.unitPrice), style: const TextStyle(fontSize: 13)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(currencyFmt.format(item.total), style: const TextStyle(fontSize: 13)),
              ),
            ],
          )),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _totalRow('Subtotal', currencyFmt.format(invoice.subtotal), isDark),
              if (invoice.includeVat) ...[
                const SizedBox(height: 4),
                _totalRow('VAT (20%)', currencyFmt.format(invoice.tax), isDark),
              ],
              const SizedBox(height: 4),
              Text(
                'Total: ${currencyFmt.format(invoice.total)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    ], isDark);
  }

  Widget _tableHeader(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
        ),
      ),
    );
  }

  Widget _totalRow(String label, String value, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(
          fontSize: 13,
          color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
        )),
        const SizedBox(width: 16),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildActionButtons(Invoice invoice, bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () => _downloadPdf(invoice),
          icon: Icon(AppIcons.download, size: 16),
          label: const Text('Download PDF'),
        ),
        if (invoice.customerEmail != null && invoice.customerEmail!.isNotEmpty)
          OutlinedButton.icon(
            onPressed: () => _emailInvoice(invoice),
            icon: Icon(AppIcons.sms, size: 16),
            label: const Text('Email'),
          ),
        if (invoice.status == InvoiceStatus.draft)
          OutlinedButton.icon(
            onPressed: () => _updateStatus(invoice, InvoiceStatus.sent),
            icon: Icon(AppIcons.send, size: 16),
            label: const Text('Mark Sent'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.blue),
          ),
        if (invoice.status == InvoiceStatus.sent)
          OutlinedButton.icon(
            onPressed: () => _updateStatus(invoice, InvoiceStatus.paid),
            icon: Icon(AppIcons.tickCircle, size: 16),
            label: const Text('Mark Paid'),
            style: OutlinedButton.styleFrom(foregroundColor: AppTheme.successGreen),
          ),
        if (invoice.status == InvoiceStatus.draft)
          OutlinedButton.icon(
            onPressed: () => widget.onEdit(invoice),
            icon: Icon(AppIcons.edit, size: 16),
            label: const Text('Edit'),
          ),
        OutlinedButton.icon(
          onPressed: () => _deleteInvoice(invoice),
          icon: Icon(AppIcons.trash, size: 16),
          label: const Text('Delete'),
          style: OutlinedButton.styleFrom(foregroundColor: AppTheme.errorRed),
        ),
      ],
    );
  }

  Future<void> _downloadPdf(Invoice invoice) async {
    try {
      showPremiumToast(context: context, message: 'Generating PDF...');
      final paymentDetails = await PaymentSettingsService.getPaymentDetails();
      final pdfBytes = await InvoicePDFService.generateInvoicePDF(invoice, paymentDetails);
      final filename = 'Invoice_${invoice.invoiceNumber}_${DateFormat('yyyyMMdd').format(invoice.date)}.pdf';
      downloadFile(pdfBytes, filename);
    } catch (e) {
      if (mounted) {
        showPremiumToast(context: context, message: 'Failed to generate PDF', variant: ToastVariant.error);
      }
    }
  }

  Future<void> _emailInvoice(Invoice invoice) async {
    final email = invoice.customerEmail ?? '';
    final subject = Uri.encodeComponent(
      'Invoice ${invoice.invoiceNumber} - ${invoice.customerName}',
    );
    final body = Uri.encodeComponent(
      'Hi,\n\nPlease find attached invoice ${invoice.invoiceNumber}.\n\n'
      'Amount: \u00A3${invoice.total.toStringAsFixed(2)}\n'
      'Due Date: ${DateFormat('dd/MM/yyyy').format(invoice.dueDate)}\n\n'
      'Kind regards',
    );
    final mailto = Uri.parse('mailto:$email?subject=$subject&body=$body');
    if (await canLaunchUrl(mailto)) {
      await launchUrl(mailto);
    }
  }

  Future<void> _updateStatus(Invoice invoice, InvoiceStatus newStatus) async {
    try {
      final updated = invoice.copyWith(
        status: newStatus,
        lastModifiedAt: DateTime.now(),
      );
      await FirestoreSyncService.instance.saveInvoiceToFirestore(updated);
      if (mounted) {
        showPremiumToast(
          context: context,
          message: 'Invoice marked as ${invoiceStatusLabel(newStatus).toLowerCase()}',
        );
      }
    } catch (e) {
      if (mounted) {
        showPremiumToast(context: context, message: 'Failed to update status', variant: ToastVariant.error);
      }
    }
  }

  Future<void> _deleteInvoice(Invoice invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Invoice?'),
        content: Text('This will permanently delete invoice ${invoice.invoiceNumber}. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirestoreSyncService.instance.deleteInvoiceFromFirestore(invoice.engineerId, invoice.id);
      _closePanel();
    }
  }

  Widget _buildSection(String title, List<Widget> children, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.cardPadding),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceElevated : AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(
          color: isDark ? AppTheme.darkDivider : AppTheme.dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
