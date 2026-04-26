import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import '../../models/company_member.dart';
import '../../services/company_service.dart';
import '../../services/user_profile_service.dart';
import '../../theme/web_theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import '../../utils/download_stub.dart' if (dart.library.html) '../../utils/download_web.dart';
import 'web_team_detail_panel.dart';
import 'dashboard/team_helpers.dart';

class WebTeamScreen extends StatefulWidget {
  const WebTeamScreen({super.key});

  @override
  State<WebTeamScreen> createState() => _WebTeamScreenState();
}

class _WebTeamScreenState extends State<WebTeamScreen>
    with SingleTickerProviderStateMixin {
  String? _roleFilter;
  String _searchQuery = '';
  String _sortColumnKey = 'name';
  bool _sortAscending = true;
  int _rowsPerPage = 25;
  int _currentPage = 0;
  String? _selectedMemberId;
  bool _panelVisible = false;
  bool _panelAnimateIn = true;
  String? _kpiFilter;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Stream<List<CompanyMember>>? _membersStream;
  Timer? _searchDebounce;

  late final AnimationController _overlayController;
  late final Animation<double> _overlayOpacity;

  String? get _companyId => UserProfileService.instance.companyId;
  String? get _currentUid => UserProfileService.instance.profile?.uid;

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
    _initStream();
  }

  void _initStream() {
    final companyId = _companyId;
    if (companyId != null) {
      _membersStream = CompanyService.instance.getCompanyMembersStream(companyId);
    }
  }

  void _selectMember(String memberId) {
    final wasAlreadyOpen = _panelVisible;
    setState(() {
      _selectedMemberId = memberId;
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
        _selectedMemberId = null;
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

  List<CompanyMember> _filterMembers(List<CompanyMember> members) {
    var filtered = members;

    if (_roleFilter != null) {
      filtered = filtered.where((m) => m.role.name == _roleFilter).toList();
    }

    if (_kpiFilter != null) {
      switch (_kpiFilter) {
        case 'admin':
          filtered = filtered.where((m) => m.role == CompanyRole.admin).toList();
        case 'dispatcher':
          filtered = filtered.where((m) => m.role == CompanyRole.dispatcher).toList();
        case 'engineer':
          filtered = filtered.where((m) => m.role == CompanyRole.engineer).toList();
      }
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((m) {
        return m.displayName.toLowerCase().contains(query) ||
            m.email.toLowerCase().contains(query);
      }).toList();
    }

    return filtered;
  }

  List<CompanyMember> _sortMembers(List<CompanyMember> members) {
    final sorted = List<CompanyMember>.from(members);
    sorted.sort((a, b) {
      int cmp;
      switch (_sortColumnKey) {
        case 'name':
          cmp = a.displayName.compareTo(b.displayName);
        case 'email':
          cmp = a.email.compareTo(b.email);
        case 'role':
          cmp = a.role.index.compareTo(b.role.index);
        case 'joinedAt':
          cmp = a.joinedAt.compareTo(b.joinedAt);
        case 'status':
          cmp = (a.isActive ? 1 : 0).compareTo(b.isActive ? 1 : 0);
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
        const SingleActivator(LogicalKeyboardKey.slash): () => _searchFocusNode.requestFocus(),
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_panelVisible) _dismissPanel();
        },
      },
      child: Focus(
        autofocus: true,
        child: StreamBuilder<List<CompanyMember>>(
          stream: _membersStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: AdaptiveLoadingIndicator());
            }

            final allMembers = snapshot.data ?? [];
            final filteredMembers = _sortMembers(_filterMembers(allMembers));
            final totalPages = (filteredMembers.length / _rowsPerPage).ceil();
            final safePage = _currentPage.clamp(0, totalPages > 0 ? totalPages - 1 : 0);
            final startIndex = safePage * _rowsPerPage;
            final endIndex = (startIndex + _rowsPerPage).clamp(0, filteredMembers.length);
            final pageMembers = filteredMembers.sublist(startIndex, endIndex);

            return Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(filteredMembers),
                    _buildKpiStrip(allMembers),
                    _buildFilterBar(),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filteredMembers.isEmpty
                          ? _buildEmptyState()
                          : _buildMemberTable(pageMembers),
                    ),
                    if (filteredMembers.isNotEmpty)
                      _buildPaginationBar(filteredMembers.length, safePage, totalPages),
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
                if (_panelVisible && _selectedMemberId != null)
                  Positioned(
                    top: 0,
                    bottom: 0,
                    right: 0,
                    width: MediaQuery.of(context).size.width * 0.42,
                    child: WebTeamDetailPanel(
                      key: ValueKey(_selectedMemberId),
                      memberId: _selectedMemberId!,
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

  Widget _buildHeader(List<CompanyMember> filteredMembers) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
      child: Row(
        children: [
          Text('Team', style: FtText.sectionTitle),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: filteredMembers.isEmpty
                ? null
                : () {
                    final csv = generateTeamCsv(filteredMembers, _columnVisibility);
                    final bytes = utf8.encode(csv);
                    downloadFile(
                      Uint8List.fromList(bytes),
                      'team_export_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv',
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
        ],
      ),
    );
  }

  Widget _buildKpiStrip(List<CompanyMember> allMembers) {
    final total = allMembers.length;
    final admins = allMembers.where((m) => m.role == CompanyRole.admin).length;
    final dispatchers = allMembers.where((m) => m.role == CompanyRole.dispatcher).length;
    final engineers = allMembers.where((m) => m.role == CompanyRole.engineer).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 0),
      child: Row(
        children: [
          Expanded(child: _kpiCard(
            label: 'TOTAL MEMBERS',
            value: '$total',
            meta: 'in company',
            filterValue: null,
            variant: _KpiVariant.featured,
          )),
          const SizedBox(width: 16),
          Expanded(child: _kpiCard(
            label: 'ADMINS',
            value: '$admins',
            meta: 'full access',
            filterValue: 'admin',
            variant: _KpiVariant.normal,
          )),
          const SizedBox(width: 16),
          Expanded(child: _kpiCard(
            label: 'DISPATCHERS',
            value: '$dispatchers',
            meta: 'job management',
            filterValue: 'dispatcher',
            variant: _KpiVariant.normal,
          )),
          const SizedBox(width: 16),
          Expanded(child: _kpiCard(
            label: 'ENGINEERS',
            value: '$engineers',
            meta: 'field workers',
            filterValue: 'engineer',
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
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: DropdownButtonFormField<String?>(
                isExpanded: true,
                initialValue: _roleFilter,
                decoration: InputDecoration(
                  labelText: 'Role',
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
                  DropdownMenuItem(value: null, child: Text('All Roles')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  DropdownMenuItem(value: 'dispatcher', child: Text('Dispatcher')),
                  DropdownMenuItem(value: 'engineer', child: Text('Engineer')),
                ],
                onChanged: (v) => setState(() {
                  _roleFilter = v;
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
                  hintText: 'Search members...',
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
    final hasFilters = _searchQuery.isNotEmpty || _roleFilter != null || _kpiFilter != null;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(AppIcons.people, size: 48, color: FtColors.hint),
          const SizedBox(height: 16),
          Text(
            hasFilters ? 'No members match your filters' : 'No team members',
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
                  _roleFilter = null;
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
    _ColumnDef(key: 'email', label: 'Email'),
    _ColumnDef(key: 'role', label: 'Role'),
    _ColumnDef(key: 'joinedAt', label: 'Joined'),
    _ColumnDef(key: 'status', label: 'Status'),
  ];

  final Map<String, bool> _columnVisibility = {
    'name': true,
    'email': true,
    'role': true,
    'joinedAt': true,
    'status': true,
  };

  List<_ColumnDef> get _visibleColumns =>
      _allColumns.where((c) => _columnVisibility[c.key] == true).toList();

  Widget _buildMemberTable(List<CompanyMember> members) {
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
            rows: members.map((member) {
              return DataRow(
                cells: visible.map((col) => DataCell(
                  _cellContent(col.key, member),
                  onTap: () => _selectMember(member.uid),
                )).toList(),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _cellContent(String key, CompanyMember member) {
    final isCurrentUser = member.uid == _currentUid;

    switch (key) {
      case 'name':
        return Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: roleSoftColor(member.role),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                member.displayName.isNotEmpty ? member.displayName[0].toUpperCase() : '?',
                style: FtText.inter(size: 12, weight: FontWeight.w700, color: roleColor(member.role)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      member.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: FtText.inter(size: 14, weight: FontWeight.w600, color: FtColors.fg1),
                    ),
                  ),
                  if (isCurrentUser)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: FtColors.accentSoft,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('You', style: FtText.inter(size: 10, weight: FontWeight.w600, color: FtColors.accentHover)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      case 'email':
        return Text(member.email, overflow: TextOverflow.ellipsis, style: FtText.body);
      case 'role':
        return roleBadge(member.role);
      case 'joinedAt':
        return Text(DateFormat('dd MMM yyyy').format(member.joinedAt), style: FtText.body);
      case 'status':
        return activeBadge(member.isActive);
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
