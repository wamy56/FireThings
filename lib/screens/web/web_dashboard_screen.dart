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

class WebDashboardScreen extends StatefulWidget {
  final String? initialJobId;

  const WebDashboardScreen({super.key, this.initialJobId});

  @override
  State<WebDashboardScreen> createState() => _WebDashboardScreenState();
}

class _WebDashboardScreenState extends State<WebDashboardScreen> {
  String? _statusFilter;
  String? _engineerFilter;
  String _searchQuery = '';
  int _sortColumnIndex = 0;
  bool _sortAscending = true;
  String? _selectedJobId;
  List<CompanyMember> _members = [];
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final Set<String> _selectedJobIds = {};
  bool _notificationBannerDismissed = false;

  String? get _companyId => UserProfileService.instance.companyId;

  @override
  void initState() {
    super.initState();
    _selectedJobId = widget.initialJobId;
    _loadMembers();
    AnalyticsService.instance.logWebDashboardViewed();
  }

  void _selectJob(String jobId) {
    setState(() => _selectedJobId = jobId);
    AnalyticsService.instance.logWebJobDetailViewed();
  }

  @override
  void dispose() {
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
      filtered = filtered.where((j) => _statusToString(j.status) == _statusFilter).toList();
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

    return filtered;
  }

  List<DispatchedJob> _sortJobs(List<DispatchedJob> jobs) {
    final sorted = List<DispatchedJob>.from(jobs);
    sorted.sort((a, b) {
      int cmp;
      switch (_sortColumnIndex) {
        case 0:
          cmp = a.title.compareTo(b.title);
        case 1:
          cmp = a.siteName.compareTo(b.siteName);
        case 2:
          cmp = (a.assignedToName ?? '').compareTo(b.assignedToName ?? '');
        case 3:
          cmp = (a.scheduledDate ?? DateTime(2099)).compareTo(b.scheduledDate ?? DateTime(2099));
        case 4:
          cmp = a.priority.index.compareTo(b.priority.index);
        case 5:
          cmp = a.status.index.compareTo(b.status.index);
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
        const SingleActivator(LogicalKeyboardKey.escape): () => setState(() => _selectedJobId = null),
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

        return Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_notificationBannerDismissed &&
                    !WebNotificationService.instance.permissionGranted)
                  _buildNotificationBanner(isDark),
                _buildHeader(isDark),
                _buildSummaryCards(allJobs, isDark),
                _buildFilterBar(isDark),
                Expanded(
                  child: filteredJobs.isEmpty
                      ? _buildEmptyState(isDark)
                      : _buildJobTable(filteredJobs, isDark),
                ),
              ],
            ),
            // Dismiss overlay — click outside panel to close
            if (_selectedJobId != null)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedJobId = null),
                  child: Container(color: Colors.black.withValues(alpha: 0.05)),
                ),
              ),
            // Detail panel overlay
            if (_selectedJobId != null)
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                width: MediaQuery.of(context).size.width * 0.42,
                child: WebJobDetailPanel(
                  companyId: companyId,
                  jobId: _selectedJobId!,
                  onClose: () => setState(() => _selectedJobId = null),
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

  Widget _buildHeader(bool isDark) {
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
          if (_selectedJobIds.isNotEmpty) ...[
            Text(
              '${_selectedJobIds.length} selected',
              style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey),
            ),
            const SizedBox(width: 12),
            _buildBulkAssignButton(isDark),
            const SizedBox(width: 12),
          ],
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

  Widget _buildBulkAssignButton(bool isDark) {
    return OutlinedButton.icon(
      onPressed: () => _showBulkAssignDialog(),
      icon: Icon(AppIcons.userAdd, size: 16),
      label: const Text('Assign Selected'),
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
        _isToday(j.completedAt!)).length;
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
              onChanged: (v) => setState(() => _statusFilter = v),
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
              onChanged: (v) => setState(() => _engineerFilter = v),
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
                  setState(() => _searchQuery = v);
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

  Widget _buildJobTable(List<DispatchedJob> jobs, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: SizedBox(
        width: double.infinity,
        child: DataTable(
          sortColumnIndex: _sortColumnIndex,
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
          columns: [
            DataColumn(
              label: const Text('Title', style: TextStyle(fontWeight: FontWeight.w600)),
              onSort: (i, asc) => setState(() { _sortColumnIndex = i; _sortAscending = asc; }),
            ),
            DataColumn(
              label: const Text('Site', style: TextStyle(fontWeight: FontWeight.w600)),
              onSort: (i, asc) => setState(() { _sortColumnIndex = i; _sortAscending = asc; }),
            ),
            DataColumn(
              label: const Text('Engineer', style: TextStyle(fontWeight: FontWeight.w600)),
              onSort: (i, asc) => setState(() { _sortColumnIndex = i; _sortAscending = asc; }),
            ),
            DataColumn(
              label: const Text('Date', style: TextStyle(fontWeight: FontWeight.w600)),
              onSort: (i, asc) => setState(() { _sortColumnIndex = i; _sortAscending = asc; }),
            ),
            DataColumn(
              label: const Text('Priority', style: TextStyle(fontWeight: FontWeight.w600)),
              onSort: (i, asc) => setState(() { _sortColumnIndex = i; _sortAscending = asc; }),
            ),
            DataColumn(
              label: const Text('Status', style: TextStyle(fontWeight: FontWeight.w600)),
              onSort: (i, asc) => setState(() { _sortColumnIndex = i; _sortAscending = asc; }),
            ),
          ],
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
              cells: [
                DataCell(
                  Text(
                    job.title,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _selectJob(job.id),
                ),
                DataCell(
                  Text(
                    job.siteName,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _selectJob(job.id),
                ),
                DataCell(
                  Text(
                    job.assignedToName ?? '\u2014',
                    style: TextStyle(
                      color: job.assignedToName == null
                          ? (isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey)
                          : null,
                    ),
                  ),
                  onTap: () => _selectJob(job.id),
                ),
                DataCell(
                  Text(
                    job.scheduledDate != null
                        ? DateFormat('dd MMM yyyy').format(job.scheduledDate!)
                        : '\u2014',
                  ),
                  onTap: () => _selectJob(job.id),
                ),
                DataCell(
                  _priorityBadge(job.priority),
                  onTap: () => _selectJob(job.id),
                ),
                DataCell(
                  _statusBadge(job.status),
                  onTap: () => _selectJob(job.id),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _statusBadge(DispatchedJobStatus status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _priorityBadge(JobPriority priority) {
    if (priority == JobPriority.normal) {
      return Text(
        'Normal',
        style: TextStyle(fontSize: 12, color: AppTheme.mediumGrey),
      );
    }
    final isEmergency = priority == JobPriority.emergency;
    final color = isEmergency ? Colors.red : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isEmergency ? 'EMERGENCY' : 'URGENT',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  void _showBulkAssignDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        String? selectedUid;
        String? selectedName;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text('Assign ${_selectedJobIds.length} Jobs'),
              content: DropdownButtonFormField<String?>(
                decoration: InputDecoration(
                  labelText: 'Engineer',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: _members.map((m) => DropdownMenuItem(
                  value: m.uid,
                  child: Text(m.displayName),
                )).toList(),
                onChanged: (v) {
                  final member = _members.where((m) => m.uid == v).firstOrNull;
                  setDialogState(() {
                    selectedUid = v;
                    selectedName = member?.displayName;
                  });
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedUid == null
                      ? null
                      : () async {
                          final companyId = _companyId;
                          if (companyId == null) return;
                          for (final jobId in _selectedJobIds) {
                            await DispatchService.instance.assignJob(
                              companyId: companyId,
                              jobId: jobId,
                              engineerUid: selectedUid!,
                              engineerName: selectedName!,
                            );
                          }
                          if (ctx.mounted) {
                            setState(() => _selectedJobIds.clear());
                            Navigator.of(ctx).pop();
                          }
                        },
                  child: const Text('Assign'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Color _statusColor(DispatchedJobStatus status) {
    switch (status) {
      case DispatchedJobStatus.created: return Colors.orange;
      case DispatchedJobStatus.assigned: return Colors.blue;
      case DispatchedJobStatus.accepted: return Colors.teal;
      case DispatchedJobStatus.enRoute: return Colors.indigo;
      case DispatchedJobStatus.onSite: return Colors.purple;
      case DispatchedJobStatus.completed: return AppTheme.successGreen;
      case DispatchedJobStatus.declined: return Colors.red;
    }
  }

  String _statusLabel(DispatchedJobStatus status) {
    switch (status) {
      case DispatchedJobStatus.created: return 'Unassigned';
      case DispatchedJobStatus.assigned: return 'Assigned';
      case DispatchedJobStatus.accepted: return 'Accepted';
      case DispatchedJobStatus.enRoute: return 'En Route';
      case DispatchedJobStatus.onSite: return 'On Site';
      case DispatchedJobStatus.completed: return 'Completed';
      case DispatchedJobStatus.declined: return 'Declined';
    }
  }

  String _statusToString(DispatchedJobStatus status) {
    switch (status) {
      case DispatchedJobStatus.created: return 'created';
      case DispatchedJobStatus.assigned: return 'assigned';
      case DispatchedJobStatus.accepted: return 'accepted';
      case DispatchedJobStatus.enRoute: return 'en_route';
      case DispatchedJobStatus.onSite: return 'on_site';
      case DispatchedJobStatus.completed: return 'completed';
      case DispatchedJobStatus.declined: return 'declined';
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }
}
