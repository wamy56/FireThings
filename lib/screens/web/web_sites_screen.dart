import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import 'dart:convert';
import '../../models/company_site.dart';
import '../../models/permission.dart';
import '../../services/company_service.dart';
import '../../services/user_profile_service.dart';
import '../../services/remote_config_service.dart';
import '../../theme/web_theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import '../../utils/download_stub.dart' if (dart.library.html) '../../utils/download_web.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/premium_toast.dart';
import 'web_site_detail_panel.dart';
import 'dashboard/site_helpers.dart';

class WebSitesScreen extends StatefulWidget {
  final String? initialSiteId;

  const WebSitesScreen({super.key, this.initialSiteId});

  @override
  State<WebSitesScreen> createState() => _WebSitesScreenState();
}

class _WebSitesScreenState extends State<WebSitesScreen>
    with SingleTickerProviderStateMixin {
  String? _typeFilter;
  String _searchQuery = '';
  String _sortColumnKey = 'name';
  bool _sortAscending = true;
  int _rowsPerPage = 25;
  int _currentPage = 0;
  String? _selectedSiteId;
  bool _panelVisible = false;
  bool _panelAnimateIn = true;
  String? _kpiFilter;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Stream<List<CompanySite>>? _sitesStream;
  Timer? _searchDebounce;

  late final AnimationController _overlayController;
  late final Animation<double> _overlayOpacity;

  String? get _companyId => UserProfileService.instance.companyId;
  bool get _canCreate => UserProfileService.instance.hasPermission(AppPermission.sitesCreate);
  bool get _bs5839Enabled => RemoteConfigService.instance.bs5839ModeEnabled;

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
    if (widget.initialSiteId != null) {
      _selectedSiteId = widget.initialSiteId;
      _panelVisible = true;
      _overlayController.value = 1.0;
    }
    _initStream();
  }

  void _initStream() {
    final companyId = _companyId;
    if (companyId != null) {
      _sitesStream = CompanyService.instance.getSitesStream(companyId);
    }
  }

  void _selectSite(String siteId) {
    final wasAlreadyOpen = _panelVisible;
    setState(() {
      _selectedSiteId = siteId;
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
        _selectedSiteId = null;
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

  List<CompanySite> _filterSites(List<CompanySite> sites) {
    var filtered = sites;

    if (_typeFilter != null) {
      switch (_typeFilter) {
        case 'bs5839':
          filtered = filtered.where((s) => s.isBs5839Site).toList();
        case 'standard':
          filtered = filtered.where((s) => !s.isBs5839Site).toList();
      }
    }

    if (_kpiFilter != null) {
      switch (_kpiFilter) {
        case 'bs5839':
          filtered = filtered.where((s) => s.isBs5839Site).toList();
        case 'recent':
          final cutoff = DateTime.now().subtract(const Duration(days: 30));
          filtered = filtered.where((s) => s.createdAt.isAfter(cutoff)).toList();
        case 'withNotes':
          filtered = filtered.where((s) => s.notes != null && s.notes!.isNotEmpty).toList();
        case 'needingService':
          final now = DateTime.now();
          filtered = filtered.where((s) => s.nextServiceDueDate != null && s.nextServiceDueDate!.isBefore(now)).toList();
      }
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((s) {
        return s.name.toLowerCase().contains(query) ||
            s.address.toLowerCase().contains(query) ||
            (s.notes?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    return filtered;
  }

  List<CompanySite> _sortSites(List<CompanySite> sites) {
    final sorted = List<CompanySite>.from(sites);
    sorted.sort((a, b) {
      int cmp;
      switch (_sortColumnKey) {
        case 'name':
          cmp = a.name.compareTo(b.name);
        case 'address':
          cmp = a.address.compareTo(b.address);
        case 'notes':
          cmp = (a.notes ?? '').compareTo(b.notes ?? '');
        case 'bs5839':
          cmp = (a.isBs5839Site ? 1 : 0).compareTo(b.isBs5839Site ? 1 : 0);
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
          const SingleActivator(LogicalKeyboardKey.keyN): () => _showSiteDialog(),
        const SingleActivator(LogicalKeyboardKey.slash): () => _searchFocusNode.requestFocus(),
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_panelVisible) _dismissPanel();
        },
      },
      child: Focus(
        autofocus: true,
        child: StreamBuilder<List<CompanySite>>(
          stream: _sitesStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: AdaptiveLoadingIndicator());
            }

            final allSites = snapshot.data ?? [];
            final filteredSites = _sortSites(_filterSites(allSites));
            final totalPages = (filteredSites.length / _rowsPerPage).ceil();
            final safePage = _currentPage.clamp(0, totalPages > 0 ? totalPages - 1 : 0);
            final startIndex = safePage * _rowsPerPage;
            final endIndex = (startIndex + _rowsPerPage).clamp(0, filteredSites.length);
            final pageSites = filteredSites.sublist(startIndex, endIndex);

            return Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(filteredSites),
                    _buildKpiStrip(allSites),
                    _buildFilterBar(),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filteredSites.isEmpty
                          ? _buildEmptyState()
                          : _buildSiteTable(pageSites),
                    ),
                    if (filteredSites.isNotEmpty)
                      _buildPaginationBar(filteredSites.length, safePage, totalPages),
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
                if (_panelVisible && _selectedSiteId != null)
                  Positioned(
                    top: 0,
                    bottom: 0,
                    right: 0,
                    width: MediaQuery.of(context).size.width * 0.42,
                    child: WebSiteDetailPanel(
                      key: ValueKey(_selectedSiteId),
                      siteId: _selectedSiteId!,
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

  Widget _buildHeader(List<CompanySite> filteredSites) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
      child: Row(
        children: [
          Text('Sites', style: FtText.sectionTitle),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: filteredSites.isEmpty
                ? null
                : () {
                    final csv = generateSitesCsv(filteredSites, _columnVisibility);
                    final bytes = utf8.encode(csv);
                    downloadFile(
                      Uint8List.fromList(bytes),
                      'sites_export_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv',
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
                onPressed: () => _showSiteDialog(),
                icon: Icon(AppIcons.add, size: 18),
                label: const Text('Add Site'),
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

  Widget _buildKpiStrip(List<CompanySite> allSites) {
    final total = allSites.length;
    final bs5839Count = allSites.where((s) => s.isBs5839Site).length;
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final recent = allSites.where((s) => s.createdAt.isAfter(cutoff)).length;
    final withNotes = allSites.where((s) => s.notes != null && s.notes!.isNotEmpty).length;
    final now = DateTime.now();
    final needingService = allSites.where((s) => s.nextServiceDueDate != null && s.nextServiceDueDate!.isBefore(now)).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 0),
      child: Row(
        children: [
          Expanded(child: _kpiCard(
            label: 'TOTAL SITES',
            value: '$total',
            meta: 'in company',
            filterValue: null,
            variant: _KpiVariant.featured,
          )),
          if (_bs5839Enabled) ...[
            const SizedBox(width: 16),
            Expanded(child: _kpiCard(
              label: 'BS 5839 SITES',
              value: '$bs5839Count',
              meta: 'compliant systems',
              filterValue: 'bs5839',
              variant: _KpiVariant.normal,
            )),
          ],
          const SizedBox(width: 16),
          Expanded(child: _kpiCard(
            label: 'RECENTLY ADDED',
            value: '$recent',
            meta: 'last 30 days',
            filterValue: 'recent',
            variant: _KpiVariant.normal,
          )),
          const SizedBox(width: 16),
          Expanded(child: _kpiCard(
            label: 'WITH NOTES',
            value: '$withNotes',
            meta: 'documented',
            filterValue: 'withNotes',
            variant: _KpiVariant.normal,
          )),
          if (needingService > 0) ...[
            const SizedBox(width: 16),
            Expanded(child: _kpiCard(
              label: 'NEEDING SERVICE',
              value: '$needingService',
              meta: 'overdue',
              filterValue: 'needingService',
              variant: _KpiVariant.danger,
            )),
          ],
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
          if (_bs5839Enabled) ...[
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: DropdownButtonFormField<String?>(
                  isExpanded: true,
                  initialValue: _typeFilter,
                  decoration: InputDecoration(
                    labelText: 'Type',
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
                    DropdownMenuItem(value: null, child: Text('All Sites')),
                    DropdownMenuItem(value: 'bs5839', child: Text('BS 5839 Sites')),
                    DropdownMenuItem(value: 'standard', child: Text('Standard Sites')),
                  ],
                  onChanged: (v) => setState(() {
                    _typeFilter = v;
                    _currentPage = 0;
                  }),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: FtText.inter(size: 13, weight: FontWeight.w500, color: FtColors.fg1),
                decoration: InputDecoration(
                  hintText: 'Search sites...',
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
    final hasFilters = _searchQuery.isNotEmpty || _typeFilter != null || _kpiFilter != null;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(AppIcons.building, size: 48, color: FtColors.hint),
          const SizedBox(height: 16),
          Text(
            hasFilters ? 'No sites match your filters' : 'No sites yet',
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
                  _typeFilter = null;
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
        if (col.key == 'bs5839' && !_bs5839Enabled) return null;
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
      }).whereType<PopupMenuItem<String>>().toList(),
    );
  }

  static const _allColumns = [
    _ColumnDef(key: 'name', label: 'Name', alwaysVisible: true),
    _ColumnDef(key: 'address', label: 'Address'),
    _ColumnDef(key: 'notes', label: 'Notes'),
    _ColumnDef(key: 'bs5839', label: 'BS 5839'),
    _ColumnDef(key: 'createdAt', label: 'Created'),
  ];

  final Map<String, bool> _columnVisibility = {
    'name': true,
    'address': true,
    'notes': false,
    'bs5839': true,
    'createdAt': false,
  };

  List<_ColumnDef> get _visibleColumns =>
      _allColumns.where((c) {
        if (c.key == 'bs5839' && !_bs5839Enabled) return false;
        return _columnVisibility[c.key] == true;
      }).toList();

  Widget _buildSiteTable(List<CompanySite> sites) {
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
            rows: sites.map((site) {
              return DataRow(
                cells: visible.map((col) => DataCell(
                  _cellContent(col.key, site),
                  onTap: () => _selectSite(site.id),
                )).toList(),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _cellContent(String key, CompanySite site) {
    switch (key) {
      case 'name':
        return Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: FtColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(AppIcons.building, size: 14, color: FtColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                site.name,
                overflow: TextOverflow.ellipsis,
                style: FtText.inter(size: 14, weight: FontWeight.w600, color: FtColors.fg1),
              ),
            ),
          ],
        );
      case 'address':
        return Text(site.address, overflow: TextOverflow.ellipsis, style: FtText.body);
      case 'notes':
        return Text(site.notes ?? '', overflow: TextOverflow.ellipsis, maxLines: 1, style: FtText.bodySoft);
      case 'bs5839':
        return bs5839Badge(site.isBs5839Site);
      case 'createdAt':
        return Text(DateFormat('dd MMM yyyy').format(site.createdAt), style: FtText.body);
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

  Future<void> _showSiteDialog({CompanySite? site}) async {
    final nameController = TextEditingController(text: site?.name ?? '');
    final addressController = TextEditingController(text: site?.address ?? '');
    final notesController = TextEditingController(text: site?.notes ?? '');
    final isEdit = site != null;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Edit Site' : 'Add Site'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  controller: nameController,
                  label: 'Site Name',
                  prefixIcon: Icon(AppIcons.building),
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: addressController,
                  label: 'Address',
                  prefixIcon: Icon(AppIcons.location),
                  maxLines: 2,
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
    final address = addressController.text.trim();
    if (name.isEmpty || address.isEmpty) {
      if (mounted) context.showErrorToast('Name and address are required');
      return;
    }

    final companyId = _companyId;
    if (companyId == null) return;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final now = DateTime.now();
      final notes = notesController.text.trim();

      if (isEdit) {
        final updated = site.copyWith(
          name: name,
          address: address,
          notes: notes.isEmpty ? null : notes,
          updatedAt: now,
        );
        await CompanyService.instance.updateSite(
          companyId, updated,
          previousAddress: site.address,
        );
        if (mounted) context.showSuccessToast('Site updated');
      } else {
        final newSite = CompanySite(
          id: const Uuid().v4(),
          name: name,
          address: address,
          notes: notes.isEmpty ? null : notes,
          createdBy: uid,
          createdAt: now,
        );
        await CompanyService.instance.createSite(companyId, newSite);
        if (mounted) context.showSuccessToast('Site added');
      }
    } catch (e) {
      if (mounted) context.showErrorToast('Failed to save site');
    }
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
