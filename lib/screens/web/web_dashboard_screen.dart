import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/dispatched_job.dart';
import '../../models/company_member.dart';
import '../../services/dispatch_service.dart';
import '../../services/company_service.dart';
import '../../services/user_profile_service.dart';
import '../../theme/web_theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import 'web_job_detail_panel.dart';
import '../../services/web_notification_service.dart';
import '../../services/analytics_service.dart';
import 'dashboard/job_helpers.dart';
import 'dashboard/date_range_filter.dart';
import 'dashboard/bulk_actions_toolbar.dart';
import 'dashboard/csv_export.dart';
import 'dart:async';
import 'dart:convert';
import '../../utils/download_stub.dart'
    if (dart.library.html) '../../utils/download_web.dart';

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
  String? _companyName;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final Set<String> _selectedJobIds = {};
  bool _notificationBannerDismissed = false;
  Stream<List<DispatchedJob>>? _jobsStream;
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
    if (widget.initialJobId != null) {
      _selectedJobId = widget.initialJobId;
      _panelVisible = true;
      _overlayController.value = 1.0;
    }
    _loadMembers();
    _initJobsStream();
    AnalyticsService.instance.logWebDashboardViewed();
  }

  void _initJobsStream() {
    final companyId = _companyId;
    if (companyId != null) {
      _jobsStream = DispatchService.instance.getJobsStream(companyId);
    }
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
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    final companyId = _companyId;
    if (companyId == null) return;
    final members = await CompanyService.instance.getCompanyMembers(companyId);
    if (mounted) setState(() => _members = members);
    try {
      final company = await CompanyService.instance.getCompany(companyId);
      if (mounted && company != null) {
        setState(() => _companyName = company.name);
      }
    } catch (_) {}
  }

  List<DispatchedJob> _filterJobs(List<DispatchedJob> jobs) {
    var filtered = jobs;

    if (_statusFilter != null) {
      if (_statusFilter == 'active') {
        filtered = filtered
            .where((j) =>
                j.status == DispatchedJobStatus.accepted ||
                j.status == DispatchedJobStatus.enRoute ||
                j.status == DispatchedJobStatus.onSite)
            .toList();
      } else if (_statusFilter == 'urgent') {
        filtered = filtered
            .where((j) =>
                j.priority != JobPriority.normal &&
                j.status != DispatchedJobStatus.completed)
            .toList();
      } else {
        filtered = filtered
            .where((j) => jobStatusToString(j.status) == _statusFilter)
            .toList();
      }
    }

    if (_engineerFilter != null) {
      if (_engineerFilter == 'unassigned') {
        filtered = filtered.where((j) => j.assignedTo == null).toList();
      } else {
        filtered =
            filtered.where((j) => j.assignedTo == _engineerFilter).toList();
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
        final d = DateTime(
            j.scheduledDate!.year, j.scheduledDate!.month, j.scheduledDate!.day);
        switch (_datePreset!) {
          case DateRangePreset.today:
            return d == today;
          case DateRangePreset.thisWeek:
            final weekStart =
                today.subtract(Duration(days: today.weekday - 1));
            final weekEnd = weekStart.add(const Duration(days: 7));
            return !d.isBefore(weekStart) && d.isBefore(weekEnd);
          case DateRangePreset.thisMonth:
            return d.year == today.year && d.month == today.month;
          case DateRangePreset.overdue:
            return d.isBefore(today) &&
                j.status != DispatchedJobStatus.completed;
          case DateRangePreset.custom:
            if (_customRange == null) return true;
            final start = DateTime(_customRange!.start.year,
                _customRange!.start.month, _customRange!.start.day);
            final end = DateTime(_customRange!.end.year,
                    _customRange!.end.month, _customRange!.end.day)
                .add(const Duration(days: 1));
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
          cmp = (a.scheduledDate ?? DateTime(2099))
              .compareTo(b.scheduledDate ?? DateTime(2099));
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

  // ── Helpers ──

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _firstName {
    final name = FirebaseAuth.instance.currentUser?.displayName;
    if (name == null || name.isEmpty) return '';
    return name.split(' ').first;
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final companyId = _companyId;
    final screenWidth = MediaQuery.of(context).size.width;
    final showRail = screenWidth >= 1280;

    if (companyId == null) {
      return Center(child: Text('No company found', style: FtText.bodySoft));
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN): () =>
            context.push('/jobs/create'),
        const SingleActivator(LogicalKeyboardKey.slash): () =>
            _searchFocusNode.requestFocus(),
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_panelVisible) _dismissPanel();
        },
      },
      child: Focus(
        autofocus: true,
        child: StreamBuilder<List<DispatchedJob>>(
          stream: _jobsStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: AdaptiveLoadingIndicator());
            }

            final allJobs = snapshot.data ?? [];
            final filteredJobs = _sortJobs(_filterJobs(allJobs));
            final totalPages = (filteredJobs.length / _rowsPerPage).ceil();
            final safePage =
                _currentPage.clamp(0, totalPages > 0 ? totalPages - 1 : 0);
            final startIndex = safePage * _rowsPerPage;
            final endIndex =
                (startIndex + _rowsPerPage).clamp(0, filteredJobs.length);
            final pageJobs = filteredJobs.sublist(startIndex, endIndex);

            return Stack(
              children: [
                Container(
                  color: FtColors.bgAlt,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!_notificationBannerDismissed &&
                          !WebNotificationService.instance.permissionGranted)
                        _buildNotificationBanner(),
                      _buildHeader(allJobs),
                      _buildKpiStrip(allJobs),
                      const SizedBox(height: 20),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
                          child: showRail
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                        child: _buildTableCard(
                                            filteredJobs,
                                            pageJobs,
                                            safePage,
                                            totalPages,
                                            companyId)),
                                    const SizedBox(width: 20),
                                    SizedBox(
                                        width: 360,
                                        child: _buildRail(allJobs)),
                                  ],
                                )
                              : _buildTableCard(filteredJobs, pageJobs,
                                  safePage, totalPages, companyId),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_panelVisible)
                  Positioned.fill(
                    child: FadeTransition(
                      opacity: _overlayOpacity,
                      child: GestureDetector(
                        onTap: _dismissPanel,
                        child: Container(
                            color: FtColors.primary.withValues(alpha: 0.08)),
                      ),
                    ),
                  ),
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

  // ── Notification banner ──

  Widget _buildNotificationBanner() {
    final service = WebNotificationService.instance;
    final isDeniedPermanently = service.permissionDenied;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
      decoration: BoxDecoration(
        color: FtColors.warningSoft,
        border:
            const Border(bottom: BorderSide(color: FtColors.border, width: 1)),
      ),
      child: Row(
        children: [
          Icon(AppIcons.notification, size: 16, color: FtColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isDeniedPermanently
                  ? 'Notifications are blocked. To receive job updates, enable notifications in your browser settings.'
                  : 'Enable notifications to get alerted when engineers update job status.',
              style: FtText.helper.copyWith(color: FtColors.fg1),
            ),
          ),
          if (!isDeniedPermanently)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () async {
                  final granted = await service.requestPermission();
                  if (mounted) {
                    setState(() {
                      if (granted) _notificationBannerDismissed = true;
                    });
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: FtColors.accent,
                    borderRadius: FtRadii.mdAll,
                  ),
                  child: Text('Enable',
                      style: FtText.inter(
                          size: 12,
                          weight: FontWeight.w600,
                          color: Colors.white)),
                ),
              ),
            ),
          const SizedBox(width: 8),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () =>
                  setState(() => _notificationBannerDismissed = true),
              child: Icon(AppIcons.close, size: 16, color: FtColors.fg2),
            ),
          ),
        ],
      ),
    );
  }

  // ── Page header ──

  Widget _buildHeader(List<DispatchedJob> allJobs) {
    final urgent = allJobs
        .where((j) =>
            j.priority != JobPriority.normal &&
            j.status != DispatchedJobStatus.completed)
        .length;
    final activeEngineers = _members.where((m) => m.isActive).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_companyName != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: FtColors.accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                              color: FtColors.success,
                              shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Live · $_companyName',
                          style: FtText.inter(
                              size: 12,
                              weight: FontWeight.w600,
                              color: FtColors.accent),
                        ),
                      ],
                    ),
                  ),
                if (_firstName.isNotEmpty)
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: '$_greeting, ', style: FtText.pageTitle),
                      TextSpan(
                          text: _firstName,
                          style: FtText.pageTitle
                              .copyWith(color: FtColors.accent)),
                    ]),
                  )
                else
                  Text(_greeting, style: FtText.pageTitle),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: FtColors.success,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: FtColors.success.withValues(alpha: 0.4),
                              spreadRadius: 2,
                              blurRadius: 4)
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                      style: FtText.bodySoft,
                    ),
                    const SizedBox(width: 16),
                    Text('·', style: FtText.bodySoft),
                    const SizedBox(width: 16),
                    Text('$activeEngineers engineers active',
                        style: FtText.bodySoft),
                    if (urgent > 0) ...[
                      const SizedBox(width: 16),
                      Text('·', style: FtText.bodySoft),
                      const SizedBox(width: 16),
                      Text('$urgent urgent',
                          style: FtText.inter(
                              size: 14,
                              weight: FontWeight.w600,
                              color: FtColors.danger)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              _FtButton(
                label: 'Today',
                onTap: () {
                  setState(() {
                    _datePreset = _datePreset == DateRangePreset.today
                        ? null
                        : DateRangePreset.today;
                    _currentPage = 0;
                  });
                },
                isPrimary: false,
              ),
              const SizedBox(width: 10),
              _FtButton(
                label: 'New job',
                icon: AppIcons.add,
                onTap: () => context.push('/jobs/create'),
                isPrimary: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── KPI strip ──

  Widget _buildKpiStrip(List<DispatchedJob> allJobs) {
    final total = allJobs.length;
    final todayCount = allJobs
        .where(
            (j) => j.scheduledDate != null && isToday(j.scheduledDate!))
        .length;
    final urgent = allJobs
        .where((j) =>
            j.priority != JobPriority.normal &&
            j.status != DispatchedJobStatus.completed)
        .length;
    final unassigned = allJobs
        .where((j) => j.status == DispatchedJobStatus.created)
        .length;
    final active = allJobs
        .where((j) =>
            j.status == DispatchedJobStatus.accepted ||
            j.status == DispatchedJobStatus.enRoute ||
            j.status == DispatchedJobStatus.onSite)
        .length;
    final completedToday = allJobs
        .where((j) =>
            j.status == DispatchedJobStatus.completed &&
            j.completedAt != null &&
            isToday(j.completedAt!))
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 0),
      child: Row(
        children: [
          Expanded(
              child: _kpiCard(
            label: 'JOBS TODAY',
            value: '$todayCount',
            meta: 'of $total total',
            filterValue: null,
            variant: _KpiVariant.normal,
          )),
          const SizedBox(width: 16),
          Expanded(
              child: _kpiCard(
            label: 'SLA AT RISK',
            value: '$urgent',
            meta: urgent > 0 ? 'need attention' : 'all clear',
            filterValue: 'urgent',
            variant: _KpiVariant.danger,
          )),
          const SizedBox(width: 16),
          Expanded(
              child: _kpiCard(
            label: 'UNASSIGNED',
            value: '$unassigned',
            meta: 'awaiting dispatch',
            filterValue: 'created',
            variant: _KpiVariant.normal,
          )),
          const SizedBox(width: 16),
          Expanded(
              child: _kpiCard(
            label: 'ACTIVE',
            value: '$active',
            meta: 'in progress',
            filterValue: 'active',
            variant: _KpiVariant.featured,
          )),
          const SizedBox(width: 16),
          Expanded(
              child: _kpiCard(
            label: 'DONE TODAY',
            value: '$completedToday',
            meta: 'completed',
            filterValue: 'completed',
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
    final isSelected = _statusFilter == filterValue;
    final isFeatured = variant == _KpiVariant.featured;
    final isDanger = variant == _KpiVariant.danger;
    final hasValue = (int.tryParse(value) ?? 0) > 0;

    return _HoverLiftCard(
      onTap: () {
        setState(() {
          _statusFilter = isSelected ? null : filterValue;
          _currentPage = 0;
        });
      },
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
                style: FtText.kpiValue.copyWith(
                  color: isFeatured
                      ? FtColors.accent
                      : isDanger && hasValue
                          ? FtColors.danger
                          : null,
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

  // ── Table card ──

  Widget _buildTableCard(
    List<DispatchedJob> filteredJobs,
    List<DispatchedJob> pageJobs,
    int safePage,
    int totalPages,
    String companyId,
  ) {
    return Container(
      decoration: FtDecorations.card(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCardHeader(filteredJobs),
          _buildFilterChips(),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(
              color: FtColors.bgAlt,
              border: Border(
                  bottom: BorderSide(color: FtColors.border, width: 1)),
            ),
            child: DateRangeFilterBar(
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
          ),
          if (_selectedJobIds.isNotEmpty)
            BulkActionsToolbar(
              selectedJobIds: _selectedJobIds,
              pageJobIds: pageJobs.map((j) => j.id).toList(),
              members: _members,
              companyId: companyId,
              onClearSelection: () =>
                  setState(() => _selectedJobIds.clear()),
              onSelectionChanged: () => setState(() {}),
            ),
          Expanded(
            child: filteredJobs.isEmpty
                ? _buildEmptyState()
                : _buildJobTable(pageJobs),
          ),
          if (filteredJobs.isNotEmpty)
            _buildPaginationBar(
                filteredJobs.length, safePage, totalPages),
        ],
      ),
    );
  }

  Widget _buildCardHeader(List<DispatchedJob> filteredJobs) {
    return Container(
      padding: FtSpacing.cardHeader,
      decoration: const BoxDecoration(
        border:
            Border(bottom: BorderSide(color: FtColors.border, width: 1)),
      ),
      child: Row(
        children: [
          Text('Active jobs', style: FtText.sectionTitle),
          const SizedBox(width: 12),
          Text('${filteredJobs.length} results', style: FtText.helper),
          const Spacer(),
          MouseRegion(
            cursor: filteredJobs.isEmpty
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            child: GestureDetector(
              onTap: filteredJobs.isEmpty
                  ? null
                  : () {
                      final csv = generateJobsCsv(
                          filteredJobs, _columnVisibility);
                      final bytes = utf8.encode(csv);
                      downloadFile(
                        Uint8List.fromList(bytes),
                        'jobs_export_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv',
                        'text/csv',
                      );
                    },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(AppIcons.download,
                      size: 14,
                      color: filteredJobs.isEmpty
                          ? FtColors.hint
                          : FtColors.fg2),
                  const SizedBox(width: 4),
                  Text('Export',
                      style: FtText.helper.copyWith(
                          color: filteredJobs.isEmpty
                              ? FtColors.hint
                              : FtColors.fg2)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          _buildColumnsButton(),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 22),
      decoration: const BoxDecoration(
        color: FtColors.bgAlt,
        border:
            Border(bottom: BorderSide(color: FtColors.border, width: 1)),
      ),
      child: Row(
        children: [
          _StatusChip(
            label: 'All',
            isSelected: _statusFilter == null,
            onTap: () =>
                setState(() { _statusFilter = null; _currentPage = 0; }),
          ),
          const SizedBox(width: 6),
          _StatusChip(
            label: 'Unassigned',
            isSelected: _statusFilter == 'created',
            onTap: () => setState(() {
              _statusFilter =
                  _statusFilter == 'created' ? null : 'created';
              _currentPage = 0;
            }),
          ),
          const SizedBox(width: 6),
          _StatusChip(
            label: 'In progress',
            isSelected: _statusFilter == 'active',
            onTap: () => setState(() {
              _statusFilter =
                  _statusFilter == 'active' ? null : 'active';
              _currentPage = 0;
            }),
          ),
          const SizedBox(width: 6),
          _StatusChip(
            label: 'On site',
            isSelected: _statusFilter == 'on_site',
            onTap: () => setState(() {
              _statusFilter =
                  _statusFilter == 'on_site' ? null : 'on_site';
              _currentPage = 0;
            }),
          ),
          const SizedBox(width: 6),
          _StatusChip(
            label: 'Completed',
            isSelected: _statusFilter == 'completed',
            onTap: () => setState(() {
              _statusFilter =
                  _statusFilter == 'completed' ? null : 'completed';
              _currentPage = 0;
            }),
          ),
          const SizedBox(width: 16),
          Container(
            constraints: const BoxConstraints(maxWidth: 170),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            decoration: BoxDecoration(
              color: FtColors.bg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: FtColors.border, width: 1.5),
            ),
            child: DropdownButton<String?>(
              value: _engineerFilter,
              underline: const SizedBox.shrink(),
              isDense: true,
              isExpanded: true,
              icon: Icon(AppIcons.arrowDown,
                  size: 14, color: FtColors.fg2),
              style: FtText.inter(
                  size: 12,
                  weight: FontWeight.w500,
                  color: FtColors.fg1),
              items: [
                DropdownMenuItem(
                    value: null,
                    child: Text('All Engineers',
                        style: FtText.inter(
                            size: 12,
                            weight: FontWeight.w500,
                            color: FtColors.fg2))),
                DropdownMenuItem(
                    value: 'unassigned',
                    child: Text('Unassigned',
                        style: FtText.inter(
                            size: 12,
                            weight: FontWeight.w500,
                            color: FtColors.fg1))),
                ..._members.map((m) => DropdownMenuItem(
                      value: m.uid,
                      child: Text(m.displayName,
                          style: FtText.inter(
                              size: 12,
                              weight: FontWeight.w500,
                              color: FtColors.fg1),
                          overflow: TextOverflow.ellipsis),
                    )),
              ],
              onChanged: (v) => setState(() {
                _engineerFilter = v;
                _currentPage = 0;
              }),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 200,
            height: 34,
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: FtText.inter(size: 13, weight: FontWeight.w500, color: FtColors.fg1),
              decoration: InputDecoration(
                hintText: 'Search jobs...',
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(8),
                  child:
                      Icon(AppIcons.search, size: 16, color: FtColors.hint),
                ),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 36, minHeight: 34),
                hintStyle: FtText.inter(size: 13, weight: FontWeight.w500, color: FtColors.hint),
                filled: true,
                fillColor: FtColors.bg,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: FtRadii.mdAll,
                  borderSide:
                      const BorderSide(color: FtColors.border, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: FtRadii.mdAll,
                  borderSide:
                      const BorderSide(color: FtColors.border, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: FtRadii.mdAll,
                  borderSide:
                      const BorderSide(color: FtColors.primary, width: 1.5),
                ),
                isDense: true,
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(AppIcons.close,
                            size: 14, color: FtColors.hint),
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
                _searchDebounce?.cancel();
                _searchDebounce =
                    Timer(const Duration(milliseconds: 300), () {
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
        ],
      ),
    );
  }

  Widget _buildColumnsButton() {
    return PopupMenuButton<String>(
      icon: Icon(AppIcons.setting, size: 16, color: FtColors.fg2),
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
                        setState(
                            () => _columnVisibility[col.key] = v ?? false);
                        setMenuState(() {});
                      },
                title: Text(col.label,
                    style: FtText.inter(
                        size: 13,
                        weight: FontWeight.w500,
                        color: FtColors.fg1)),
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

  // ── Empty state ──

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(AppIcons.clipboard, size: 48, color: FtColors.hint),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ||
                    _statusFilter != null ||
                    _engineerFilter != null
                ? 'No jobs match your filters'
                : 'No dispatched jobs yet',
            style: FtText.bodySoft,
          ),
          const SizedBox(height: 8),
          if (_searchQuery.isNotEmpty ||
              _statusFilter != null ||
              _engineerFilter != null)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => setState(() {
                  _statusFilter = null;
                  _engineerFilter = null;
                  _searchQuery = '';
                  _searchController.clear();
                  _datePreset = null;
                  _currentPage = 0;
                }),
                child: Text('Clear filters',
                    style: FtText.inter(
                        size: 14,
                        weight: FontWeight.w600,
                        color: FtColors.accent)),
              ),
            ),
        ],
      ),
    );
  }

  // ── Job table ──

  Widget _buildJobTable(List<DispatchedJob> jobs) {
    final visible = _visibleColumns;
    final sortIndex = visible.indexWhere((c) => c.key == _sortColumnKey);

    return SingleChildScrollView(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: FtColors.border),
        child: SizedBox(
          width: double.infinity,
          child: DataTable(
            sortColumnIndex: sortIndex >= 0 ? sortIndex : null,
            sortAscending: _sortAscending,
            showCheckboxColumn: true,
            headingRowColor: WidgetStateProperty.all(FtColors.bgAlt),
            headingRowHeight: 48,
            dataRowColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return FtColors.accentSoft;
              }
              if (states.contains(WidgetState.hovered)) {
                return FtColors.bgAlt;
              }
              return null;
            }),
            dataRowMinHeight: 56,
            dataRowMaxHeight: 56,
            dividerThickness: 1,
            checkboxHorizontalMargin: 16,
            columns: visible
                .map((col) => DataColumn(
                      label: Text(col.label.toUpperCase(),
                          style: FtText.labelStrong),
                      onSort: (_, asc) => setState(() {
                        _sortColumnKey = col.key;
                        _sortAscending = asc;
                      }),
                    ))
                .toList(),
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
                cells: visible
                    .map((col) => DataCell(
                          _cellContent(col.key, job),
                          onTap: () => _selectJob(job.id),
                        ))
                    .toList(),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _cellContent(String key, DispatchedJob job) {
    switch (key) {
      case 'title':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(job.title,
                style: FtText.inter(
                    size: 14,
                    weight: FontWeight.w600,
                    color: FtColors.fg1),
                overflow: TextOverflow.ellipsis),
            Text(job.siteName,
                style: FtText.inter(
                    size: 12.5,
                    weight: FontWeight.w500,
                    color: FtColors.fg2),
                overflow: TextOverflow.ellipsis),
          ],
        );
      case 'jobNumber':
        return Text(job.jobNumber ?? '—', style: FtText.monoSmall);
      case 'jobType':
        return Text(job.jobType ?? '—',
            style: FtText.body, overflow: TextOverflow.ellipsis);
      case 'site':
        return Text(job.siteName,
            style: FtText.body, overflow: TextOverflow.ellipsis);
      case 'engineer':
        if (job.assignedToName == null) {
          return Text('—', style: FtText.bodySoft);
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: _avatarColor(job.assignedToName!),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                _initials(job.assignedToName!),
                style: FtText.inter(
                    size: 10, weight: FontWeight.w700, color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(job.assignedToName!,
                  style: FtText.body, overflow: TextOverflow.ellipsis),
            ),
          ],
        );
      case 'date':
        return Text(
          job.scheduledDate != null
              ? DateFormat('dd MMM yyyy').format(job.scheduledDate!)
              : '—',
          style: FtText.body,
        );
      case 'priority':
        return jobPriorityBadge(job.priority);
      case 'status':
        return jobStatusBadge(job.status);
      case 'contactName':
        return Text(job.contactName ?? '—',
            style: FtText.body, overflow: TextOverflow.ellipsis);
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Pagination ──

  Widget _buildPaginationBar(
      int totalItems, int currentPage, int totalPages) {
    final startItem = totalItems == 0 ? 0 : currentPage * _rowsPerPage + 1;
    final endItem =
        ((currentPage + 1) * _rowsPerPage).clamp(0, totalItems);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      decoration: const BoxDecoration(
        border:
            Border(top: BorderSide(color: FtColors.border, width: 1)),
      ),
      child: Row(
        children: [
          Text('Rows per page:', style: FtText.helper),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: _rowsPerPage,
            underline: const SizedBox.shrink(),
            isDense: true,
            style: FtText.inter(
                size: 13,
                weight: FontWeight.w500,
                color: FtColors.fg1),
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
          Text('Showing $startItem–$endItem of $totalItems',
              style: FtText.bodySoft),
          const SizedBox(width: 16),
          _paginationBtn(
            Icons.first_page,
            currentPage > 0 ? () => setState(() => _currentPage = 0) : null,
          ),
          _paginationBtn(
            Icons.chevron_left,
            currentPage > 0 ? () => setState(() => _currentPage--) : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('${currentPage + 1} / $totalPages',
                style: FtText.inter(
                    size: 13,
                    weight: FontWeight.w600,
                    color: FtColors.fg1)),
          ),
          _paginationBtn(
            Icons.chevron_right,
            currentPage < totalPages - 1
                ? () => setState(() => _currentPage++)
                : null,
          ),
          _paginationBtn(
            Icons.last_page,
            currentPage < totalPages - 1
                ? () => setState(() => _currentPage = totalPages - 1)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _paginationBtn(IconData icon, VoidCallback? onPressed) {
    return MouseRegion(
      cursor: onPressed != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: FtRadii.smAll,
          ),
          child: Icon(icon,
              size: 20,
              color: onPressed != null ? FtColors.fg1 : FtColors.hint),
        ),
      ),
    );
  }

  // ── Right rail ──

  Widget _buildRail(List<DispatchedJob> allJobs) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildScheduleCard(allJobs),
          const SizedBox(height: 20),
          _buildEngineersCard(allJobs),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(List<DispatchedJob> allJobs) {
    final todayJobs = allJobs
        .where(
            (j) => j.scheduledDate != null && isToday(j.scheduledDate!))
        .toList()
      ..sort((a, b) => a.scheduledDate!.compareTo(b.scheduledDate!));
    final display = todayJobs.take(6).toList();

    return Container(
      decoration: FtDecorations.card(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: FtSpacing.cardHeader,
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: FtColors.border, width: 1)),
            ),
            child: Row(
              children: [
                Text("Today's schedule", style: FtText.cardTitle),
                const Spacer(),
                Text('${todayJobs.length} visits', style: FtText.helper),
              ],
            ),
          ),
          if (display.isEmpty)
            Padding(
              padding: FtSpacing.cardBody,
              child: Text('No visits scheduled today',
                  style: FtText.bodySoft),
            )
          else
            ...display.map((job) {
              final time =
                  (job.scheduledDate!.hour > 0 || job.scheduledDate!.minute > 0)
                      ? DateFormat('HH:mm').format(job.scheduledDate!)
                      : '—';
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(
                      bottom:
                          BorderSide(color: FtColors.border, width: 1)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 52,
                      child: Text(time, style: FtText.monoSmall),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(job.title,
                              style: FtText.inter(
                                  size: 13.5,
                                  weight: FontWeight.w600,
                                  color: FtColors.fg1),
                              overflow: TextOverflow.ellipsis),
                          Text(
                            job.assignedToName ?? 'Unassigned',
                            style: FtText.inter(
                                size: 12,
                                weight: FontWeight.w500,
                                color: FtColors.fg2),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          if (todayJobs.length > 6)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 22, vertical: 12),
              child: Text(
                  '+${todayJobs.length - 6} more',
                  style: FtText.helper.copyWith(color: FtColors.accent)),
            ),
        ],
      ),
    );
  }

  Widget _buildEngineersCard(List<DispatchedJob> allJobs) {
    final activeCount = _members.where((m) => m.isActive).length;

    return Container(
      decoration: FtDecorations.card(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: FtSpacing.cardHeader,
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: FtColors.border, width: 1)),
            ),
            child: Row(
              children: [
                Text('Engineers', style: FtText.cardTitle),
                const Spacer(),
                Text('$activeCount of ${_members.length} active',
                    style: FtText.helper),
              ],
            ),
          ),
          if (_members.isEmpty)
            Padding(
              padding: FtSpacing.cardBody,
              child: Text('No team members', style: FtText.bodySoft),
            )
          else
            ..._members.map((member) {
              final memberJobs = allJobs.where((j) =>
                  j.assignedTo == member.uid &&
                  j.status != DispatchedJobStatus.completed);
              final jobCount = memberJobs.length;
              final onSite = memberJobs
                  .where(
                      (j) => j.status == DispatchedJobStatus.onSite);
              final enRoute = memberJobs
                  .where(
                      (j) => j.status == DispatchedJobStatus.enRoute);
              String status;
              if (onSite.isNotEmpty) {
                status = 'On site · ${onSite.first.siteName}';
              } else if (enRoute.isNotEmpty) {
                status = 'En route';
              } else if (jobCount > 0) {
                status = '$jobCount active jobs';
              } else {
                status = 'Available';
              }

              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(
                      bottom:
                          BorderSide(color: FtColors.border, width: 1)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _avatarColor(member.displayName),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _initials(member.displayName),
                        style: FtText.inter(
                            size: 12,
                            weight: FontWeight.w700,
                            color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(member.displayName,
                              style: FtText.inter(
                                  size: 14,
                                  weight: FontWeight.w600,
                                  color: FtColors.fg1),
                              overflow: TextOverflow.ellipsis),
                          Text(status,
                              style: FtText.inter(
                                  size: 12,
                                  weight: FontWeight.w500,
                                  color: FtColors.fg2),
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Text('$jobCount', style: FtText.monoSmall),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── Utility ──

  static Color _avatarColor(String name) {
    const colors = [
      Color(0xFF6366F1),
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
      Color(0xFFF97316),
      Color(0xFF14B8A6),
      Color(0xFF3B82F6),
      Color(0xFFEF4444),
      Color(0xFF10B981),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '?';
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Private widgets
// ═══════════════════════════════════════════════════════════════════════

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

class _StatusChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_StatusChip> createState() => _StatusChipState();
}

class _StatusChipState extends State<_StatusChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: FtMotion.fast,
          curve: FtMotion.standardCurve,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? FtColors.primary
                : _hovered
                    ? FtColors.bg
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isSelected
                  ? FtColors.primary
                  : _hovered
                      ? FtColors.border
                      : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Text(
            widget.label,
            style: FtText.inter(
              size: 12,
              weight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
              color: widget.isSelected
                  ? Colors.white
                  : _hovered
                      ? FtColors.primary
                      : FtColors.fg2,
            ),
          ),
        ),
      ),
    );
  }
}

class _FtButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool isPrimary;

  const _FtButton({
    required this.label,
    this.icon,
    required this.onTap,
    required this.isPrimary,
  });

  @override
  State<_FtButton> createState() => _FtButtonState();
}

class _FtButtonState extends State<_FtButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: FtMotion.fast,
          curve: FtMotion.standardCurve,
          transform: Matrix4.translationValues(0, _hovered ? -1 : 0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isPrimary
                ? (_hovered ? FtColors.accentHover : FtColors.accent)
                : (_hovered ? FtColors.bgAlt : FtColors.bg),
            borderRadius: FtRadii.mdAll,
            border: widget.isPrimary
                ? null
                : Border.all(color: FtColors.border, width: 1.5),
            boxShadow: widget.isPrimary ? FtShadows.amber : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon,
                    size: 16,
                    color: widget.isPrimary ? Colors.white : FtColors.primary),
                const SizedBox(width: 6),
              ],
              Text(
                widget.label,
                style: FtText.button.copyWith(
                  color: widget.isPrimary ? Colors.white : FtColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
