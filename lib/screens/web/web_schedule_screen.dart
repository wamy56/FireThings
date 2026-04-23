import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/company_member.dart';
import '../../models/dispatched_job.dart';
import '../../services/company_service.dart';
import '../../services/dispatch_service.dart';
import '../../services/user_profile_service.dart';
import '../../theme/web_theme.dart';
import '../../utils/icon_map.dart';
import '../../widgets/premium_toast.dart';
import 'package:go_router/go_router.dart';
import 'web_job_detail_panel.dart';
import 'widgets/schedule/schedule_day_grid.dart';
import 'widgets/schedule/schedule_week_grid.dart';

class WebScheduleScreen extends StatefulWidget {
  const WebScheduleScreen({super.key});

  @override
  State<WebScheduleScreen> createState() => _WebScheduleScreenState();
}

class _WebScheduleScreenState extends State<WebScheduleScreen>
    with SingleTickerProviderStateMixin {
  late DateTime _weekStart;
  late DateTime _selectedDay;
  int _activeViewIndex = 1;

  List<CompanyMember> _members = [];
  List<DispatchedJob> _jobs = [];
  bool _loading = true;

  StreamSubscription<List<DispatchedJob>>? _jobsSub;
  StreamSubscription<List<CompanyMember>>? _membersSub;

  String? _selectedJobId;
  bool _panelVisible = false;
  bool _panelAnimateIn = true;
  late final AnimationController _overlayController;
  late final Animation<double> _overlayOpacity;

  final Set<JobPriority> _activePriorities = {
    JobPriority.emergency,
    JobPriority.urgent,
    JobPriority.normal,
  };
  bool _showCompleted = false;
  String _engineerFilter = 'all';

  static const _palette = [
    Color(0xFFDC2626),
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFF059669),
    Color(0xFFD97706),
    Color(0xFFDB2777),
    Color(0xFF0891B2),
    Color(0xFF4F46E5),
  ];

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
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
    _weekStart = _selectedDay.subtract(Duration(days: now.weekday - 1));
    _loadData();
  }

  @override
  void dispose() {
    _overlayController.dispose();
    _jobsSub?.cancel();
    _membersSub?.cancel();
    super.dispose();
  }

  void _selectJob(String jobId) {
    final wasAlreadyOpen = _panelVisible;
    setState(() {
      _selectedJobId = jobId;
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
        _selectedJobId = null;
      });
    }
  }

  void _handleJobDrop(DispatchedJob job, DateTime newDate, String? engineerId, String? engineerName) async {
    final companyId = UserProfileService.instance.companyId;
    if (companyId == null) return;

    final isSameDate = job.scheduledDate != null &&
        job.scheduledDate!.year == newDate.year &&
        job.scheduledDate!.month == newDate.month &&
        job.scheduledDate!.day == newDate.day;
    final isSameEngineer = job.assignedTo == engineerId;

    if (isSameDate && isSameEngineer) return;

    if (!isSameEngineer && job.status == DispatchedJobStatus.onSite) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: FtRadii.lgAll),
          title: Text(
            'Reassign active job?',
            style: FtText.inter(size: 16, weight: FontWeight.w700, color: FtColors.fg1),
          ),
          content: Text(
            '${job.assignedToName ?? 'The engineer'} is currently on site for this job. Reassigning will change their active assignment.',
            style: FtText.inter(size: 14, weight: FontWeight.w500, color: FtColors.fg2),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel', style: FtText.inter(size: 14, weight: FontWeight.w600, color: FtColors.fg2)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Reassign', style: FtText.inter(size: 14, weight: FontWeight.w600, color: FtColors.warning)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    if (job.status == DispatchedJobStatus.completed && mounted) {
      context.showWarningToast('Moved a completed job');
    }

    final snapshot = List<DispatchedJob>.from(_jobs);

    if (isSameEngineer) {
      setState(() {
        final idx = _jobs.indexWhere((j) => j.id == job.id);
        if (idx != -1) _jobs[idx] = _jobs[idx].copyWith(scheduledDate: newDate);
      });
      try {
        await DispatchService.instance.updateScheduledDate(
          companyId: companyId, jobId: job.id, newDate: newDate,
        );
      } catch (e) {
        if (mounted) {
          setState(() => _jobs = snapshot);
          context.showErrorToast('Failed to reschedule job');
        }
      }
    } else if (engineerId == null) {
      setState(() => _jobs.removeWhere((j) => j.id == job.id));
      try {
        await DispatchService.instance.unassignJob(companyId: companyId, jobId: job.id);
        if (!isSameDate) {
          await DispatchService.instance.updateScheduledDate(
            companyId: companyId, jobId: job.id, newDate: newDate,
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _jobs = snapshot);
          context.showErrorToast('Failed to unassign job');
        }
      }
    } else {
      setState(() {
        final idx = _jobs.indexWhere((j) => j.id == job.id);
        if (idx != -1) {
          _jobs[idx] = _jobs[idx].copyWith(
            scheduledDate: newDate,
            assignedTo: engineerId,
            assignedToName: engineerName,
            status: DispatchedJobStatus.assigned,
          );
        }
      });
      try {
        await DispatchService.instance.rescheduleAndReassign(
          companyId: companyId,
          jobId: job.id,
          newDate: newDate,
          newAssignedTo: engineerId,
          newAssignedToName: engineerName!,
        );
      } catch (e) {
        if (mounted) {
          setState(() => _jobs = snapshot);
          context.showErrorToast('Failed to reassign job');
        }
      }
    }
  }

  void _loadData() {
    final companyId = UserProfileService.instance.companyId;
    if (companyId == null) return;

    _membersSub?.cancel();
    _membersSub = CompanyService.instance
        .getCompanyMembersStream(companyId)
        .listen((members) {
      setState(() => _members = members);
    });

    _subscribeToJobs(companyId);
  }

  void _subscribeToJobs(String companyId) {
    _jobsSub?.cancel();
    late final DateTime from;
    late final DateTime to;

    if (_activeViewIndex == 0) {
      from = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
      to = from.add(const Duration(hours: 23, minutes: 59, seconds: 59));
    } else {
      from = _weekStart;
      to = _weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    }

    _jobsSub = DispatchService.instance
        .watchJobsForDateRange(companyId: companyId, from: from, to: to)
        .listen((jobs) {
      setState(() {
        _jobs = jobs;
        _loading = false;
      });
    });
  }

  void _goToPrevious() {
    setState(() {
      if (_activeViewIndex == 0) {
        _selectedDay = _selectedDay.subtract(const Duration(days: 1));
      } else {
        _weekStart = _weekStart.subtract(const Duration(days: 7));
      }
      _loading = true;
    });
    _subscribeToJobs(UserProfileService.instance.companyId!);
  }

  void _goToNext() {
    setState(() {
      if (_activeViewIndex == 0) {
        _selectedDay = _selectedDay.add(const Duration(days: 1));
      } else {
        _weekStart = _weekStart.add(const Duration(days: 7));
      }
      _loading = true;
    });
    _subscribeToJobs(UserProfileService.instance.companyId!);
  }

  void _goToToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_activeViewIndex == 0) {
      if (today == _selectedDay) return;
      setState(() { _selectedDay = today; _loading = true; });
    } else {
      final monday = today.subtract(Duration(days: now.weekday - 1));
      if (monday == _weekStart) return;
      setState(() { _weekStart = monday; _loading = true; });
    }
    _subscribeToJobs(UserProfileService.instance.companyId!);
  }

  void _onViewChanged(int newIndex) {
    if (newIndex == _activeViewIndex) return;
    final oldIndex = _activeViewIndex;
    setState(() {
      _activeViewIndex = newIndex;
      if (newIndex == 0 && oldIndex == 1) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final weekEnd = _weekStart.add(const Duration(days: 6));
        _selectedDay = (!today.isBefore(_weekStart) && !today.isAfter(weekEnd))
            ? today
            : _weekStart;
      } else if (newIndex == 1 && oldIndex == 0) {
        _weekStart = _selectedDay.subtract(Duration(days: _selectedDay.weekday - 1));
      }
      _loading = true;
    });
    _subscribeToJobs(UserProfileService.instance.companyId!);
  }

  List<DispatchedJob> get _filteredJobs {
    return _jobs.where((job) {
      if (!_activePriorities.contains(job.priority)) return false;
      if (!_showCompleted && job.status == DispatchedJobStatus.completed) return false;
      return true;
    }).toList();
  }

  List<CompanyMember> get _filteredMembers {
    if (_engineerFilter == 'available') {
      return _members.where((m) => m.isActive).toList();
    }
    return _members;
  }

  List<ScheduleEngineer> get _engineers {
    final members = _filteredMembers;
    return members.map((m) {
      final engineerJobs = _filteredJobs.where((j) => j.assignedTo == m.uid).toList();
      final hasOnSiteJob = engineerJobs.any((j) =>
          j.status == DispatchedJobStatus.onSite ||
          j.status == DispatchedJobStatus.enRoute);
      return ScheduleEngineer(
        id: m.uid,
        name: m.displayName,
        initials: _initials(m.displayName),
        color: _palette[members.indexOf(m) % _palette.length],
        presence: !m.isActive ? 'offline' : hasOnSiteJob ? 'onsite' : 'online',
        isActive: m.isActive,
        weekJobCount: engineerJobs.length,
        offlineLabel: !m.isActive ? 'Offline' : null,
      );
    }).toList();
  }

  Map<String?, List<DispatchedJob>> get _jobsByEngineer {
    final map = <String?, List<DispatchedJob>>{};
    for (final job in _filteredJobs) {
      map.putIfAbsent(job.assignedTo, () => []).add(job);
    }
    return map;
  }

  ScheduleEngineer? get _unassignedRow {
    final unassignedJobs = _filteredJobs.where((j) => j.assignedTo == null).toList();
    if (unassignedJobs.isEmpty) return null;
    return ScheduleEngineer(
      id: '_unassigned',
      name: 'Unassigned',
      initials: '!',
      color: Colors.transparent,
      weekJobCount: unassignedJobs.length,
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.first.substring(0, parts.first.length.clamp(0, 2)).toUpperCase();
  }

  int _isoWeekNumber(DateTime date) {
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays;
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  @override
  Widget build(BuildContext context) {
    final weekEnd = _weekStart.add(const Duration(days: 6));
    final filtered = _filteredJobs;
    final scheduled = filtered.where((j) => j.assignedTo != null).length;
    final unassigned = filtered.where((j) => j.assignedTo == null).length;
    final weekNum = _isoWeekNumber(_weekStart);
    final activeEngineers = _members.where((m) => m.isActive).length;
    final capacityPct = activeEngineers > 0
        ? (filtered.length / (activeEngineers * 12) * 100).round()
        : 0;

    final companyId = UserProfileService.instance.companyId;
    final isDay = _activeViewIndex == 0;
    final title = isDay
        ? DateFormat('EEEE d MMMM').format(_selectedDay)
        : '${DateFormat('d').format(_weekStart)} — ${DateFormat('d MMMM').format(weekEnd)}';
    final subtitle = isDay
        ? '$scheduled jobs scheduled · $unassigned unassigned'
        : 'Week $weekNum · $scheduled jobs scheduled · $unassigned unassigned';

    return Stack(
      children: [
        Column(
          children: [
            _SubHeader(
              title: title,
              subtitle: subtitle,
              prevTooltip: isDay ? 'Previous day' : 'Previous week',
              nextTooltip: isDay ? 'Next day' : 'Next week',
              activeViewIndex: _activeViewIndex,
              onViewChanged: _onViewChanged,
              onPrevious: _goToPrevious,
              onNext: _goToNext,
              onToday: _goToToday,
            ),
            _FilterStrip(
              activePriorities: _activePriorities,
              showCompleted: _showCompleted,
              engineerFilter: _engineerFilter,
              onTogglePriority: (p) => setState(() {
                _activePriorities.contains(p)
                    ? _activePriorities.remove(p)
                    : _activePriorities.add(p);
              }),
              onToggleCompleted: () => setState(() => _showCompleted = !_showCompleted),
              onEngineerFilterChanged: (f) => setState(() => _engineerFilter = f),
              bookedCount: scheduled,
              unassignedCount: unassigned,
              capacityPercent: capacityPct,
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: FtColors.accent))
                  : _members.isEmpty
                      ? Center(
                          child: Text(
                            'No team members found',
                            style: FtText.inter(size: 14, weight: FontWeight.w500, color: FtColors.hint),
                          ),
                        )
                      : Stack(
                          children: [
                            if (_activeViewIndex == 0)
                              ScheduleDayGrid(
                                engineers: _engineers,
                                unassignedRow: _unassignedRow,
                                jobsByEngineer: _jobsByEngineer,
                                selectedDay: _selectedDay,
                                onJobTap: (job) => _selectJob(job.id),
                                onJobDrop: _handleJobDrop,
                              )
                            else
                              ScheduleWeekGrid(
                                engineers: _engineers,
                                unassignedRow: _unassignedRow,
                                jobsByEngineer: _jobsByEngineer,
                                weekStart: _weekStart,
                                onJobTap: (job) => _selectJob(job.id),
                                onJobDrop: _handleJobDrop,
                              ),
                            if (filtered.isEmpty && _members.isNotEmpty)
                              _EmptyStateOverlay(viewLabel: isDay ? 'day' : 'week'),
                          ],
                        ),
            ),
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
        if (_panelVisible && _selectedJobId != null && companyId != null)
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
              onEdit: (job) => context.push('/jobs/create', extra: job),
            ),
          ),
      ],
    );
  }
}

class _SubHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String prevTooltip;
  final String nextTooltip;
  final int activeViewIndex;
  final ValueChanged<int> onViewChanged;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  const _SubHeader({
    required this.title,
    required this.subtitle,
    required this.prevTooltip,
    required this.nextTooltip,
    required this.activeViewIndex,
    required this.onViewChanged,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: const BoxDecoration(
        color: FtColors.bg,
        border: Border(bottom: BorderSide(color: FtColors.border, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: FtText.outfit(
                    size: 24, weight: FontWeight.w800,
                    letterSpacing: -0.6, color: FtColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: FtText.inter(size: 13, weight: FontWeight.w500, color: FtColors.fg2),
                ),
              ],
            ),
          ),

          _NavArrow(icon: AppIcons.arrowLeft, tooltip: prevTooltip, onTap: onPrevious),
          const SizedBox(width: 8),
          _NavButton(label: 'Today', onTap: onToday),
          const SizedBox(width: 8),
          _NavArrow(icon: AppIcons.arrowRight, tooltip: nextTooltip, onTap: onNext),

          const SizedBox(width: 16),

          _ViewSwitcher(
            labels: const ['Day', 'Week', 'Month'],
            activeIndex: activeViewIndex,
            onChanged: onViewChanged,
          ),

          const SizedBox(width: 8),
          _SecondaryButton(icon: AppIcons.printer, label: 'Print'),
          const SizedBox(width: 8),
          _PrimaryButton(icon: AppIcons.addCircle, label: 'New job'),
        ],
      ),
    );
  }
}

class _NavArrow extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _NavArrow({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: FtColors.bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: FtColors.border, width: 1.5),
            ),
            child: Icon(icon, size: 16, color: FtColors.fg2),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _NavButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: FtColors.bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: FtColors.border, width: 1.5),
          ),
          child: Text(
            label,
            style: FtText.inter(size: 13, weight: FontWeight.w600, color: FtColors.fg1),
          ),
        ),
      ),
    );
  }
}

class _ViewSwitcher extends StatelessWidget {
  final List<String> labels;
  final int activeIndex;
  final ValueChanged<int> onChanged;

  const _ViewSwitcher({
    required this.labels,
    required this.activeIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: FtColors.bgAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < labels.length; i++)
            GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: FtMotion.fast,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: i == activeIndex ? FtColors.bg : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: i == activeIndex
                      ? const [BoxShadow(color: Color(0x0D000000), offset: Offset(0, 1), blurRadius: 2)]
                      : null,
                ),
                child: Text(
                  labels[i],
                  style: FtText.inter(
                    size: 13, weight: FontWeight.w600,
                    color: i == activeIndex ? FtColors.primary : FtColors.fg2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SecondaryButton({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: FtColors.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FtColors.border, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: FtColors.primary),
          const SizedBox(width: 7),
          Text(label, style: FtText.inter(size: 13, weight: FontWeight.w600, color: FtColors.primary)),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PrimaryButton({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: FtColors.accent,
        borderRadius: BorderRadius.circular(10),
        boxShadow: FtShadows.amber,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 7),
          Text(label, style: FtText.inter(size: 13, weight: FontWeight.w600, color: Colors.white)),
        ],
      ),
    );
  }
}

class _FilterStrip extends StatelessWidget {
  final Set<JobPriority> activePriorities;
  final bool showCompleted;
  final String engineerFilter;
  final ValueChanged<JobPriority> onTogglePriority;
  final VoidCallback onToggleCompleted;
  final ValueChanged<String> onEngineerFilterChanged;
  final int bookedCount;
  final int unassignedCount;
  final int capacityPercent;

  const _FilterStrip({
    required this.activePriorities,
    required this.showCompleted,
    required this.engineerFilter,
    required this.onTogglePriority,
    required this.onToggleCompleted,
    required this.onEngineerFilterChanged,
    required this.bookedCount,
    required this.unassignedCount,
    required this.capacityPercent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      decoration: const BoxDecoration(
        color: FtColors.bg,
        border: Border(bottom: BorderSide(color: FtColors.border, width: 1)),
      ),
      child: Row(
        children: [
          Text('VIEW', style: FtText.inter(size: 11, weight: FontWeight.w700, letterSpacing: 0.4, color: FtColors.hint)),
          const SizedBox(width: 12),
          _FilterChip(
            label: 'All engineers',
            active: engineerFilter == 'all',
            onTap: () => onEngineerFilterChanged('all'),
          ),
          const SizedBox(width: 6),
          _FilterChip(
            label: 'Available only',
            active: engineerFilter == 'available',
            onTap: () => onEngineerFilterChanged('available'),
          ),

          const SizedBox(width: 16),
          Text('SHOW', style: FtText.inter(size: 11, weight: FontWeight.w700, letterSpacing: 0.4, color: FtColors.hint)),
          const SizedBox(width: 12),
          _FilterChip(
            label: 'Emergency',
            active: activePriorities.contains(JobPriority.emergency),
            dotColor: FtColors.danger,
            onTap: () => onTogglePriority(JobPriority.emergency),
          ),
          const SizedBox(width: 6),
          _FilterChip(
            label: 'Urgent',
            active: activePriorities.contains(JobPriority.urgent),
            dotColor: FtColors.warning,
            onTap: () => onTogglePriority(JobPriority.urgent),
          ),
          const SizedBox(width: 6),
          _FilterChip(
            label: 'Normal',
            active: activePriorities.contains(JobPriority.normal),
            dotColor: FtColors.info,
            onTap: () => onTogglePriority(JobPriority.normal),
          ),
          const SizedBox(width: 6),
          _FilterChip(
            label: 'Completed',
            active: showCompleted,
            dotColor: FtColors.success,
            onTap: onToggleCompleted,
          ),

          const Spacer(),

          _StatItem(label: 'Booked:', value: '$bookedCount'),
          const SizedBox(width: 20),
          _StatItem(label: 'Unassigned:', value: '$unassignedCount', valueColor: unassignedCount > 0 ? FtColors.warning : null),
          const SizedBox(width: 20),
          _StatItem(label: 'Capacity:', value: '$capacityPercent%'),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color? dotColor;
  final VoidCallback? onTap;

  const _FilterChip({required this.label, this.active = false, this.dotColor, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: active ? FtColors.primary : FtColors.bgAlt,
            borderRadius: BorderRadius.circular(20),
            border: active ? null : Border.all(color: Colors.transparent, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: active ? dotColor!.withValues(alpha: 0.9) : dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: FtText.inter(
                  size: 12, weight: FontWeight.w600,
                  color: active ? Colors.white : FtColors.fg2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _StatItem({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: FtText.inter(size: 12, weight: FontWeight.w500, color: FtColors.fg2)),
        const SizedBox(width: 6),
        Text(value, style: FtText.mono(size: 12, weight: FontWeight.w600, color: valueColor ?? FtColors.fg1)),
      ],
    );
  }
}

class _EmptyStateOverlay extends StatelessWidget {
  final String viewLabel;
  const _EmptyStateOverlay({required this.viewLabel});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        decoration: BoxDecoration(
          color: FtColors.bg.withValues(alpha: 0.92),
          borderRadius: FtRadii.lgAll,
          border: Border.all(color: FtColors.border, width: 1.5),
          boxShadow: FtShadows.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.briefcaseTimer, size: 40, color: FtColors.hint),
            const SizedBox(height: 12),
            Text(
              'No jobs scheduled this $viewLabel',
              style: FtText.inter(size: 16, weight: FontWeight.w600, color: FtColors.fg2),
            ),
            const SizedBox(height: 6),
            Text(
              'Create a job or adjust your filters to see scheduled work.',
              style: FtText.inter(size: 13, weight: FontWeight.w500, color: FtColors.hint),
            ),
          ],
        ),
      ),
    );
  }
}
