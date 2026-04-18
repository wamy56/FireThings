import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../utils/icon_map.dart';
import '../../utils/theme.dart';
import '../../services/quote_service.dart';
import '../../widgets/adaptive_app_bar.dart';
import '../../utils/adaptive_widgets.dart';
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

class _QuoteListScreenState extends State<QuoteListScreen> {
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
    return Scaffold(
      appBar: AdaptiveNavigationBar(title: widget.title),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: _isLoading
                ? const Center(child: AdaptiveLoadingIndicator())
                : _quotes.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadQuotes,
                        child: ListView.builder(
                          padding: EdgeInsets.all(AppTheme.screenPadding),
                          itemCount: _quotes.length,
                          itemBuilder: (ctx, i) => _buildQuoteCard(_quotes[i]),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const QuoteScreen()),
          );
          _loadQuotes();
        },
        backgroundColor: AppTheme.accentOrange,
        child: const Icon(Icons.add, color: Colors.white),
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
    final isSelected = _selectedFilter == status;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) {
          setState(() => _selectedFilter = status);
          _loadQuotes();
        },
        selectedColor: AppTheme.primaryBlue.withValues(alpha: 0.2),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(AppIcons.document, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            _selectedFilter != null
                ? 'No ${_selectedFilter!.name} quotes'
                : 'No quotes yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first quote to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade500,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteCard(Quote quote) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFormat =
        NumberFormat.currency(symbol: '\u00A3', decimalDigits: 2);
    final dateFormat = DateFormat('dd/MM/yyyy');
    final isOverdue = quote.status == QuoteStatus.sent &&
        quote.validUntil.isBefore(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isDark ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        side: isOverdue
            ? const BorderSide(color: AppTheme.errorRed, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => QuoteScreen(existingQuote: quote),
            ),
          );
          _loadQuotes();
        },
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Padding(
          padding: EdgeInsets.all(AppTheme.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    quote.quoteNumber,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  _buildStatusBadge(quote.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                quote.customerName,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (quote.siteName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  quote.siteName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textSecondary,
                      ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    currencyFormat.format(quote.total),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Created: ${dateFormat.format(quote.createdAt)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (isOverdue)
                        Text(
                          'OVERDUE',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.errorRed,
                                    fontWeight: FontWeight.bold,
                                  ),
                        )
                      else
                        Text(
                          'Valid until: ${dateFormat.format(quote.validUntil)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(QuoteStatus status) {
    Color color;
    switch (status) {
      case QuoteStatus.draft:
        color = Colors.grey;
        break;
      case QuoteStatus.sent:
        color = Colors.blue;
        break;
      case QuoteStatus.approved:
        color = AppTheme.successGreen;
        break;
      case QuoteStatus.declined:
        color = AppTheme.errorRed;
        break;
      case QuoteStatus.converted:
        color = Colors.purple;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
