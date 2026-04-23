import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/quote.dart';
import '../../services/quote_service.dart';
import '../../services/user_profile_service.dart';
import '../../models/permission.dart';
import '../../theme/web_theme.dart';
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

  bool _hasPermission(AppPermission perm) {
    return UserProfileService.instance.hasPermission(perm);
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
                    Icon(AppIcons.warning, size: 32, color: FtColors.hint),
                    const SizedBox(height: 8),
                    Text('Quote not found', style: FtText.bodySoft),
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
                _buildPanelHeader(quote),
                Expanded(
                  child: ListView(
                    padding: FtSpacing.cardBody,
                    children: [
                      _buildStatusSection(quote),
                      const SizedBox(height: 16),
                      _buildSection('Quote Details', [
                        _detailRow('Quote #', quote.quoteNumber),
                        _detailRow('Created', DateFormat('dd MMM yyyy').format(quote.createdAt)),
                        _detailRow('Valid Until', DateFormat('dd MMM yyyy').format(quote.validUntil)),
                        if (quote.sentAt != null)
                          _detailRow('Sent', DateFormat('dd MMM yyyy').format(quote.sentAt!)),
                        if (quote.respondedAt != null)
                          _detailRow('Responded', DateFormat('dd MMM yyyy').format(quote.respondedAt!)),
                      ]),
                      const SizedBox(height: 16),
                      _buildSection('Customer & Site', [
                        _detailRow('Customer', quote.customerName),
                        _detailRow('Address', quote.customerAddress),
                        if (quote.customerEmail != null)
                          _detailRow('Email', quote.customerEmail!),
                        if (quote.customerPhone != null)
                          _detailRow('Phone', quote.customerPhone!),
                        _detailRow('Site', quote.siteName),
                      ]),
                      if (quote.defectDescription != null) ...[
                        const SizedBox(height: 16),
                        _buildSection('Linked Defect', [
                          _detailRow('Description', quote.defectDescription!),
                          if (quote.defectSeverity != null)
                            _detailRow('Severity', quote.defectSeverity!),
                        ]),
                      ],
                      const SizedBox(height: 16),
                      _buildItemsTable(quote, currencyFmt),
                      const SizedBox(height: 16),
                      _buildSection('Engineer', [
                        _detailRow('Name', quote.engineerName),
                      ]),
                      if (quote.notes != null && quote.notes!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildSection('Notes', [
                          Text(quote.notes!, style: FtText.inter(size: 13, weight: FontWeight.w500, color: FtColors.fg1)),
                        ]),
                      ],
                      const SizedBox(height: 24),
                      _buildActionButtons(quote),
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

  Widget _buildPanelHeader(Quote quote) {
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
                  quote.quoteNumber,
                  style: FtText.cardTitle,
                ),
                const SizedBox(height: 4),
                Text(
                  quote.customerName,
                  style: FtText.helper,
                ),
              ],
            ),
          ),
          quoteStatusBadge(quote.status),
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

  Widget _buildStatusSection(Quote quote) {
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
              ? FtColors.danger
              : isActive
                  ? quoteStatusColor(statuses[i])
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
                          color: !isDeclined && i < currentIndex
                              ? quoteStatusColor(statuses[i + 1])
                              : FtColors.border,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  quoteStatusLabel(statuses[i]),
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

  Widget _buildItemsTable(Quote quote, NumberFormat currencyFmt) {
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
          ...quote.items.map((item) => TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.description, style: FtText.inter(size: 13, weight: FontWeight.w500, color: FtColors.fg1)),
                    if (item.category != null)
                      Text(item.category!, style: FtText.helper),
                  ],
                ),
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
              _totalRow('Subtotal', currencyFmt.format(quote.subtotal)),
              if (quote.includeVat) ...[
                const SizedBox(height: 4),
                _totalRow('VAT (20%)', currencyFmt.format(quote.vatAmount)),
              ],
              const SizedBox(height: 4),
              Text(
                'Total: ${currencyFmt.format(quote.total)}',
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

  Widget _buildActionButtons(Quote quote) {
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
          onPressed: () => _downloadPdf(quote),
          icon: Icon(AppIcons.download, size: 16),
          label: const Text('Download PDF'),
          style: btnStyle,
        ),
        if (quote.status == QuoteStatus.draft && _hasPermission(AppPermission.quotesSend))
          OutlinedButton.icon(
            onPressed: () => _updateStatus(quote, QuoteStatus.sent),
            icon: Icon(AppIcons.send, size: 16),
            label: const Text('Mark Sent'),
            style: btnStyle.copyWith(
              foregroundColor: WidgetStatePropertyAll(FtColors.info),
              side: WidgetStatePropertyAll(BorderSide(color: FtColors.info.withValues(alpha: 0.3), width: 1.5)),
            ),
          ),
        if (quote.status == QuoteStatus.sent && _hasPermission(AppPermission.quotesApprove)) ...[
          OutlinedButton.icon(
            onPressed: () => _updateStatus(quote, QuoteStatus.approved),
            icon: Icon(AppIcons.tickCircle, size: 16),
            label: const Text('Approve'),
            style: btnStyle.copyWith(
              foregroundColor: const WidgetStatePropertyAll(FtColors.success),
              side: WidgetStatePropertyAll(BorderSide(color: FtColors.success.withValues(alpha: 0.3), width: 1.5)),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _updateStatus(quote, QuoteStatus.declined),
            icon: Icon(AppIcons.close, size: 16),
            label: const Text('Decline'),
            style: btnStyle.copyWith(
              foregroundColor: const WidgetStatePropertyAll(FtColors.danger),
              side: WidgetStatePropertyAll(BorderSide(color: FtColors.danger.withValues(alpha: 0.3), width: 1.5)),
            ),
          ),
        ],
        if (quote.status == QuoteStatus.approved && _hasPermission(AppPermission.quotesConvert))
          OutlinedButton.icon(
            onPressed: () => _convertToJob(quote),
            icon: Icon(AppIcons.refresh, size: 16),
            label: const Text('Convert to Job'),
            style: btnStyle.copyWith(
              foregroundColor: const WidgetStatePropertyAll(FtColors.primary),
              side: WidgetStatePropertyAll(BorderSide(color: FtColors.primary.withValues(alpha: 0.3), width: 1.5)),
            ),
          ),
        if (quote.status == QuoteStatus.draft && _hasPermission(AppPermission.quotesEdit))
          OutlinedButton.icon(
            onPressed: () => widget.onEdit(quote),
            icon: Icon(AppIcons.edit, size: 16),
            label: const Text('Edit'),
            style: btnStyle,
          ),
        OutlinedButton.icon(
          onPressed: () => _deleteQuote(quote),
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
            style: ElevatedButton.styleFrom(backgroundColor: FtColors.primary, foregroundColor: Colors.white),
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
            style: ElevatedButton.styleFrom(backgroundColor: FtColors.danger),
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
