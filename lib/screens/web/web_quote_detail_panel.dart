import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/quote.dart';
import '../../services/quote_service.dart';
import '../../services/user_profile_service.dart';
import '../../models/permission.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/premium_toast.dart';
import '../../utils/download_stub.dart' if (dart.library.html) '../../utils/download_web.dart';
import '../../services/quote_pdf_service.dart';
import 'dashboard/quote_helpers.dart';

class WebQuoteDetailPanel extends StatefulWidget {
  final String engineerId;
  final String quoteId;
  final VoidCallback onClose;
  final void Function(Quote quote) onEdit;
  final bool animateIn;

  const WebQuoteDetailPanel({
    super.key,
    required this.engineerId,
    required this.quoteId,
    required this.onClose,
    required this.onEdit,
    this.animateIn = true,
  });

  @override
  State<WebQuoteDetailPanel> createState() => _WebQuoteDetailPanelState();
}

class _WebQuoteDetailPanelState extends State<WebQuoteDetailPanel>
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

  bool _hasPermission(AppPermission perm) {
    return UserProfileService.instance.hasPermission(perm);
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
        child: StreamBuilder<Quote?>(
          stream: QuoteService.instance.getQuoteStream(UserProfileService.instance.companyId!, widget.quoteId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: AdaptiveLoadingIndicator());
            }

            final quote = snapshot.data;
            if (quote == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(AppIcons.warning, size: 32, color: AppTheme.mediumGrey),
                    const SizedBox(height: 8),
                    const Text('Quote not found'),
                    const SizedBox(height: 16),
                    TextButton(onPressed: _closePanel, child: const Text('Close')),
                  ],
                ),
              );
            }

            return Column(
              children: [
                _buildPanelHeader(quote, isDark),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildStatusSection(quote, isDark),
                      const SizedBox(height: 16),
                      _buildSection('Quote Details', [
                        _detailRow('Quote #', quote.quoteNumber, isDark),
                        _detailRow('Created', DateFormat('dd MMM yyyy').format(quote.createdAt), isDark),
                        _detailRow('Valid Until', DateFormat('dd MMM yyyy').format(quote.validUntil), isDark),
                        if (quote.sentAt != null)
                          _detailRow('Sent', DateFormat('dd MMM yyyy').format(quote.sentAt!), isDark),
                        if (quote.respondedAt != null)
                          _detailRow('Responded', DateFormat('dd MMM yyyy').format(quote.respondedAt!), isDark),
                      ], isDark),
                      const SizedBox(height: 16),
                      _buildSection('Customer & Site', [
                        _detailRow('Customer', quote.customerName, isDark),
                        _detailRow('Address', quote.customerAddress, isDark),
                        if (quote.customerEmail != null)
                          _detailRow('Email', quote.customerEmail!, isDark),
                        if (quote.customerPhone != null)
                          _detailRow('Phone', quote.customerPhone!, isDark),
                        _detailRow('Site', quote.siteName, isDark),
                      ], isDark),
                      if (quote.defectDescription != null) ...[
                        const SizedBox(height: 16),
                        _buildSection('Linked Defect', [
                          _detailRow('Description', quote.defectDescription!, isDark),
                          if (quote.defectSeverity != null)
                            _detailRow('Severity', quote.defectSeverity!, isDark),
                        ], isDark),
                      ],
                      const SizedBox(height: 16),
                      _buildItemsTable(quote, isDark, currencyFmt),
                      const SizedBox(height: 16),
                      _buildSection('Engineer', [
                        _detailRow('Name', quote.engineerName, isDark),
                      ], isDark),
                      if (quote.notes != null && quote.notes!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildSection('Notes', [
                          Text(quote.notes!, style: const TextStyle(fontSize: 13)),
                        ], isDark),
                      ],
                      const SizedBox(height: 24),
                      _buildActionButtons(quote, isDark),
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

  Widget _buildPanelHeader(Quote quote, bool isDark) {
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
                  quote.quoteNumber,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text(
                  quote.customerName,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
                  ),
                ),
              ],
            ),
          ),
          quoteStatusBadge(quote.status),
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

  Widget _buildStatusSection(Quote quote, bool isDark) {
    final statuses = [
      QuoteStatus.draft,
      QuoteStatus.sent,
      QuoteStatus.approved,
      QuoteStatus.converted,
    ];
    final currentIndex = statuses.indexOf(quote.status);
    final isDeclined = quote.status == QuoteStatus.declined;

    return SizedBox(
      height: 56,
      child: Row(
        children: List.generate(statuses.length, (i) {
          final isActive = !isDeclined && i <= currentIndex;
          final isCurrent = !isDeclined && i == currentIndex;
          final color = isDeclined && i == 0
              ? AppTheme.errorRed
              : isActive
                  ? quoteStatusColor(statuses[i])
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
                          color: !isDeclined && i < currentIndex
                              ? quoteStatusColor(statuses[i + 1])
                              : (isDark ? AppTheme.darkDivider : Colors.grey.shade300),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  quoteStatusLabel(statuses[i]),
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

  Widget _buildItemsTable(Quote quote, bool isDark, NumberFormat currencyFmt) {
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
          ...quote.items.map((item) => TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.description, style: const TextStyle(fontSize: 13)),
                    if (item.category != null)
                      Text(
                        item.category!,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
                        ),
                      ),
                  ],
                ),
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
              _totalRow('Subtotal', currencyFmt.format(quote.subtotal), isDark),
              if (quote.includeVat) ...[
                const SizedBox(height: 4),
                _totalRow('VAT (20%)', currencyFmt.format(quote.vatAmount), isDark),
              ],
              const SizedBox(height: 4),
              Text(
                'Total: ${currencyFmt.format(quote.total)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
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
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
          ),
        ),
        const SizedBox(width: 16),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildActionButtons(Quote quote, bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () => _downloadPdf(quote),
          icon: Icon(AppIcons.download, size: 16),
          label: const Text('Download PDF'),
        ),
        if (quote.status == QuoteStatus.draft && _hasPermission(AppPermission.quotesSend))
          OutlinedButton.icon(
            onPressed: () => _updateStatus(quote, QuoteStatus.sent),
            icon: Icon(AppIcons.send, size: 16),
            label: const Text('Mark Sent'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.blue),
          ),
        if (quote.status == QuoteStatus.sent && _hasPermission(AppPermission.quotesApprove)) ...[
          OutlinedButton.icon(
            onPressed: () => _updateStatus(quote, QuoteStatus.approved),
            icon: Icon(AppIcons.tickCircle, size: 16),
            label: const Text('Approve'),
            style: OutlinedButton.styleFrom(foregroundColor: AppTheme.successGreen),
          ),
          OutlinedButton.icon(
            onPressed: () => _updateStatus(quote, QuoteStatus.declined),
            icon: Icon(AppIcons.close, size: 16),
            label: const Text('Decline'),
            style: OutlinedButton.styleFrom(foregroundColor: AppTheme.errorRed),
          ),
        ],
        if (quote.status == QuoteStatus.approved && _hasPermission(AppPermission.quotesConvert))
          OutlinedButton.icon(
            onPressed: () => _convertToJob(quote),
            icon: Icon(AppIcons.refresh, size: 16),
            label: const Text('Convert to Job'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.purple),
          ),
        if (quote.status == QuoteStatus.draft && _hasPermission(AppPermission.quotesEdit))
          OutlinedButton.icon(
            onPressed: () => widget.onEdit(quote),
            icon: Icon(AppIcons.edit, size: 16),
            label: const Text('Edit'),
          ),
        OutlinedButton.icon(
          onPressed: () => _deleteQuote(quote),
          icon: Icon(AppIcons.trash, size: 16),
          label: const Text('Delete'),
          style: OutlinedButton.styleFrom(foregroundColor: AppTheme.errorRed),
        ),
      ],
    );
  }

  Future<void> _downloadPdf(Quote quote) async {
    try {
      showPremiumToast(context: context, message: 'Generating PDF...');
      final pdfBytes = await QuotePdfService.generateQuotePdf(quote);
      final filename = 'Quote_${quote.quoteNumber}_${DateFormat('yyyyMMdd').format(quote.createdAt)}.pdf';
      downloadFile(pdfBytes, filename);
    } catch (e) {
      if (mounted) {
        showPremiumToast(context: context, message: 'Failed to generate PDF', variant: ToastVariant.error);
      }
    }
  }

  Future<void> _updateStatus(Quote quote, QuoteStatus newStatus) async {
    try {
      final updated = quote.copyWith(
        status: newStatus,
        sentAt: newStatus == QuoteStatus.sent && quote.sentAt == null ? DateTime.now() : quote.sentAt,
        respondedAt: (newStatus == QuoteStatus.approved || newStatus == QuoteStatus.declined) && quote.respondedAt == null
            ? DateTime.now()
            : quote.respondedAt,
        lastModifiedAt: DateTime.now(),
      );
      await QuoteService.instance.saveQuoteToFirestore(updated);
      if (mounted) {
        showPremiumToast(
          context: context,
          message: 'Quote marked as ${quoteStatusLabel(newStatus).toLowerCase()}',
        );
      }
    } catch (e) {
      if (mounted) {
        showPremiumToast(context: context, message: 'Failed to update status', variant: ToastVariant.error);
      }
    }
  }

  Future<void> _convertToJob(Quote quote) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Convert to Job?'),
        content: Text(
          'This will create a new dispatched job from quote ${quote.quoteNumber} and mark the quote as converted.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
            child: const Text('Convert'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await QuoteService.instance.convertQuoteToJob(quote);
      if (mounted) {
        showPremiumToast(context: context, message: 'Quote converted to job');
      }
    } catch (e) {
      if (mounted) {
        showPremiumToast(context: context, message: 'Failed to convert: $e', variant: ToastVariant.error);
      }
    }
  }

  Future<void> _deleteQuote(Quote quote) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Quote?'),
        content: Text('This will permanently delete quote ${quote.quoteNumber}. This cannot be undone.'),
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
      await QuoteService.instance.deleteQuoteFromFirestore(quote.engineerId, quote.id, companyId: quote.companyId);
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
