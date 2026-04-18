import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'dart:convert';
import '../../models/invoice.dart';
import '../../models/company_member.dart';
import '../../services/firestore_sync_service.dart';
import '../../services/company_service.dart';
import '../../services/user_profile_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import '../../utils/download_stub.dart' if (dart.library.html) '../../utils/download_web.dart';
import 'web_invoice_detail_panel.dart';
import 'dashboard/invoice_helpers.dart';

class WebInvoicesScreen extends StatefulWidget {
  final String? initialInvoiceId;

  const WebInvoicesScreen({super.key, this.initialInvoiceId});

  @override
  State<WebInvoicesScreen> createState() => _WebInvoicesScreenState();
}

class _WebInvoicesScreenState extends State<WebInvoicesScreen>
    with SingleTickerProviderStateMixin {
  String? _statusFilter;
  String? _engineerFilter;
  String _searchQuery = '';
  String _sortColumnKey = 'invoiceNumber';
  bool _sortAscending = false;
  int _rowsPerPage = 25;
  int _currentPage = 0;
  String? _selectedInvoiceId;
  String? _selectedEngineerId;
  bool _panelVisible = false;
  bool _panelAnimateIn = true;
  List<CompanyMember> _members = [];
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Stream<List<Invoice>>? _invoicesStream;
  Timer? _searchDebounce;

  late final AnimationController _overlayController;
  late final Animation<double> _overlayOpacity;

  String? get _companyId => UserProfileService.instance.companyId;

  @override
  void initState() {
    super.initState();
    _overlayController = AnimationController(
      vsync: this,
      duration: AppTheme.normalAnimation,
    );
    _overlayOpacity = CurvedAnimation(
      parent: _overlayController,
      curve: AppTheme.defaultCurve,
    );
    if (widget.initialInvoiceId != null) {
      _selectedInvoiceId = widget.initialInvoiceId;
      _panelVisible = true;
      _overlayController.value = 1.0;
    }
    _loadMembers();
    _initStream();
  }

  void _initStream() {
    final companyId = _companyId;
    if (companyId != null) {
      _invoicesStream = FirestoreSyncService.instance.getCompanyInvoicesStream(companyId);
    }
  }

  void _selectInvoice(String invoiceId, String engineerId) {
    final wasAlreadyOpen = _panelVisible;
    setState(() {
      _selectedInvoiceId = invoiceId;
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
        _selectedInvoiceId = null;
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

  List<Invoice> _filterInvoices(List<Invoice> invoices) {
    var filtered = invoices;

    if (_statusFilter != null) {
      filtered = filtered.where((inv) => inv.status.name == _statusFilter).toList();
    }

    if (_engineerFilter != null) {
      filtered = filtered.where((inv) => inv.engineerId == _engineerFilter).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((inv) {
        return inv.invoiceNumber.toLowerCase().contains(query) ||
            inv.customerName.toLowerCase().contains(query) ||
            inv.engineerName.toLowerCase().contains(query) ||
            (inv.customerEmail ?? '').toLowerCase().contains(query);
      }).toList();
    }

    return filtered;
  }

  List<Invoice> _sortInvoices(List<Invoice> invoices) {
    final sorted = List<Invoice>.from(invoices);
    sorted.sort((a, b) {
      int cmp;
      switch (_sortColumnKey) {
        case 'invoiceNumber':
          cmp = a.invoiceNumber.compareTo(b.invoiceNumber);
        case 'customer':
          cmp = a.customerName.compareTo(b.customerName);
        case 'engineer':
          cmp = a.engineerName.compareTo(b.engineerName);
        case 'status':
          cmp = a.status.index.compareTo(b.status.index);
        case 'total':
          cmp = a.total.compareTo(b.total);
        case 'date':
          cmp = a.date.compareTo(b.date);
        case 'dueDate':
          cmp = a.dueDate.compareTo(b.dueDate);
        default:
          cmp = 0;
      }
      return _sortAscending ? cmp : -cmp;
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final companyId = _companyId;

    if (companyId == null) {
      return const Center(child: Text('No company found'));
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN): () => context.push('/invoices/create'),
        const SingleActivator(LogicalKeyboardKey.slash): () => _searchFocusNode.requestFocus(),
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_panelVisible) _dismissPanel();
        },
      },
      child: Focus(
        autofocus: true,
        child: StreamBuilder<List<Invoice>>(
          stream: _invoicesStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: AdaptiveLoadingIndicator());
            }

            final allInvoices = snapshot.data ?? [];
            final filteredInvoices = _sortInvoices(_filterInvoices(allInvoices));
            final totalPages = (filteredInvoices.length / _rowsPerPage).ceil();
            final safePage = _currentPage.clamp(0, totalPages > 0 ? totalPages - 1 : 0);
            final startIndex = safePage * _rowsPerPage;
            final endIndex = (startIndex + _rowsPerPage).clamp(0, filteredInvoices.length);
            final pageInvoices = filteredInvoices.sublist(startIndex, endIndex);

            return Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(isDark, filteredInvoices),
                    _buildSummaryCards(allInvoices, isDark),
                    _buildFilterBar(isDark),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filteredInvoices.isEmpty
                          ? _buildEmptyState(isDark)
                          : _buildInvoiceTable(pageInvoices, isDark),
                    ),
                    if (filteredInvoices.isNotEmpty)
                      _buildPaginationBar(isDark, filteredInvoices.length, safePage, totalPages),
                  ],
                ),
                if (_panelVisible)
                  Positioned.fill(
                    child: FadeTransition(
                      opacity: _overlayOpacity,
                      child: GestureDetector(
                        onTap: _dismissPanel,
                        child: Container(color: Colors.black.withValues(alpha: 0.05)),
                      ),
                    ),
                  ),
                if (_panelVisible && _selectedInvoiceId != null)
                  Positioned(
                    top: 0,
                    bottom: 0,
                    right: 0,
                    width: MediaQuery.of(context).size.width * 0.42,
                    child: WebInvoiceDetailPanel(
                      key: ValueKey(_selectedInvoiceId),
                      engineerId: _selectedEngineerId ?? '',
                      invoiceId: _selectedInvoiceId!,
                      onClose: _dismissPanel,
                      animateIn: _panelAnimateIn,
                      onEdit: (invoice) {
                        context.push('/invoices/create', extra: invoice);
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

  Widget _buildHeader(bool isDark, List<Invoice> filteredInvoices) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        children: [
          Text(
            'Invoices',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: filteredInvoices.isEmpty
                ? null
                : () {
                    final csv = generateInvoicesCsv(filteredInvoices, _columnVisibility);
                    final bytes = utf8.encode(csv);
                    downloadFile(
                      Uint8List.fromList(bytes),
                      'invoices_export_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv',
                      'text/csv',
                    );
                  },
            icon: Icon(AppIcons.download, size: 16),
            label: const Text('Export'),
          ),
          const SizedBox(width: 8),
          _buildColumnsButton(isDark),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => context.push('/invoices/create'),
            icon: Icon(AppIcons.add, size: 18),
            label: const Text('Create Invoice'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(List<Invoice> allInvoices, bool isDark) {
    final drafts = allInvoices.where((i) => i.status == InvoiceStatus.draft).length;
    final sent = allInvoices.where((i) => i.status == InvoiceStatus.sent).length;
    final paid = allInvoices.where((i) => i.status == InvoiceStatus.paid).length;
    final outstanding = allInvoices
        .where((i) => i.status == InvoiceStatus.sent)
        .fold<double>(0.0, (acc, i) => acc + i.total);
    final currencyFmt = NumberFormat.currency(symbol: '\u00A3', decimalDigits: 0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          _summaryCard('Drafts', '$drafts', AppTheme.mediumGrey, isDark, 'draft'),
          const SizedBox(width: 12),
          _summaryCard('Sent', '$sent', Colors.blue, isDark, 'sent'),
          const SizedBox(width: 12),
          _summaryCard('Paid', '$paid', AppTheme.successGreen, isDark, 'paid'),
          const SizedBox(width: 12),
          _summaryCard('Outstanding', currencyFmt.format(outstanding), AppTheme.accentOrange, isDark, null),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, String count, Color color, bool isDark, String? filterValue) {
    final isSelected = _statusFilter == filterValue && filterValue != null;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: filterValue != null
            ? () {
                setState(() {
                  _statusFilter = isSelected ? null : filterValue;
                  _currentPage = 0;
                });
              }
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.2)
                : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: isSelected ? Border.all(color: color, width: 1.5) : null,
          ),
          child: Column(
            children: [
              Text(
                count,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 12, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All')),
                  DropdownMenuItem(value: 'draft', child: Text('Draft')),
                  DropdownMenuItem(value: 'sent', child: Text('Sent')),
                  DropdownMenuItem(value: 'paid', child: Text('Paid')),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                ),
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
                decoration: InputDecoration(
                  hintText: 'Search invoices...',
                  prefixIcon: Icon(AppIcons.search, size: 18),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
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

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            AppIcons.wallet,
            size: 48,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty || _statusFilter != null || _engineerFilter != null
                ? 'No invoices match your filters'
                : 'No invoices yet',
            style: TextStyle(
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnsButton(bool isDark) {
    return PopupMenuButton<String>(
      icon: Icon(AppIcons.setting, size: 18),
      tooltip: 'Toggle columns',
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
                title: Text(col.label, style: const TextStyle(fontSize: 14)),
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              );
            },
          ),
        );
      }).toList(),
    );
  }

  static const _allColumns = [
    _ColumnDef(key: 'invoiceNumber', label: 'Invoice #', alwaysVisible: true),
    _ColumnDef(key: 'customer', label: 'Customer'),
    _ColumnDef(key: 'engineer', label: 'Engineer'),
    _ColumnDef(key: 'status', label: 'Status'),
    _ColumnDef(key: 'total', label: 'Total'),
    _ColumnDef(key: 'date', label: 'Date'),
    _ColumnDef(key: 'dueDate', label: 'Due Date'),
  ];

  final Map<String, bool> _columnVisibility = {
    'invoiceNumber': true,
    'customer': true,
    'engineer': true,
    'status': true,
    'total': true,
    'date': true,
    'dueDate': true,
  };

  List<_ColumnDef> get _visibleColumns =>
      _allColumns.where((c) => _columnVisibility[c.key] == true).toList();

  Widget _buildInvoiceTable(List<Invoice> invoices, bool isDark) {
    final visible = _visibleColumns;
    final sortIndex = visible.indexWhere((c) => c.key == _sortColumnKey);
    final currencyFmt = NumberFormat.currency(symbol: '\u00A3', decimalDigits: 2);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: SizedBox(
        width: double.infinity,
        child: DataTable(
          sortColumnIndex: sortIndex >= 0 ? sortIndex : null,
          sortAscending: _sortAscending,
          headingRowColor: WidgetStateProperty.all(
            isDark ? AppTheme.darkSurfaceElevated : Colors.grey.shade50,
          ),
          dataRowColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) {
              return isDark
                  ? AppTheme.darkSurfaceElevated.withValues(alpha: 0.5)
                  : Colors.blue.withValues(alpha: 0.04);
            }
            return null;
          }),
          columns: visible.map((col) => DataColumn(
            label: Text(col.label, style: const TextStyle(fontWeight: FontWeight.w600)),
            onSort: (_, asc) => setState(() {
              _sortColumnKey = col.key;
              _sortAscending = asc;
            }),
          )).toList(),
          rows: invoices.map((invoice) {
            return DataRow(
              cells: visible.map((col) => DataCell(
                _cellContent(col.key, invoice, isDark, currencyFmt),
                onTap: () => _selectInvoice(invoice.id, invoice.engineerId),
              )).toList(),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _cellContent(String key, Invoice invoice, bool isDark, NumberFormat currencyFmt) {
    final now = DateTime.now();
    switch (key) {
      case 'invoiceNumber':
        return Text(
          invoice.invoiceNumber,
          style: const TextStyle(fontWeight: FontWeight.w500),
        );
      case 'customer':
        return Text(invoice.customerName, overflow: TextOverflow.ellipsis);
      case 'engineer':
        return Text(invoice.engineerName, overflow: TextOverflow.ellipsis);
      case 'status':
        return invoiceStatusBadge(invoice.status);
      case 'total':
        return Text(
          currencyFmt.format(invoice.total),
          style: const TextStyle(fontWeight: FontWeight.w500),
        );
      case 'date':
        return Text(DateFormat('dd MMM yyyy').format(invoice.date));
      case 'dueDate':
        final isOverdue = invoice.status == InvoiceStatus.sent &&
            invoice.dueDate.isBefore(DateTime(now.year, now.month, now.day));
        return Text(
          DateFormat('dd MMM yyyy').format(invoice.dueDate),
          style: TextStyle(
            color: isOverdue ? AppTheme.errorRed : null,
            fontWeight: isOverdue ? FontWeight.w600 : null,
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPaginationBar(bool isDark, int totalItems, int currentPage, int totalPages) {
    final startItem = totalItems == 0 ? 0 : currentPage * _rowsPerPage + 1;
    final endItem = ((currentPage + 1) * _rowsPerPage).clamp(0, totalItems);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Text('Rows per page:', style: TextStyle(
            fontSize: 13,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
          )),
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
          Text(
            'Showing $startItem\u2013$endItem of $totalItems',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.first_page, size: 20),
            onPressed: currentPage > 0 ? () => setState(() => _currentPage = 0) : null,
            iconSize: 20, padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            onPressed: currentPage > 0 ? () => setState(() => _currentPage--) : null,
            iconSize: 20, padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('${currentPage + 1} / $totalPages',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            onPressed: currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
            iconSize: 20, padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: const Icon(Icons.last_page, size: 20),
            onPressed: currentPage < totalPages - 1 ? () => setState(() => _currentPage = totalPages - 1) : null,
            iconSize: 20, padding: EdgeInsets.zero,
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
