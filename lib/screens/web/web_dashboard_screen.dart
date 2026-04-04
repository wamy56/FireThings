import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../models/dispatched_job.dart';
import '../../models/company_member.dart';
import '../../services/dispatch_service.dart';
import '../../services/company_service.dart';
import '../../services/user_profile_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import 'web_job_detail_panel.dart';
import '../../services/web_notification_service.dart';
import '../../services/analytics_service.dart';
import 'dashboard/job_helpers.dart';
import 'dashboard/date_range_filter.dart';
import 'dashboard/bulk_actions_toolbar.dart';
import 'dashboard/csv_export.dart';
import 'dart:convert';
import '../../utils/download_stub.dart' if (dart.library.html) '../../utils/download_web.dart';

class WebDashboardScreen extends StatefulWidget {
  final String? initialJobId;

  const WebDashboardScreen({super.key, this.initialJobId});

  @override
  State<WebDashboardScreen> createState() => _WebDashboardScreenState();
}

class _WebDashboardScreenState extends State<WebDashboardScreen>
    with SingleTickerProviderStateMixin {
  String? _statusFilter;
  String? _engineerFilter;
  String _searchQuery = '';
  String _sortColumnKey = 'title';
  bool _sortAscending = true;
  int _rowsPerPage = 25;
  int _currentPage = 0;
  DateRangePreset? _datePreset;
  DateTimeRange? _customRange;
  String? _selectedJobId;
  bool _panelVisible = false;
  bool _panelAnimateIn = true;
  List<CompanyMember> _members = [];
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final Set<String> _selectedJobIds = {};
  bool _notificationBannerDismissed = false;

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
    if (widget.initialJobId != null) {
      _selectedJobId = widget.initialJobId;
      _panelVisible = true;
      _overlayController.value = 1.0;
    }
    _loadMembers();
    AnalyticsService.instance.logWebDashboardViewed();
  }

  void _selectJob(String jobId) {
    final wasAlreadyOpen = _panelVisible;
    setState(() {
      _selectedJobId = jobId;
      _panelVisible = true;
      _panelAnimateIn = !wasAlreadyOpen;
    });
    if (!wasAlreadyOpen) _overlayController.forward();
    AnalyticsService.instance.logWebJobDetailViewed();
  }

  void _dismissPanel() async {
    await _overlayController.reverse();
    if (mounted) {
      setState(() {
        _panelVisible = false;
        _selectedJobId = null;
      });
    }
  }

  @override
  void dispose() {
    _overlayController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    final companyId = _companyId;
    if (companyId == null) return;
    final members = await CompanyService.instance.getCompanyMembers(companyId);
    if (mounted) setState(() => _members = members);
  }

  List<DispatchedJob> _filterJobs(List<DispatchedJob> jobs) {
    var filtered = jobs;

    if (_statusFilter != null) {
      if (_statusFilter == 'active') {
        filtered = filtered.where((j) =>
            j.status == DispatchedJobStatus.accepted ||
            j.status == DispatchedJobStatus.enRoute ||
            j.status == DispatchedJobStatus.onSite).toList();
      } else if (_statusFilter == 'urgent') {
        filtered = filtered.where((j) =>
            j.priority != JobPriority.normal &&
            j.status != DispatchedJobStatus.completed).toList();
      } else {
        filtered = filtered.where((j) => jobStatusToString(j.status) == _statusFilter).toList();
      }
    }

    if (_engineerFilter != null) {
      if (_engineerFilter == 'unassigned') {
        filtered = filtered.where((j) => j.assignedTo == null).toList();
      } else {
        filtered = filtered.where((j) => j.assignedTo == _engineerFilter).toList();
      }
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((j) {
        return j.title.toLowerCase().contains(q) ||
            j.siteName.toLowerCase().contains(q) ||
            j.siteAddress.toLowerCase().contains(q) ||
            (j.jobNumber ?? '').toLowerCase().contains(q) ||
            (j.contactName ?? '').toLowerCase().contains(q) ||
            (j.assignedToName ?? '').toLowerCase().contains(q);
      }).toList();
    }

    if (_datePreset != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      filtered = filtered.where((j) {
        if (j.scheduledDate == null) {
          return _datePreset == DateRangePreset.overdue;
        }
        final d = DateTime(j.scheduledDate!.year, j.scheduledDate!.month, j.scheduledDate!.day);
        switch (_datePreset!) {
          case DateRangePreset.today:
            return d == today;
          case DateRangePreset.thisWeek:
            final weekStart = today.subtract(Duration(days: today.weekday - 1));
            final weekEnd = weekStart.add(const Duration(days: 7));
            return !d.isBefore(weekStart) && d.isBefore(weekEnd);
          case DateRangePreset.thisMonth:
            return d.year == today.year && d.month == today.month;
          case DateRangePreset.overdue:
            return d.isBefore(today) && j.status != DispatchedJobStatus.completed;
          case DateRangePreset.custom:
            if (_customRange == null) return true;
            final start = DateTime(_customRange!.start.year, _customRange!.start.month, _customRange!.start.day);
            final end = DateTime(_customRange!.end.year, _customRange!.end.month, _customRange!.end.day).add(const Duration(days: 1));
            return !d.isBefore(start) && d.isBefore(end);
        }
      }).toList();
    }

    return filtered;
  }

  List<DispatchedJob> _sortJobs(List<DispatchedJob> jobs) {
    final sorted = List<DispatchedJob>.from(jobs);
    sorted.sort((a, b) {
      int cmp;
      switch (_sortColumnKey) {
        case 'title':
          cmp = a.title.compareTo(b.title);
        case 'site':
          cmp = a.siteName.compareTo(b.siteName);
        case 'engineer':
          cmp = (a.assignedToName ?? '').compareTo(b.assignedToName ?? '');
        case 'date':
          cmp = (a.scheduledDate ?? DateTime(2099)).compareTo(b.scheduledDate ?? DateTime(2099));
        case 'priority':
          cmp = a.priority.index.compareTo(b.priority.index);
        case 'status':
          cmp = a.status.index.compareTo(b.status.index);
        case 'jobNumber':
          cmp = (a.jobNumber ?? '').compareTo(b.jobNumber ?? '');
        case 'jobType':
          cmp = (a.jobType ?? '').compareTo(b.jobType ?? '');
        case 'contactName':
          cmp = (a.contactName ?? '').compareTo(b.contactName ?? '');
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
        const SingleActivator(LogicalKeyboardKey.keyN): () => context.push('/jobs/create'),
        const SingleActivator(LogicalKeyboardKey.slash): () => _searchFocusNode.requestFocus(),
        const SingleActivator(LogicalKeyboardKey.escape): () { if (_panelVisible) _dismissPanel(); },
      },
      child: Focus(
        autofocus: true,
        child: StreamBuilder<List<DispatchedJob>>(
      stream: DispatchService.instance.getJobsStream(companyId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: AdaptiveLoadingIndicator());
        }

        final allJobs = snapshot.data ?? [];
        final filteredJobs = _sortJobs(_filterJobs(allJobs));
        final totalPages = (filteredJobs.length / _rowsPerPage).ceil();
        final safePage = _currentPage.clamp(0, totalPages > 0 ? totalPages - 1 : 0);
        final startIndex = safePage * _rowsPerPage;
        final endIndex = (startIndex + _rowsPerPage).clamp(0, filteredJobs.length);
        final pageJobs = filteredJobs.sublist(startIndex, endIndex);

        return Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_notificationBannerDismissed &&
                    !WebNotificationService.instance.permissionGranted)
                  _buildNotificationBanner(isDark),
                _buildHeader(isDark, filteredJobs),
                _buildSummaryCards(allJobs, isDark),
                _buildFilterBar(isDark),
                DateRangeFilterBar(
                  activePreset: _datePreset,
                  customRange: _customRange,
                  onPresetChanged: (preset) {
                    setState(() {
                      _datePreset = preset;
                      _currentPage = 0;
                    });
                  },
                  onCustomRangeSelected: (range) {
                    setState(() {
                      _customRange = range;
                      _datePreset = DateRangePreset.custom;
                      _currentPage = 0;
                    });
                  },
                ),
                const SizedBox(height: 8),
                if (_selectedJobIds.isNotEmpty)
                  BulkActionsToolbar(
                    selectedJobIds: _selectedJobIds,
                    pageJobIds: pageJobs.map((j) => j.id).toList(),
                    members: _members,
                    companyId: companyId,
                    onClearSelection: () => setState(() => _selectedJobIds.clear()),
                    onSelectionChanged: () => setState(() {}),
                  ),
                Expanded(
                  child: filteredJobs.isEmpty
                      ? _buildEmptyState(isDark)
                      : _buildJobTable(pageJobs, isDark),
                ),
                if (filteredJobs.isNotEmpty)
                  _buildPaginationBar(isDark, filteredJobs.length, safePage, totalPages),
              ],
            ),
            // Dismiss overlay — click outside panel to close
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
            // Detail panel overlay
            if (_panelVisible && _selectedJobId != null)
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                width: MediaQuery.of(context).size.width * 0.42,
                child: WebJobDetailPanel(
                  key: ValueKey(_selectedJobId),
                  companyId: companyId,
                  jobId: _selectedJobId!,
                  onClose: _dismissPanel,
                  animateIn: _panelAnimateIn,
                  onEdit: (job) {
                    context.push('/jobs/create', extra: job);
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

  Widget _buildNotificationBanner(bool isDark) {
    final service = WebNotificationService.instance;
    final isDeniedPermanently = service.permissionDenied;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      color: Colors.orange.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(AppIcons.notification, size: 16, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isDeniedPermanently
                  ? 'Notifications are blocked. To receive job updates, enable notifications in your browser settings.'
                  : 'Enable notifications to get alerted when engineers update job status.',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.orange.shade200 : Colors.orange.shade800),
            ),
          ),
          if (!isDeniedPermanently)
            TextButton(
              onPressed: () async {
                final granted = await service.requestPermission();
                if (mounted) {
                  setState(() {
                    if (granted) _notificationBannerDismissed = true;
                  });
                }
              },
              child: const Text('Enable', style: TextStyle(fontSize: 12)),
            ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => setState(() => _notificationBannerDismissed = true),
            icon: Icon(AppIcons.close, size: 16),
            iconSize: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark, List<DispatchedJob> filteredJobs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        children: [
          Text(
            'Jobs Overview',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: filteredJobs.isEmpty ? null : () {
              final csv = generateJobsCsv(filteredJobs, _columnVisibility);
              final bytes = utf8.encode(csv);
              downloadFile(
                Uint8List.fromList(bytes),
                'jobs_export_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv',
                'text/csv',
              );
              // Analytics: CSV export tracked via Firebase
            },
            icon: Icon(AppIcons.download, size: 16),
            label: const Text('Export'),
          ),
          const SizedBox(width: 8),
          _buildColumnsButton(isDark),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => context.push('/jobs/create'),
            icon: Icon(AppIcons.add, size: 18),
            label: const Text('Create Job'),
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

  Widget _buildSummaryCards(List<DispatchedJob> allJobs, bool isDark) {
    final total = allJobs.length;
    final unassigned = allJobs.where((j) => j.status == DispatchedJobStatus.created).length;
    final active = allJobs.where((j) =>
        j.status == DispatchedJobStatus.accepted ||
        j.status == DispatchedJobStatus.enRoute ||
        j.status == DispatchedJobStatus.onSite).length;
    final completedToday = allJobs.where((j) =>
        j.status == DispatchedJobStatus.completed &&
        j.completedAt != null &&
        isToday(j.completedAt!)).length;
    final urgent = allJobs.where((j) =>
        j.priority != JobPriority.normal &&
        j.status != DispatchedJobStatus.completed).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          _summaryCard('Total', '$total', AppTheme.primaryBlue, isDark, null),
          const SizedBox(width: 12),
          _summaryCard('Unassigned', '$unassigned', Colors.orange, isDark, 'created'),
          const SizedBox(width: 12),
          _summaryCard('Active', '$active', Colors.blue, isDark, 'active'),
          const SizedBox(width: 12),
          _summaryCard('Done Today', '$completedToday', AppTheme.successGreen, isDark, 'completed'),
          const SizedBox(width: 12),
          _summaryCard('Urgent', '$urgent', Colors.red, isDark, 'urgent'),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, String count, Color color, bool isDark, String? filterValue) {
    final isSelected = _statusFilter == filterValue;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _statusFilter = isSelected ? null : filterValue;
            _currentPage = 0;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.2)
                : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: color, width: 1.5)
                : null,
          ),
          child: Column(
            children: [
              Text(
                count,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: color),
              ),
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
          // Status filter
          Flexible(
            child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: DropdownButtonFormField<String?>(
              isExpanded: true,
              initialValue: _statusFilter,
              decoration: InputDecoration(
                labelText: 'Status',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('All')),
                DropdownMenuItem(value: 'created', child: Text('Unassigned')),
                DropdownMenuItem(value: 'assigned', child: Text('Assigned')),
                DropdownMenuItem(value: 'accepted', child: Text('Accepted')),
                DropdownMenuItem(value: 'en_route', child: Text('En Route')),
                DropdownMenuItem(value: 'on_site', child: Text('On Site')),
                DropdownMenuItem(value: 'completed', child: Text('Completed')),
                DropdownMenuItem(value: 'declined', child: Text('Declined')),
                DropdownMenuItem(value: 'active', child: Text('Active')),
                DropdownMenuItem(value: 'urgent', child: Text('Urgent/Emergency')),
              ],
              onChanged: (v) => setState(() { _statusFilter = v; _currentPage = 0; }),
            ),
          ),
          ),
          const SizedBox(width: 12),

          // Engineer filter
          Flexible(
            child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: DropdownButtonFormField<String?>(
              isExpanded: true,
              initialValue: _engineerFilter,
              decoration: InputDecoration(
                labelText: 'Engineer',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Engineers')),
                const DropdownMenuItem(value: 'unassigned', child: Text('Unassigned')),
                ..._members.map((m) => DropdownMenuItem(
                  value: m.uid,
                  child: Text(m.displayName, overflow: TextOverflow.ellipsis),
                )),
              ],
              onChanged: (v) => setState(() { _engineerFilter = v; _currentPage = 0; }),
            ),
          ),
          ),
          const SizedBox(width: 12),

          // Search
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: 'Search jobs...',
                  prefixIcon: Icon(AppIcons.search, size: 18),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
                  if (_searchQuery.isEmpty && v.isNotEmpty) {
                    AnalyticsService.instance.logWebSearchUsed();
                  }
                  setState(() { _searchQuery = v; _currentPage = 0; });
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
            AppIcons.clipboard,
            size: 48,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty || _statusFilter != null || _engineerFilter != null
                ? 'No jobs match your filters'
                : 'No dispatched jobs yet',
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
                onChanged: col.alwaysVisible ? null : (v) {
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

  // Column definitions for dynamic visibility
  static const _allColumns = [
    _ColumnDef(key: 'title', label: 'Title', alwaysVisible: true),
    _ColumnDef(key: 'jobNumber', label: 'Job #'),
    _ColumnDef(key: 'jobType', label: 'Type'),
    _ColumnDef(key: 'site', label: 'Site'),
    _ColumnDef(key: 'engineer', label: 'Engineer'),
    _ColumnDef(key: 'date', label: 'Date'),
    _ColumnDef(key: 'priority', label: 'Priority'),
    _ColumnDef(key: 'status', label: 'Status'),
    _ColumnDef(key: 'contactName', label: 'Contact'),
  ];

  final Map<String, bool> _columnVisibility = {
    'title': true,
    'jobNumber': false,
    'jobType': false,
    'site': true,
    'engineer': true,
    'date': true,
    'priority': true,
    'status': true,
    'contactName': false,
  };

  List<_ColumnDef> get _visibleColumns =>
      _allColumns.where((c) => _columnVisibility[c.key] == true).toList();

  Widget _buildJobTable(List<DispatchedJob> jobs, bool isDark) {
    final visible = _visibleColumns;
    final sortIndex = visible.indexWhere((c) => c.key == _sortColumnKey);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: SizedBox(
        width: double.infinity,
        child: DataTable(
          sortColumnIndex: sortIndex >= 0 ? sortIndex : null,
          sortAscending: _sortAscending,
          showCheckboxColumn: true,
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
          rows: jobs.map((job) {
            final isSelected = _selectedJobIds.contains(job.id);
            return DataRow(
              selected: isSelected,
              onSelectChanged: (selected) {
                setState(() {
                  if (selected == true) {
                    _selectedJobIds.add(job.id);
                  } else {
                    _selectedJobIds.remove(job.id);
                  }
                });
              },
              cells: visible.map((col) => DataCell(
                _cellContent(col.key, job, isDark),
                onTap: () => _selectJob(job.id),
              )).toList(),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _cellContent(String key, DispatchedJob job, bool isDark) {
    switch (key) {
      case 'title':
        return Text(
          job.title,
          style: const TextStyle(fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
        );
      case 'jobNumber':
        return Text(job.jobNumber ?? '\u2014', overflow: TextOverflow.ellipsis);
      case 'jobType':
        return Text(job.jobType ?? '\u2014', overflow: TextOverflow.ellipsis);
      case 'site':
        return Text(job.siteName, overflow: TextOverflow.ellipsis);
      case 'engineer':
        return Text(
          job.assignedToName ?? '\u2014',
          style: TextStyle(
            color: job.assignedToName == null
                ? (isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey)
                : null,
          ),
        );
      case 'date':
        return Text(
          job.scheduledDate != null
              ? DateFormat('dd MMM yyyy').format(job.scheduledDate!)
              : '\u2014',
        );
      case 'priority':
        return jobPriorityBadge(job.priority);
      case 'status':
        return jobStatusBadge(job.status);
      case 'contactName':
        return Text(job.contactName ?? '\u2014', overflow: TextOverflow.ellipsis);
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
          top: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          // Rows per page
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
              if (v != null) setState(() { _rowsPerPage = v; _currentPage = 0; });
            },
          ),
          const Spacer(),
          // Range text
          Text(
            'Showing $startItem–$endItem of $totalItems',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
            ),
          ),
          const SizedBox(width: 16),
          // Page navigation
          IconButton(
            icon: const Icon(Icons.first_page, size: 20),
            onPressed: currentPage > 0 ? () => setState(() => _currentPage = 0) : null,
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            onPressed: currentPage > 0 ? () => setState(() => _currentPage--) : null,
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '${currentPage + 1} / $totalPages',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            onPressed: currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: const Icon(Icons.last_page, size: 20),
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
