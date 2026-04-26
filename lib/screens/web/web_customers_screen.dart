import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import 'dart:convert';
import '../../models/company_customer.dart';
import '../../models/permission.dart';
import '../../services/company_service.dart';
import '../../services/user_profile_service.dart';
import '../../theme/web_theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import '../../utils/download_stub.dart' if (dart.library.html) '../../utils/download_web.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/premium_toast.dart';
import 'web_customer_detail_panel.dart';
import 'dashboard/customer_helpers.dart';

class WebCustomersScreen extends StatefulWidget {
  final String? initialCustomerId;

  const WebCustomersScreen({super.key, this.initialCustomerId});

  @override
  State<WebCustomersScreen> createState() => _WebCustomersScreenState();
}

class _WebCustomersScreenState extends State<WebCustomersScreen>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  String _sortColumnKey = 'name';
  bool _sortAscending = true;
  int _rowsPerPage = 25;
  int _currentPage = 0;
  String? _selectedCustomerId;
  bool _panelVisible = false;
  bool _panelAnimateIn = true;
  String? _kpiFilter;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Stream<List<CompanyCustomer>>? _customersStream;
  Timer? _searchDebounce;

  late final AnimationController _overlayController;
  late final Animation<double> _overlayOpacity;

  String? get _companyId => UserProfileService.instance.companyId;
  bool get _canCreate => UserProfileService.instance.hasPermission(AppPermission.customersCreate);

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
    if (widget.initialCustomerId != null) {
      _selectedCustomerId = widget.initialCustomerId;
      _panelVisible = true;
      _overlayController.value = 1.0;
    }
    _initStream();
  }

  void _initStream() {
    final companyId = _companyId;
    if (companyId != null) {
      _customersStream = CompanyService.instance.getCustomersStream(companyId);
    }
  }

  void _selectCustomer(String customerId) {
    final wasAlreadyOpen = _panelVisible;
    setState(() {
      _selectedCustomerId = customerId;
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
        _selectedCustomerId = null;
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

  List<CompanyCustomer> _filterCustomers(List<CompanyCustomer> customers) {
    var filtered = customers;

    if (_kpiFilter != null) {
      switch (_kpiFilter) {
        case 'withEmail':
          filtered = filtered.where((c) => c.email != null && c.email!.isNotEmpty).toList();
        case 'withPhone':
          filtered = filtered.where((c) => c.phone != null && c.phone!.isNotEmpty).toList();
        case 'recent':
          final cutoff = DateTime.now().subtract(const Duration(days: 30));
          filtered = filtered.where((c) => c.createdAt.isAfter(cutoff)).toList();
      }
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((c) {
        return c.name.toLowerCase().contains(query) ||
            (c.address?.toLowerCase().contains(query) ?? false) ||
            (c.email?.toLowerCase().contains(query) ?? false) ||
            (c.phone?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    return filtered;
  }

  List<CompanyCustomer> _sortCustomers(List<CompanyCustomer> customers) {
    final sorted = List<CompanyCustomer>.from(customers);
    sorted.sort((a, b) {
      int cmp;
      switch (_sortColumnKey) {
        case 'name':
          cmp = a.name.compareTo(b.name);
        case 'address':
          cmp = (a.address ?? '').compareTo(b.address ?? '');
        case 'email':
          cmp = (a.email ?? '').compareTo(b.email ?? '');
        case 'phone':
          cmp = (a.phone ?? '').compareTo(b.phone ?? '');
        case 'notes':
          cmp = (a.notes ?? '').compareTo(b.notes ?? '');
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
        if (_canCreate)
          const SingleActivator(LogicalKeyboardKey.keyN): () => _showCustomerDialog(),
        const SingleActivator(LogicalKeyboardKey.slash): () => _searchFocusNode.requestFocus(),
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_panelVisible) _dismissPanel();
        },
      },
      child: Focus(
        autofocus: true,
        child: StreamBuilder<List<CompanyCustomer>>(
          stream: _customersStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: AdaptiveLoadingIndicator());
            }

            final allCustomers = snapshot.data ?? [];
            final filteredCustomers = _sortCustomers(_filterCustomers(allCustomers));
            final totalPages = (filteredCustomers.length / _rowsPerPage).ceil();
            final safePage = _currentPage.clamp(0, totalPages > 0 ? totalPages - 1 : 0);
            final startIndex = safePage * _rowsPerPage;
            final endIndex = (startIndex + _rowsPerPage).clamp(0, filteredCustomers.length);
            final pageCustomers = filteredCustomers.sublist(startIndex, endIndex);

            return Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(filteredCustomers),
                    _buildKpiStrip(allCustomers),
                    _buildFilterBar(),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filteredCustomers.isEmpty
                          ? _buildEmptyState()
                          : _buildCustomerTable(pageCustomers),
                    ),
                    if (filteredCustomers.isNotEmpty)
                      _buildPaginationBar(filteredCustomers.length, safePage, totalPages),
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
                if (_panelVisible && _selectedCustomerId != null)
                  Positioned(
                    top: 0,
                    bottom: 0,
                    right: 0,
                    width: MediaQuery.of(context).size.width * 0.42,
                    child: WebCustomerDetailPanel(
                      key: ValueKey(_selectedCustomerId),
                      customerId: _selectedCustomerId!,
                      onClose: _dismissPanel,
                      animateIn: _panelAnimateIn,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(List<CompanyCustomer> filteredCustomers) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
      child: Row(
        children: [
          Text('Customers', style: FtText.sectionTitle),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: filteredCustomers.isEmpty
                ? null
                : () {
                    final csv = generateCustomersCsv(filteredCustomers, _columnVisibility);
                    final bytes = utf8.encode(csv);
                    downloadFile(
                      Uint8List.fromList(bytes),
                      'customers_export_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv',
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
          if (_canCreate) ...[
            const SizedBox(width: 8),
            DecoratedBox(
              decoration: const BoxDecoration(boxShadow: FtShadows.amber, borderRadius: BorderRadius.all(Radius.circular(10))),
              child: ElevatedButton.icon(
                onPressed: () => _showCustomerDialog(),
                icon: Icon(AppIcons.add, size: 18),
                label: const Text('Add Customer'),
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
        ],
      ),
    );
  }

  Widget _buildKpiStrip(List<CompanyCustomer> allCustomers) {
    final total = allCustomers.length;
    final withEmail = allCustomers.where((c) => c.email != null && c.email!.isNotEmpty).length;
    final withPhone = allCustomers.where((c) => c.phone != null && c.phone!.isNotEmpty).length;
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final recent = allCustomers.where((c) => c.createdAt.isAfter(cutoff)).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 0),
      child: Row(
        children: [
          Expanded(child: _kpiCard(
            label: 'TOTAL CUSTOMERS',
            value: '$total',
            meta: 'in company',
            filterValue: null,
            variant: _KpiVariant.featured,
          )),
          const SizedBox(width: 16),
          Expanded(child: _kpiCard(
            label: 'WITH EMAIL',
            value: '$withEmail',
            meta: 'contactable',
            filterValue: 'withEmail',
            variant: _KpiVariant.normal,
          )),
          const SizedBox(width: 16),
          Expanded(child: _kpiCard(
            label: 'WITH PHONE',
            value: '$withPhone',
            meta: 'callable',
            filterValue: 'withPhone',
            variant: _KpiVariant.normal,
          )),
          const SizedBox(width: 16),
          Expanded(child: _kpiCard(
            label: 'RECENTLY ADDED',
            value: '$recent',
            meta: 'last 30 days',
            filterValue: 'recent',
            variant: _KpiVariant.normal,
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
    final isSelected = _kpiFilter == filterValue && filterValue != null;
    final isFeatured = variant == _KpiVariant.featured;
    final isDanger = variant == _KpiVariant.danger;
    final hasValue = (int.tryParse(value) ?? 0) > 0;

    return _HoverLiftCard(
      onTap: filterValue != null
          ? () {
              setState(() {
                _kpiFilter = isSelected ? null : filterValue;
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
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: FtText.inter(size: 13, weight: FontWeight.w500, color: FtColors.fg1),
                decoration: InputDecoration(
                  hintText: 'Search customers...',
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
                            setState(() {
                              _searchQuery = '';
                              _currentPage = 0;
                            });
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
    final hasFilters = _searchQuery.isNotEmpty || _kpiFilter != null;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(AppIcons.people, size: 48, color: FtColors.hint),
          const SizedBox(height: 16),
          Text(
            hasFilters ? 'No customers match your filters' : 'No customers yet',
            style: FtText.bodySoft,
          ),
          if (hasFilters) ...[
            const SizedBox(height: 8),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                  _kpiFilter = null;
                  _currentPage = 0;
                }),
                child: Text('Clear filters', style: FtText.inter(size: 13, weight: FontWeight.w600, color: FtColors.accent)),
              ),
            ),
          ],
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
    _ColumnDef(key: 'name', label: 'Name', alwaysVisible: true),
    _ColumnDef(key: 'address', label: 'Address'),
    _ColumnDef(key: 'email', label: 'Email'),
    _ColumnDef(key: 'phone', label: 'Phone'),
    _ColumnDef(key: 'notes', label: 'Notes'),
    _ColumnDef(key: 'createdAt', label: 'Created'),
  ];

  final Map<String, bool> _columnVisibility = {
    'name': true,
    'address': true,
    'email': true,
    'phone': true,
    'notes': false,
    'createdAt': false,
  };

  List<_ColumnDef> get _visibleColumns =>
      _allColumns.where((c) => _columnVisibility[c.key] == true).toList();

  Widget _buildCustomerTable(List<CompanyCustomer> customers) {
    final visible = _visibleColumns;
    final sortIndex = visible.indexWhere((c) => c.key == _sortColumnKey);

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
            rows: customers.map((customer) {
              return DataRow(
                cells: visible.map((col) => DataCell(
                  _cellContent(col.key, customer),
                  onTap: () => _selectCustomer(customer.id),
                )).toList(),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _cellContent(String key, CompanyCustomer customer) {
    switch (key) {
      case 'name':
        return Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: _avatarColor(customer.name),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                _initials(customer.name),
                style: FtText.inter(size: 11, weight: FontWeight.w700, color: Colors.white),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                customer.name,
                overflow: TextOverflow.ellipsis,
                style: FtText.inter(size: 14, weight: FontWeight.w600, color: FtColors.fg1),
              ),
            ),
          ],
        );
      case 'address':
        return Text(customer.address ?? '', overflow: TextOverflow.ellipsis, style: FtText.body);
      case 'email':
        return Text(customer.email ?? '', overflow: TextOverflow.ellipsis, style: FtText.body);
      case 'phone':
        return Text(customer.phone ?? '', overflow: TextOverflow.ellipsis, style: FtText.body);
      case 'notes':
        return Text(customer.notes ?? '', overflow: TextOverflow.ellipsis, maxLines: 1, style: FtText.bodySoft);
      case 'createdAt':
        return Text(DateFormat('dd MMM yyyy').format(customer.createdAt), style: FtText.body);
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

  Future<void> _showCustomerDialog({CompanyCustomer? customer}) async {
    final nameController = TextEditingController(text: customer?.name ?? '');
    final addressController = TextEditingController(text: customer?.address ?? '');
    final emailController = TextEditingController(text: customer?.email ?? '');
    final phoneController = TextEditingController(text: customer?.phone ?? '');
    final notesController = TextEditingController(text: customer?.notes ?? '');
    final isEdit = customer != null;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Edit Customer' : 'Add Customer'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  controller: nameController,
                  label: 'Customer Name',
                  prefixIcon: Icon(AppIcons.user),
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: addressController,
                  label: 'Address (optional)',
                  prefixIcon: Icon(AppIcons.location),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: emailController,
                  label: 'Email (optional)',
                  prefixIcon: Icon(AppIcons.sms),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: phoneController,
                  label: 'Phone (optional)',
                  prefixIcon: Icon(AppIcons.call),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: notesController,
                  label: 'Notes (optional)',
                  prefixIcon: Icon(AppIcons.note),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: FtColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(isEdit ? 'Save' : 'Add'),
          ),
        ],
      ),
    );

    if (result != true) return;

    final name = nameController.text.trim();
    if (name.isEmpty) {
      if (mounted) context.showErrorToast('Customer name is required');
      return;
    }

    final companyId = _companyId;
    if (companyId == null) return;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final now = DateTime.now();
      final address = addressController.text.trim();
      final email = emailController.text.trim();
      final phone = phoneController.text.trim();
      final notes = notesController.text.trim();

      if (isEdit) {
        final updated = customer.copyWith(
          name: name,
          address: address.isEmpty ? null : address,
          email: email.isEmpty ? null : email,
          phone: phone.isEmpty ? null : phone,
          notes: notes.isEmpty ? null : notes,
          updatedAt: now,
        );
        await CompanyService.instance.updateCustomer(companyId, updated);
        if (mounted) context.showSuccessToast('Customer updated');
      } else {
        final newCustomer = CompanyCustomer(
          id: const Uuid().v4(),
          name: name,
          address: address.isEmpty ? null : address,
          email: email.isEmpty ? null : email,
          phone: phone.isEmpty ? null : phone,
          notes: notes.isEmpty ? null : notes,
          createdBy: uid,
          createdAt: now,
        );
        await CompanyService.instance.createCustomer(companyId, newCustomer);
        if (mounted) context.showSuccessToast('Customer added');
      }
    } catch (e) {
      if (mounted) context.showErrorToast('Failed to save customer');
    }
  }

  static Color _avatarColor(String name) {
    const colors = [
      Color(0xFF6366F1),
      Color(0xFF8B5CF6),
      Color(0xFF06B6D4),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
      Color(0xFFEC4899),
      Color(0xFF3B82F6),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return '?';
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
