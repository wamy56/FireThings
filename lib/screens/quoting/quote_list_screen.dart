import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../utils/icon_map.dart';
import '../../utils/theme.dart';
import '../../utils/animate_helpers.dart';
import '../../utils/adaptive_widgets.dart';
import '../../mixins/multi_select_mixin.dart';
import '../../services/quote_service.dart';
import '../../widgets/adaptive_app_bar.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/premium_toast.dart';
import '../../widgets/premium_dialog.dart';
import '../../widgets/selection_app_bar.dart';
import '../../widgets/selectable_avatar.dart';
import 'quote_screen.dart';

class QuoteListScreen extends StatefulWidget {
  final QuoteStatus? statusFilter;
  final String title;

  const QuoteListScreen({
    super.key,
    this.statusFilter,
    this.title = 'Quotes',
  });

  @override
  State<QuoteListScreen> createState() => _QuoteListScreenState();
}

class _QuoteListScreenState extends State<QuoteListScreen>
    with MultiSelectMixin {
  List<Quote> _quotes = [];
  bool _isLoading = true;
  QuoteStatus? _selectedFilter;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.statusFilter;
    _loadQuotes();
  }

  Future<void> _loadQuotes() async {
    setState(() => _isLoading = true);
    try {
      final quotes = _selectedFilter != null
          ? await QuoteService.instance.getQuotesByStatus(_selectedFilter!)
          : await QuoteService.instance.getQuotes();
      setState(() {
        _quotes = quotes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading quotes: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) exitSelectionMode();
      },
      child: Scaffold(
        appBar: isSelectionMode
            ? SelectionAppBar(
                selectedCount: selectedCount,
                isAllSelected:
                    _quotes.isNotEmpty && selectedCount == _quotes.length,
                onClose: exitSelectionMode,
                onSelectAll: (selectAll) {
                  if (selectAll) {
                    this.selectAll(_quotes.map((q) => q.id).toList());
                  } else {
                    deselectAll();
                  }
                },
                onDelete: _bulkDelete,
              )
            : AdaptiveNavigationBar(
                title: widget.title,
                actions: [
                  TextButton(
                    onPressed: _quotes.isEmpty ? null : enterSelectionMode,
                    child: const Text('Select'),
                  ),
                ],
              ),
        body: Column(
          children: [
            _buildFilterChips(),
            Expanded(
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: SkeletonList(itemCount: 5, showLeading: true),
                    )
                  : _quotes.isEmpty
                      ? _buildEmptyState()
                      : AdaptiveRefreshIndicator(
                          onRefresh: _loadQuotes,
                          child: _buildQuoteList(),
                        ),
            ),
          ],
        ),
        floatingActionButton: isSelectionMode
            ? null
            : FloatingActionButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    adaptivePageRoute(builder: (_) => const QuoteScreen()),
                  );
                  _loadQuotes();
                },
                backgroundColor: AppTheme.primaryBlue,
                child: const Icon(AppIcons.addCircle, color: Colors.white),
              ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildChip('All', null),
          _buildChip('Drafts', QuoteStatus.draft),
          _buildChip('Sent', QuoteStatus.sent),
          _buildChip('Approved', QuoteStatus.approved),
          _buildChip('Declined', QuoteStatus.declined),
          _buildChip('Converted', QuoteStatus.converted),
        ],
      ),
    );
  }

  Widget _buildChip(String label, QuoteStatus? status) {
    final isActive = _selectedFilter == status;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isActive,
        onSelected: (_) {
          if (isSelectionMode) exitSelectionMode();
          setState(() => _selectedFilter = status);
          _loadQuotes();
        },
        selectedColor: AppTheme.primaryBlue.withValues(alpha: 0.2),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? AppTheme.darkTextSecondary : Colors.grey[400];
    final textColor = isDark ? AppTheme.darkTextSecondary : Colors.grey[600];

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(AppIcons.document, size: 80, color: iconColor),
            const SizedBox(height: 16),
            Text(
              _selectedFilter != null
                  ? 'No ${_selectedFilter!.name} quotes'
                  : 'No quotes yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Quotes with this status will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(color: textColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuoteList() {
    final currencyFormat = NumberFormat.currency(
      symbol: '\u00A3',
      decimalDigits: 2,
    );
    final dateFormat = DateFormat('dd/MM/yyyy');

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      itemCount: _quotes.length,
      itemBuilder: (context, index) {
        return _buildQuoteCard(_quotes[index], currencyFormat, dateFormat)
            .animateListItem(index);
      },
    );
  }

  Widget _buildQuoteCard(
    Quote quote,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = isSelected(quote.id);
    final isOverdue = quote.status == QuoteStatus.sent &&
        quote.validUntil.isBefore(DateTime.now());

    final statusColor = _getStatusColor(quote.status);
    final statusLabel =
        quote.status.name[0].toUpperCase() + quote.status.name.substring(1);

    return AnimatedContainer(
      duration: AppTheme.fastAnimation,
      curve: AppTheme.defaultCurve,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: selected
            ? (isDark
                ? AppTheme.primaryBlue.withValues(alpha: 0.15)
                : AppTheme.primaryBlue.withValues(alpha: 0.06))
            : (isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: isDark ? AppTheme.darkCardShadow : AppTheme.cardShadow,
        border: isOverdue
            ? Border.all(color: AppTheme.errorRed, width: 1.5)
            : null,
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
          leading: SelectableAvatar(
            isSelectionMode: isSelectionMode,
            isSelected: selected,
            child: CircleAvatar(
              backgroundColor: statusColor.withValues(alpha: 0.1),
              child:
                  Icon(AppIcons.receiptItem, color: statusColor, size: 22),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  quote.quoteNumber,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                quote.customerName.isNotEmpty
                    ? quote.customerName
                    : 'No customer',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    currencyFormat.format(quote.total),
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.darkPrimaryBlue
                          : AppTheme.primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateFormat.format(quote.createdAt),
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  if (isOverdue) ...[
                    const SizedBox(width: 8),
                    const Text(
                      'OVERDUE',
                      style: TextStyle(
                        color: AppTheme.errorRed,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          isThreeLine: true,
          trailing: isSelectionMode
              ? null
              : IconButton(
                  icon: const Icon(AppIcons.more),
                  onPressed: () => _showQuoteActions(quote),
                ),
          onTap: () {
            if (isSelectionMode) {
              toggleSelection(quote.id);
            } else {
              _openQuote(quote);
            }
          },
        ),
      ),
    );
  }

  Color _getStatusColor(QuoteStatus status) {
    switch (status) {
      case QuoteStatus.draft:
        return AppTheme.warningOrange;
      case QuoteStatus.sent:
        return AppTheme.primaryBlue;
      case QuoteStatus.approved:
        return AppTheme.successGreen;
      case QuoteStatus.declined:
        return AppTheme.errorRed;
      case QuoteStatus.converted:
        return Colors.purple;
    }
  }

  void _showQuoteActions(Quote quote) {
    showAdaptiveActionSheet(
      context: context,
      options: [
        ActionSheetOption(
          label: 'Edit',
          icon: AppIcons.edit,
          onTap: () => _openQuote(quote),
        ),
        if (quote.status == QuoteStatus.draft)
          ActionSheetOption(
            label: 'Mark as Sent',
            icon: AppIcons.send,
            onTap: () => _updateStatus(quote, QuoteStatus.sent),
          ),
        if (quote.status == QuoteStatus.sent)
          ActionSheetOption(
            label: 'Mark as Approved',
            icon: AppIcons.tickCircle,
            onTap: () => _updateStatus(quote, QuoteStatus.approved),
          ),
        if (quote.status == QuoteStatus.sent)
          ActionSheetOption(
            label: 'Mark as Declined',
            icon: AppIcons.close,
            onTap: () => _updateStatus(quote, QuoteStatus.declined),
          ),
        ActionSheetOption(
          label: 'Delete',
          icon: AppIcons.trash,
          isDestructive: true,
          onTap: () => _confirmDelete(quote),
        ),
      ],
    );
  }

  Future<void> _openQuote(Quote quote) async {
    await Navigator.push(
      context,
      adaptivePageRoute(
        builder: (_) => QuoteScreen(existingQuote: quote),
      ),
    );
    _loadQuotes();
  }

  Future<void> _updateStatus(Quote quote, QuoteStatus newStatus) async {
    try {
      await QuoteService.instance.updateQuoteStatus(quote.id, newStatus);
      _loadQuotes();
      if (mounted) context.showSuccessToast('Quote marked as ${newStatus.name}');
    } catch (e) {
      if (mounted) context.showErrorToast('Error: $e');
    }
  }

  void _confirmDelete(Quote quote) async {
    final confirm = await showAdaptiveAlertDialog<bool>(
      context: context,
      title: 'Delete Quote',
      message: 'Are you sure you want to delete "${quote.quoteNumber}"?',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      isDestructive: true,
    );

    if (confirm == true) {
      try {
        await QuoteService.instance.deleteQuote(quote.id);
        if (mounted) {
          _loadQuotes();
          context.showSuccessToast('Quote deleted');
        }
      } catch (e) {
        if (mounted) context.showErrorToast('Error: $e');
      }
    }
  }

  Future<void> _bulkDelete() async {
    final count = selectedCount;
    final confirm = await showAdaptiveAlertDialog<bool>(
      context: context,
      title: 'Delete $count Quote${count == 1 ? '' : 's'}',
      message:
          'Are you sure you want to delete $count selected ${count == 1 ? 'item' : 'items'}? This cannot be undone.',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      isDestructive: true,
    );

    if (confirm == true) {
      try {
        await QuoteService.instance.deleteQuotes(selectedIds.toList());
        if (mounted) {
          exitSelectionMode();
          _loadQuotes();
          context.showSuccessToast(
              '$count quote${count == 1 ? '' : 's'} deleted');
        }
      } catch (e) {
        if (mounted) {
          context.showErrorToast('Error deleting quotes: $e');
        }
      }
    }
  }
}
