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
import '../../theme/web_theme.dart';
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
      duration: FtMotion.slow,
    );
    _overlayOpacity = CurvedAnimation(
      parent: _overlayController,
      curve: FtMotion.standardCurve,
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
                    _buildHeader(filteredInvoices),
                    _buildKpiStrip(allInvoices),
                    _buildFilterBar(),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filteredInvoices.isEmpty
                          ? _buildEmptyState()
                          : _buildInvoiceTable(pageInvoices),
                    ),
                    if (filteredInvoices.isNotEmpty)
                      _buildPaginationBar(filteredInvoices.length, safePage, totalPages),
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

  Widget _buildHeader(List<Invoice> filteredInvoices) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
      child: Row(
        children: [
          Text('Invoices', style: FtText.sectionTitle),
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
            decoration: const BoxDecoration(boxShadow: FtShadows.amber),
            child: ElevatedButton.icon(
              onPressed: () => context.push('/invoices/create'),
              icon: Icon(AppIcons.add, size: 18),
              label: const Text('Create Invoice'),
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

  Widget _buildKpiStrip(List<Invoice> allInvoices) {
    final drafts = allInvoices.where((i) => i.status == InvoiceStatus.draft).length;
    final sent = allInvoices.where((i) => i.status == InvoiceStatus.sent).length;
    final paid = allInvoices.where((i) => i.status == InvoiceStatus.paid).length;
    final outstanding = allInvoices
        .where((i) => i.status == InvoiceStatus.sent)
        .fold<double>(0.0, (acc, i) => acc + i.total);
    final currencyFmt = NumberFormat.currency(symbol: '£', decimalDigits: 0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 0),
      child: Row(
        children: [
          Expanded(child: _kpiCard(
            label: 'DRAFTS',
            value: '$drafts',
            meta: 'not yet sent',
            filterValue: 'draft',
            variant: _KpiVariant.normal,
          )),
          const SizedBox(width: 16),
          Expanded(child: _kpiCard(
            label: 'SENT',
            value: '$sent',
            meta: 'awaiting payment',
            filterValue: 'sent',
            variant: _KpiVariant.normal,
          )),
          const SizedBox(width: 16),
          Expanded(child: _kpiCard(
            label: 'PAID',
            value: '$paid',
            meta: 'completed',
            filterValue: 'paid',
            variant: _KpiVariant.normal,
          )),
          const SizedBox(width: 16),
          Expanded(child: _kpiCard(
            label: 'OUTSTANDING',
            value: currencyFmt.format(outstanding),
            meta: 'total unpaid',
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
                  hintText: 'Search invoices...',
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
          Icon(AppIcons.wallet, size: 48, color: FtColors.hint),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty || _statusFilter != null || _engineerFilter != null
                ? 'No invoices match your filters'
                : 'No invoices yet',
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

  Widget _buildInvoiceTable(List<Invoice> invoices) {
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
            rows: invoices.map((invoice) {
              return DataRow(
                cells: visible.map((col) => DataCell(
                  _cellContent(col.key, invoice, currencyFmt),
                  onTap: () => _selectInvoice(invoice.id, invoice.engineerId),
                )).toList(),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _cellContent(String key, Invoice invoice, NumberFormat currencyFmt) {
    final now = DateTime.now();
    switch (key) {
      case 'invoiceNumber':
        return Text(
          invoice.invoiceNumber,
          style: FtText.inter(size: 14, weight: FontWeight.w600, color: FtColors.fg1),
        );
      case 'customer':
        return Text(invoice.customerName, overflow: TextOverflow.ellipsis, style: FtText.body);
      case 'engineer':
        return Text(invoice.engineerName, overflow: TextOverflow.ellipsis, style: FtText.body);
      case 'status':
        return invoiceStatusBadge(invoice.status);
      case 'total':
        return Text(currencyFmt.format(invoice.total), style: FtText.monoSmall);
      case 'date':
        return Text(DateFormat('dd MMM yyyy').format(invoice.date), style: FtText.body);
      case 'dueDate':
        final isOverdue = invoice.status == InvoiceStatus.sent &&
            invoice.dueDate.isBefore(DateTime(now.year, now.month, now.day));
        return Text(
          DateFormat('dd MMM yyyy').format(invoice.dueDate),
          style: isOverdue
              ? FtText.inter(size: 14, weight: FontWeight.w600, color: FtColors.danger)
              : FtText.body,
        );
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
