import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/invoice.dart';
import '../../services/firestore_sync_service.dart';
import '../../services/user_profile_service.dart';
import '../../services/invoice_pdf_service.dart';
import '../../services/payment_settings_service.dart';
import '../../theme/web_theme.dart';
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
      duration: FtMotion.slow,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: FtMotion.standardCurve,
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
    final currencyFmt = NumberFormat.currency(symbol: '£', decimalDigits: 2);

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        decoration: const BoxDecoration(
          color: FtColors.bg,
          boxShadow: FtShadows.lg,
          border: Border(left: BorderSide(color: FtColors.border, width: 1.5)),
        ),
        child: StreamBuilder<Invoice?>(
          stream: FirestoreSyncService.instance.getInvoiceStream(UserProfileService.instance.companyId!, widget.invoiceId),
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
                    Icon(AppIcons.warning, size: 32, color: FtColors.hint),
                    const SizedBox(height: 8),
                    Text('Invoice not found', style: FtText.bodySoft),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _closePanel,
                      style: TextButton.styleFrom(foregroundColor: FtColors.fg2),
                      child: Text('Close', style: FtText.button),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                _buildPanelHeader(invoice),
                Expanded(
                  child: ListView(
                    padding: FtSpacing.cardBody,
                    children: [
                      _buildStatusSection(invoice),
                      const SizedBox(height: 16),
                      _buildSection('Invoice Details', [
                        _detailRow('Invoice #', invoice.invoiceNumber),
                        _detailRow('Date', DateFormat('dd MMM yyyy').format(invoice.date)),
                        _detailRow('Due Date', DateFormat('dd MMM yyyy').format(invoice.dueDate)),
                        if (invoice.includeVat)
                          _detailRow('VAT', 'Included (20%)'),
                      ]),
                      const SizedBox(height: 16),
                      _buildSection('Customer', [
                        _detailRow('Name', invoice.customerName),
                        _detailRow('Address', invoice.customerAddress),
                        if (invoice.customerEmail != null)
                          _detailRow('Email', invoice.customerEmail!),
                      ]),
                      const SizedBox(height: 16),
                      _buildItemsTable(invoice, currencyFmt),
                      const SizedBox(height: 16),
                      _buildSection('Engineer', [
                        _detailRow('Name', invoice.engineerName),
                      ]),
                      if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildSection('Notes', [
                          Text(invoice.notes!, style: FtText.inter(size: 13, weight: FontWeight.w500, color: FtColors.fg1)),
                        ]),
                      ],
                      const SizedBox(height: 24),
                      _buildActionButtons(invoice),
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

  Widget _buildPanelHeader(Invoice invoice) {
    return Container(
      padding: FtSpacing.cardHeader,
      decoration: const BoxDecoration(
        color: FtColors.bgAlt,
        border: Border(
          bottom: BorderSide(color: FtColors.border, width: 1),
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
                  style: FtText.cardTitle,
                ),
                const SizedBox(height: 4),
                Text(
                  invoice.customerName,
                  style: FtText.helper,
                ),
              ],
            ),
          ),
          invoiceStatusBadge(invoice.status),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _closePanel,
            icon: Icon(AppIcons.close, color: FtColors.fg2),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection(Invoice invoice) {
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
              : FtColors.border;

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
                              : FtColors.border,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  invoiceStatusLabel(statuses[i]),
                  style: FtText.inter(
                    size: 9,
                    weight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                    color: isActive ? FtColors.fg1 : FtColors.hint,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildItemsTable(Invoice invoice, NumberFormat currencyFmt) {
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
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: FtColors.border),
              ),
            ),
            children: [
              _tableHeader('Description'),
              _tableHeader('Qty'),
              _tableHeader('Price'),
              _tableHeader('Total'),
            ],
          ),
          ...invoice.items.map((item) => TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(item.description, style: FtText.inter(size: 13, weight: FontWeight.w500, color: FtColors.fg1)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text('${item.quantity}', style: FtText.inter(size: 13, weight: FontWeight.w500, color: FtColors.fg1)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(currencyFmt.format(item.unitPrice), style: FtText.inter(size: 13, weight: FontWeight.w500, color: FtColors.fg1)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(currencyFmt.format(item.total), style: FtText.inter(size: 13, weight: FontWeight.w500, color: FtColors.fg1)),
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
              _totalRow('Subtotal', currencyFmt.format(invoice.subtotal)),
              if (invoice.includeVat) ...[
                const SizedBox(height: 4),
                _totalRow('VAT (20%)', currencyFmt.format(invoice.tax)),
              ],
              const SizedBox(height: 4),
              Text(
                'Total: ${currencyFmt.format(invoice.total)}',
                style: FtText.inter(size: 16, weight: FontWeight.w700, color: FtColors.fg1),
              ),
            ],
          ),
        ],
      ),
    ]);
  }

  Widget _tableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text.toUpperCase(), style: FtText.label),
    );
  }

  Widget _totalRow(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: FtText.helper),
        const SizedBox(width: 16),
        Text(value, style: FtText.inter(size: 13, weight: FontWeight.w500, color: FtColors.fg1)),
      ],
    );
  }

  Widget _buildActionButtons(Invoice invoice) {
    final btnStyle = OutlinedButton.styleFrom(
      foregroundColor: FtColors.fg1,
      side: const BorderSide(color: FtColors.border, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: FtRadii.mdAll),
      textStyle: FtText.button,
    );

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () => _downloadPdf(invoice),
          icon: Icon(AppIcons.download, size: 16),
          label: const Text('Download PDF'),
          style: btnStyle,
        ),
        if (invoice.customerEmail != null && invoice.customerEmail!.isNotEmpty)
          OutlinedButton.icon(
            onPressed: () => _emailInvoice(invoice),
            icon: Icon(AppIcons.sms, size: 16),
            label: const Text('Email'),
            style: btnStyle,
          ),
        if (invoice.status == InvoiceStatus.draft)
          OutlinedButton.icon(
            onPressed: () => _updateStatus(invoice, InvoiceStatus.sent),
            icon: Icon(AppIcons.send, size: 16),
            label: const Text('Mark Sent'),
            style: btnStyle.copyWith(
              foregroundColor: const WidgetStatePropertyAll(FtColors.info),
              side: WidgetStatePropertyAll(BorderSide(color: FtColors.info.withValues(alpha: 0.3), width: 1.5)),
            ),
          ),
        if (invoice.status == InvoiceStatus.sent)
          OutlinedButton.icon(
            onPressed: () => _updateStatus(invoice, InvoiceStatus.paid),
            icon: Icon(AppIcons.tickCircle, size: 16),
            label: const Text('Mark Paid'),
            style: btnStyle.copyWith(
              foregroundColor: const WidgetStatePropertyAll(FtColors.success),
              side: WidgetStatePropertyAll(BorderSide(color: FtColors.success.withValues(alpha: 0.3), width: 1.5)),
            ),
          ),
        if (invoice.status == InvoiceStatus.draft)
          OutlinedButton.icon(
            onPressed: () => widget.onEdit(invoice),
            icon: Icon(AppIcons.edit, size: 16),
            label: const Text('Edit'),
            style: btnStyle,
          ),
        OutlinedButton.icon(
          onPressed: () => _deleteInvoice(invoice),
          icon: Icon(AppIcons.trash, size: 16),
          label: const Text('Delete'),
          style: btnStyle.copyWith(
            foregroundColor: const WidgetStatePropertyAll(FtColors.danger),
            side: WidgetStatePropertyAll(BorderSide(color: FtColors.danger.withValues(alpha: 0.3), width: 1.5)),
          ),
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
      'Amount: £${invoice.total.toStringAsFixed(2)}\n'
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
            style: ElevatedButton.styleFrom(backgroundColor: FtColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirestoreSyncService.instance.deleteInvoiceFromFirestore(invoice.engineerId, invoice.id, companyId: invoice.companyId);
      _closePanel();
    }
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      padding: FtSpacing.cardBody,
      decoration: FtDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: FtText.label),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: FtText.helper),
          ),
          Expanded(
            child: Text(value, style: FtText.inter(size: 13, weight: FontWeight.w500, color: FtColors.fg1)),
          ),
        ],
      ),
    );
  }
}
