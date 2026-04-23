import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'dart:convert';
import '../../models/quote.dart';
import '../../models/company_member.dart';
import '../../services/quote_service.dart';
import '../../services/company_service.dart';
import '../../services/user_profile_service.dart';
import '../../theme/web_theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import '../../utils/download_stub.dart' if (dart.library.html) '../../utils/download_web.dart';
import 'web_quote_detail_panel.dart';
import 'dashboard/quote_helpers.dart';

class WebQuotesScreen extends StatefulWidget {
  final String? initialQuoteId;

  const WebQuotesScreen({super.key, this.initialQuoteId});

  @override
  State<WebQuotesScreen> createState() => _WebQuotesScreenState();
}

class _WebQuotesScreenState extends State<WebQuotesScreen>
    with SingleTickerProviderStateMixin {
  String? _statusFilter;
  String? _engineerFilter;
  String _searchQuery = '';
  String _sortColumnKey = 'quoteNumber';
  bool _sortAscending = false;
  int _rowsPerPage = 25;
  int _currentPage = 0;
  String? _selectedQuoteId;
  String? _selectedEngineerId;
  bool _panelVisible = false;
  bool _panelAnimateIn = true;
  List<CompanyMember> _members = [];
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Stream<List<Quote>>? _quotesStream;
  Timer? _searchDebounce;

  late final AnimationController _overlayController;
  late final Animation<double> _overlayOpacity;

  String? get _companyId => UserProfileService.instance.companyId;

  @override
  void initState() {
    super.initState();
    _overlayController = AnimationController(
      vsync: this,
      duration: FtMotion.slow,
    );
    _overlayOpacity = CurvedAnimation(
      parent: _overlayController,
      curve: FtMotion.standardCurve,
    );
    if (widget.initialQuoteId != null) {
      _selectedQuoteId = widget.initialQuoteId;
      _panelVisible = true;
      _overlayController.value = 1.0;
    }
    _loadMembers();
    _initStream();
  }

  void _initStream() {
    final companyId = _companyId;
    if (companyId != null) {
      _quotesStream = QuoteService.instance.getCompanyQuotesStream(companyId);
    }
  }

  void _selectQuote(String quoteId, String engineerId) {
    final wasAlreadyOpen = _panelVisible;
    setState(() {
      _selectedQuoteId = quoteId;
      _selectedEngineerId = engineerId;
      _panelVisible = true;
      _panelAnimateIn = !wasAlreadyOpen;
    });
    if (!wasAlreadyOpen) _overlayController.forward();
  }

  void _dismissPanel() async {
    await _overlayController.reverse();
    if (mounted) {
      setState(() {
        _panelVisible = false;
        _selectedQuoteId = null;
        _selectedEngineerId = null;
      });
    }
  }

  @override
  void dispose() {
    _overlayController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    final companyId = _companyId;
    if (companyId == null) return;
    final members = await CompanyService.instance.getCompanyMembers(companyId);
    if (mounted) setState(() => _members = members);
  }

  List<Quote> _filterQuotes(List<Quote> quotes) {
    var filtered = quotes;

    if (_statusFilter != null) {
      filtered = filtered.where((q) => q.status.name == _statusFilter).toList();
    }

    if (_engineerFilter != null) {
      filtered = filtered.where((q) => q.engineerId == _engineerFilter).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((q) {
        return q.quoteNumber.toLowerCase().contains(query) ||
            q.customerName.toLowerCase().contains(query) ||
            q.siteName.toLowerCase().contains(query) ||
            q.engineerName.toLowerCase().contains(query) ||
            (q.defectDescription ?? '').toLowerCase().contains(query);
      }).toList();
    }

    return filtered;
  }

  List<Quote> _sortQuotes(List<Quote> quotes) {
    final sorted = List<Quote>.from(quotes);
    sorted.sort((a, b) {
      int cmp;
      switch (_sortColumnKey) {
        case 'quoteNumber':
          cmp = a.quoteNumber.compareTo(b.quoteNumber);
        case 'customer':
          cmp = a.customerName.compareTo(b.customerName);
        case 'site':
          cmp = a.siteName.compareTo(b.siteName);
        case 'engineer':
          cmp = a.engineerName.compareTo(b.engineerName);
        case 'status':
          cmp = a.status.index.compareTo(b.status.index);
        case 'total':
          cmp = a.total.compareTo(b.total);
        case 'validUntil':
          cmp = a.validUntil.compareTo(b.validUntil);
        case 'createdAt':
          cmp = a.createdAt.compareTo(b.createdAt);
        default:
          cmp = 0;
      }
      return _sortAscending ? cmp : -cmp;
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final companyId = _companyId;

    if (companyId == null) {
      return const Center(child: Text('No company found'));
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN): () => context.push('/quotes/create'),
        const SingleActivator(LogicalKeyboardKey.slash): () => _searchFocusNode.requestFocus(),
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_panelVisible) _dismissPanel();
        },
      },
      child: Focus(
        autofocus: true,
        child: StreamBuilder<List<Quote>>(
          stream: _quotesStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: AdaptiveLoadingIndicator());
            }

            final allQuotes = snapshot.data ?? [];
            final filteredQuotes = _sortQuotes(_filterQuotes(allQuotes));
            final totalPages = (filteredQuotes.length / _rowsPerPage).ceil();
            final safePage = _currentPage.clamp(0, totalPages > 0 ? totalPages - 1 : 0);
            final startIndex = safePage * _rowsPerPage;
            final endIndex = (startIndex + _rowsPerPage).clamp(0, filteredQuotes.length);
            final pageQuotes = filteredQuotes.sublist(startIndex, endIndex);

            return Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(filteredQuotes),
                    _buildKpiStrip(allQuotes),
                    _buildFilterBar(),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filteredQuotes.isEmpty
                          ? _buildEmptyState()
                          : _buildQuoteTable(pageQuotes),
                    ),
                    if (filteredQuotes.isNotEmpty)
                      _buildPaginationBar(filteredQuotes.length, safePage, totalPages),
                  ],
                ),
                if (_panelVisible)
                  Positioned.fill(
                    child: FadeTransition(
                      opacity: _overlayOpacity,
                      child: GestureDetector(
                        onTap: _dismissPanel,
                        child: Container(color: FtColors.primary.withValues(alpha: 0.08)),
                      ),
                    ),
                  ),
                if (_panelVisible && _selectedQuoteId != null)
                  Positioned(
                    top: 0,
                    bottom: 0,
                    right: 0,
                    width: MediaQuery.of(context).size.width * 0.42,
                    child: WebQuoteDetailPanel(
                      key: ValueKey(_selectedQuoteId),
                      engineerId: _selectedEngineerId ?? '',
                      quoteId: _selectedQuoteId!,
                      onClose: _dismissPanel,
                      animateIn: _panelAnimateIn,
                      onEdit: (quote) {
                        context.push('/quotes/create', extra: quote);
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(List<Quote> filteredQuotes) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
      child: Row(
        children: [
          Text('Quotes', style: FtText.sectionTitle),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: filteredQuotes.isEmpty
                ? null
                : () {
                    final csv = generateQuotesCsv(filteredQuotes, _columnVisibility);
                    final bytes = utf8.encode(csv);
                    downloadFile(
                      Uint8List.fromList(bytes),
                      'quotes_export_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv',
                      'text/csv',
                    );
                  },
            icon: Icon(AppIcons.download, size: 16),
            label: const Text('Export'),
            style: OutlinedButton.styleFrom(
              foregroundColor: FtColors.fg1,
              side: const BorderSide(color: FtColors.border, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: FtRadii.mdAll),
              textStyle: FtText.button,
            ),
          ),
          const SizedBox(width: 8),
          _buildColumnsButton(),
          const SizedBox(width: 8),
          DecoratedBox(
            decoration: const BoxDecoration(boxShadow: FtShadows.amber, borderRadius: BorderRadius.all(Radius.circular(10))),
            child: ElevatedButton.icon(
              onPressed: () => context.push('/quotes/create'),
              icon: Icon(AppIcons.add, size: 18),
              label: const Text('Create Quote'),
              style: ElevatedButton.styleFrom(
                backgroundColor: FtColors.accent,
                foregroundColor: FtColors.primary,
                shape: RoundedRectangleBorder(borderRadius: FtRadii.mdAll),
                textStyle: FtText.button,
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiStrip(List<Quote> allQuotes) {
    final drafts = allQuotes.where((q) => q.status == QuoteStatus.draft).length;
    final sent = allQuotes.where((q) => q.status == QuoteStatus.sent).length;
    final approved = allQuotes.where((q) => q.status == QuoteStatus.approved).length;
    final declined = allQuotes.where((q) => q.status == QuoteStatus.declined).length;
    final totalValue = allQuotes
        .where((q) => q.status == QuoteStatus.approved || q.status == QuoteStatus.converted)
        .fold<double>(0.0, (acc, q) => acc + q.total);
    final currencyFmt = NumberFormat.currency(symbol: '£', decimalDigits: 0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 0),
      child: Row(
        children: [
          Expanded(child: _kpiCard(
            label: 'DRAFTS',
            value: '$drafts',
            meta: 'awaiting send',
            filterValue: 'draft',
            variant: _KpiVariant.normal,
          )),
          const SizedBox(width: 16),
          Expanded(child: _kpiCard(
            label: 'SENT',
            value: '$sent',
            meta: 'awaiting response',
            filterValue: 'sent',
            variant: _KpiVariant.normal,
          )),
          const SizedBox(width: 16),
          Expanded(child: _kpiCard(
            label: 'APPROVED',
            value: '$approved',
            meta: 'ready to convert',
            filterValue: 'approved',
            variant: _KpiVariant.normal,
          )),
          const SizedBox(width: 16),
          Expanded(child: _kpiCard(
            label: 'DECLINED',
            value: '$declined',
            meta: declined > 0 ? 'not accepted' : 'none',
            filterValue: 'declined',
            variant: _KpiVariant.danger,
          )),
          const SizedBox(width: 16),
          Expanded(child: _kpiCard(
            label: 'APPROVED VALUE',
            value: currencyFmt.format(totalValue),
            meta: 'total approved',
            filterValue: null,
            variant: _KpiVariant.featured,
          )),
        ],
      ),
    );
  }

  Widget _kpiCard({
    required String label,
    required String value,
    required String meta,
    required String? filterValue,
    required _KpiVariant variant,
  }) {
    final isSelected = _statusFilter == filterValue && filterValue != null;
    final isFeatured = variant == _KpiVariant.featured;
    final isDanger = variant == _KpiVariant.danger;
    final hasValue = (int.tryParse(value) ?? 0) > 0;

    return _HoverLiftCard(
      onTap: filterValue != null
          ? () {
              setState(() {
                _statusFilter = isSelected ? null : filterValue;
                _currentPage = 0;
              });
            }
          : () {},
      isSelected: isSelected,
      variant: variant,
      child: Padding(
        padding: FtSpacing.cardBody,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: FtText.label.copyWith(
                  color: isFeatured ? Colors.white70 : null,
                )),
            const SizedBox(height: 8),
            Text(value,
                style: FtText.outfit(
                  size: 28,
                  weight: FontWeight.w800,
                  color: isFeatured
                      ? FtColors.accent
                      : isDanger && hasValue
                          ? FtColors.danger
                          : FtColors.primary,
                  letterSpacing: -0.8,
                )),
            const SizedBox(height: 4),
            Text(meta,
                style: FtText.helper.copyWith(
                  color: isFeatured ? Colors.white54 : null,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 8),
      child: Row(
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: DropdownButtonFormField<String?>(
                isExpanded: true,
                initialValue: _statusFilter,
                decoration: InputDecoration(
                  labelText: 'Status',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: FtRadii.mdAll),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: FtRadii.mdAll,
                    borderSide: const BorderSide(color: FtColors.border, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: FtRadii.mdAll,
                    borderSide: const BorderSide(color: FtColors.primary, width: 1.5),
                  ),
                  isDense: true,
                ),
                style: FtText.inter(size: 13, weight: FontWeight.w500, color: FtColors.fg1),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All')),
                  DropdownMenuItem(value: 'draft', child: Text('Draft')),
                  DropdownMenuItem(value: 'sent', child: Text('Sent')),
                  DropdownMenuItem(value: 'approved', child: Text('Approved')),
                  DropdownMenuItem(value: 'declined', child: Text('Declined')),
                  DropdownMenuItem(value: 'converted', child: Text('Converted')),
                ],
                onChanged: (v) => setState(() {
                  _statusFilter = v;
                  _currentPage = 0;
                }),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: DropdownButtonFormField<String?>(
                isExpanded: true,
                initialValue: _engineerFilter,
                decoration: InputDecoration(
                  labelText: 'Engineer',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: FtRadii.mdAll),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: FtRadii.mdAll,
                    borderSide: const BorderSide(color: FtColors.border, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: FtRadii.mdAll,
                    borderSide: const BorderSide(color: FtColors.primary, width: 1.5),
                  ),
                  isDense: true,
                ),
                style: FtText.inter(size: 13, weight: FontWeight.w500, color: FtColors.fg1),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Engineers')),
                  ..._members.map((m) => DropdownMenuItem(
                    value: m.uid,
                    child: Text(m.displayName, overflow: TextOverflow.ellipsis),
                  )),
                ],
                onChanged: (v) => setState(() {
                  _engineerFilter = v;
                  _currentPage = 0;
                }),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: FtText.inter(size: 13, weight: FontWeight.w500, color: FtColors.fg1),
                decoration: InputDecoration(
                  hintText: 'Search quotes...',
                  hintStyle: FtText.inter(size: 13, color: FtColors.hint),
                  prefixIcon: Icon(AppIcons.search, size: 18, color: FtColors.fg2),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  border: OutlineInputBorder(borderRadius: FtRadii.mdAll),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: FtRadii.mdAll,
                    borderSide: const BorderSide(color: FtColors.border, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: FtRadii.mdAll,
                    borderSide: const BorderSide(color: FtColors.primary, width: 1.5),
                  ),
                  isDense: true,
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, size: 16, color: FtColors.fg2),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
                onChanged: (v) {
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                    if (mounted) {
                      setState(() {
                        _searchQuery = v;
                        _currentPage = 0;
                      });
                    }
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(AppIcons.receipt, size: 48, color: FtColors.hint),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty || _statusFilter != null || _engineerFilter != null
                ? 'No quotes match your filters'
                : 'No quotes yet',
            style: FtText.bodySoft,
          ),
        ],
      ),
    );
  }

  Widget _buildColumnsButton() {
    return PopupMenuButton<String>(
      icon: Icon(AppIcons.setting, size: 18, color: FtColors.fg2),
      tooltip: 'Toggle columns',
      shape: RoundedRectangleBorder(borderRadius: FtRadii.mdAll),
      color: FtColors.bg,
      itemBuilder: (context) => _allColumns.map((col) {
        return PopupMenuItem<String>(
          value: col.key,
          enabled: !col.alwaysVisible,
          child: StatefulBuilder(
            builder: (context, setMenuState) {
              return CheckboxListTile(
                value: _columnVisibility[col.key] ?? false,
                onChanged: col.alwaysVisible
                    ? null
                    : (v) {
                        setState(() => _columnVisibility[col.key] = v ?? false);
                        setMenuState(() {});
                      },
                title: Text(col.label, style: FtText.inter(size: 13, weight: FontWeight.w500, color: FtColors.fg1)),
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                activeColor: FtColors.primary,
              );
            },
          ),
        );
      }).toList(),
    );
  }

  static const _allColumns = [
    _ColumnDef(key: 'quoteNumber', label: 'Quote #', alwaysVisible: true),
    _ColumnDef(key: 'customer', label: 'Customer'),
    _ColumnDef(key: 'site', label: 'Site'),
    _ColumnDef(key: 'engineer', label: 'Engineer'),
    _ColumnDef(key: 'status', label: 'Status'),
    _ColumnDef(key: 'total', label: 'Total'),
    _ColumnDef(key: 'validUntil', label: 'Valid Until'),
    _ColumnDef(key: 'createdAt', label: 'Created'),
  ];

  final Map<String, bool> _columnVisibility = {
    'quoteNumber': true,
    'customer': true,
    'site': true,
    'engineer': true,
    'status': true,
    'total': true,
    'validUntil': true,
    'createdAt': false,
  };

  List<_ColumnDef> get _visibleColumns =>
      _allColumns.where((c) => _columnVisibility[c.key] == true).toList();

  Widget _buildQuoteTable(List<Quote> quotes) {
    final visible = _visibleColumns;
    final sortIndex = visible.indexWhere((c) => c.key == _sortColumnKey);
    final currencyFmt = NumberFormat.currency(symbol: '£', decimalDigits: 2);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
      child: SizedBox(
        width: double.infinity,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: FtColors.border),
          child: DataTable(
            sortColumnIndex: sortIndex >= 0 ? sortIndex : null,
            sortAscending: _sortAscending,
            headingRowColor: const WidgetStatePropertyAll(FtColors.bgAlt),
            headingRowHeight: 48,
            dataRowColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered)) {
                return FtColors.bgAlt;
              }
              return null;
            }),
            dataRowMinHeight: 56,
            dataRowMaxHeight: 56,
            dividerThickness: 1,
            columns: visible.map((col) => DataColumn(
              label: Text(col.label.toUpperCase(), style: FtText.labelStrong),
              onSort: (_, asc) => setState(() {
                _sortColumnKey = col.key;
                _sortAscending = asc;
              }),
            )).toList(),
            rows: quotes.map((quote) {
              return DataRow(
                cells: visible.map((col) => DataCell(
                  _cellContent(col.key, quote, currencyFmt),
                  onTap: () => _selectQuote(quote.id, quote.engineerId),
                )).toList(),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _cellContent(String key, Quote quote, NumberFormat currencyFmt) {
    switch (key) {
      case 'quoteNumber':
        return Text(
          quote.quoteNumber,
          style: FtText.inter(size: 14, weight: FontWeight.w600, color: FtColors.fg1),
        );
      case 'customer':
        return Text(quote.customerName, overflow: TextOverflow.ellipsis, style: FtText.body);
      case 'site':
        return Text(quote.siteName, overflow: TextOverflow.ellipsis, style: FtText.body);
      case 'engineer':
        return Text(quote.engineerName, overflow: TextOverflow.ellipsis, style: FtText.body);
      case 'status':
        return quoteStatusBadge(quote.status);
      case 'total':
        return Text(currencyFmt.format(quote.total), style: FtText.monoSmall);
      case 'validUntil':
        return Text(DateFormat('dd MMM yyyy').format(quote.validUntil), style: FtText.body);
      case 'createdAt':
        return Text(DateFormat('dd MMM yyyy').format(quote.createdAt), style: FtText.body);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPaginationBar(int totalItems, int currentPage, int totalPages) {
    final startItem = totalItems == 0 ? 0 : currentPage * _rowsPerPage + 1;
    final endItem = ((currentPage + 1) * _rowsPerPage).clamp(0, totalItems);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: FtColors.border)),
      ),
      child: Row(
        children: [
          Text('Rows per page:', style: FtText.helper),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: _rowsPerPage,
            underline: const SizedBox.shrink(),
            isDense: true,
            items: const [
              DropdownMenuItem(value: 25, child: Text('25')),
              DropdownMenuItem(value: 50, child: Text('50')),
              DropdownMenuItem(value: 100, child: Text('100')),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  _rowsPerPage = v;
                  _currentPage = 0;
                });
              }
            },
          ),
          const Spacer(),
          Text('Showing $startItem–$endItem of $totalItems', style: FtText.bodySoft),
          const SizedBox(width: 16),
          IconButton(
            icon: Icon(Icons.first_page, size: 20, color: currentPage > 0 ? FtColors.fg1 : FtColors.hint),
            onPressed: currentPage > 0 ? () => setState(() => _currentPage = 0) : null,
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: Icon(Icons.chevron_left, size: 20, color: currentPage > 0 ? FtColors.fg1 : FtColors.hint),
            onPressed: currentPage > 0 ? () => setState(() => _currentPage--) : null,
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '${currentPage + 1} / $totalPages',
              style: FtText.inter(size: 13, weight: FontWeight.w600, color: FtColors.fg1),
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right, size: 20, color: currentPage < totalPages - 1 ? FtColors.fg1 : FtColors.hint),
            onPressed: currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: Icon(Icons.last_page, size: 20, color: currentPage < totalPages - 1 ? FtColors.fg1 : FtColors.hint),
            onPressed: currentPage < totalPages - 1 ? () => setState(() => _currentPage = totalPages - 1) : null,
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

class _ColumnDef {
  final String key;
  final String label;
  final bool alwaysVisible;

  const _ColumnDef({
    required this.key,
    required this.label,
    this.alwaysVisible = false,
  });
}

enum _KpiVariant { normal, featured, danger }

class _HoverLiftCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool isSelected;
  final _KpiVariant variant;

  const _HoverLiftCard({
    required this.child,
    required this.onTap,
    required this.isSelected,
    required this.variant,
  });

  @override
  State<_HoverLiftCard> createState() => _HoverLiftCardState();
}

class _HoverLiftCardState extends State<_HoverLiftCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isFeatured = widget.variant == _KpiVariant.featured;
    final isDanger = widget.variant == _KpiVariant.danger;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: FtMotion.normal,
          curve: FtMotion.standardCurve,
          transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
          decoration: BoxDecoration(
            gradient: isFeatured ? FtColors.primaryGradient : null,
            color: isFeatured
                ? null
                : isDanger
                    ? const Color(0xFFFEF2F2)
                    : FtColors.bg,
            borderRadius: FtRadii.lgAll,
            border: Border.all(
              color: widget.isSelected
                  ? FtColors.accent
                  : isDanger
                      ? FtColors.dangerSoft
                      : isFeatured
                          ? Colors.transparent
                          : FtColors.border,
              width: widget.isSelected ? 2 : 1.5,
            ),
            boxShadow: _hovered ? FtShadows.md : FtShadows.sm,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
