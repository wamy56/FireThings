import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/dispatched_job.dart';
import '../../models/company_member.dart';
import '../../services/dispatch_service.dart';
import '../../services/company_service.dart';
import '../../services/user_profile_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import '../../services/analytics_service.dart';
import 'web_job_detail_panel.dart';
import 'package:go_router/go_router.dart';

/// Engineer colour palette for calendar blocks.
const _engineerColors = [
  Colors.blue,
  Colors.teal,
  Colors.orange,
  Colors.purple,
  Colors.indigo,
  Colors.pink,
  Colors.cyan,
  Colors.amber,
  Colors.green,
  Colors.deepOrange,
];

class WebScheduleScreen extends StatefulWidget {
  const WebScheduleScreen({super.key});

  @override
  State<WebScheduleScreen> createState() => _WebScheduleScreenState();
}

class _WebScheduleScreenState extends State<WebScheduleScreen> {
  late DateTime _weekStart;
  String? _selectedJobId;
  List<CompanyMember> _members = [];
  bool _colorByEngineer = true;
  bool _isMonthView = false;
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  String? get _companyId => UserProfileService.instance.companyId;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekStart = _startOfWeek(now);
    _focusedDay = now;
    _selectedDay = now;
    _loadMembers();
    AnalyticsService.instance.logWebScheduleViewed();
  }

  DateTime _startOfWeek(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - 1)); // Monday
  }

  Future<void> _loadMembers() async {
    final companyId = _companyId;
    if (companyId == null) return;
    try {
      final members = await CompanyService.instance.getCompanyMembers(companyId);
      if (mounted) setState(() => _members = members);
    } catch (_) {}
  }

  void _previousWeek() => setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));
  void _nextWeek() => setState(() => _weekStart = _weekStart.add(const Duration(days: 7)));
  void _previousMonth() => setState(() => _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1));
  void _nextMonth() => setState(() => _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1));

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _weekStart = _startOfWeek(now);
      _focusedDay = now;
      _selectedDay = now;
    });
  }

  Color _engineerColor(String? engineerId) {
    if (engineerId == null) return Colors.grey;
    final idx = _members.indexWhere((m) => m.uid == engineerId);
    if (idx < 0) return Colors.grey;
    return _engineerColors[idx % _engineerColors.length];
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

  Color _jobColor(DispatchedJob job) {
    return _colorByEngineer ? _engineerColor(job.assignedTo) : _statusColor(job.status);
  }

  Map<int, List<DispatchedJob>> _groupJobsByWeekDay(List<DispatchedJob> allJobs) {
    final weekEnd = _weekStart.add(const Duration(days: 7));
    final Map<int, List<DispatchedJob>> jobsByDay = {for (var i = 0; i < 7; i++) i: []};
    for (final job in allJobs) {
      if (job.scheduledDate == null) continue;
      final d = job.scheduledDate!;
      if (d.isBefore(_weekStart) || !d.isBefore(weekEnd)) continue;
      jobsByDay[d.weekday - 1]!.add(job);
    }
    return jobsByDay;
  }

  List<DispatchedJob> _getJobsForDay(DateTime day, List<DispatchedJob> allJobs) {
    return allJobs.where((job) =>
      job.scheduledDate != null && isSameDay(job.scheduledDate!, day)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final companyId = _companyId;

    if (companyId == null) {
      return const Center(child: Text('No company found'));
    }

    return StreamBuilder<List<DispatchedJob>>(
      stream: DispatchService.instance.getJobsStream(companyId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: AdaptiveLoadingIndicator());
        }

        final allJobs = snapshot.data ?? [];
        final unscheduled = allJobs.where((j) => j.scheduledDate == null).toList();

        return Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(isDark),
                Expanded(
                  child: _isMonthView
                      ? _buildMonthView(allJobs, isDark)
                      : _buildWeekGrid(_groupJobsByWeekDay(allJobs), isDark),
                ),
                if (_isMonthView)
                  _buildSelectedDayJobs(
                    _getJobsForDay(_selectedDay, allJobs),
                    isDark,
                  ),
                if (unscheduled.isNotEmpty)
                  _buildUnscheduledSection(unscheduled, isDark),
              ],
            ),
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
    );
  }

  // ─── HEADER ──────────────────────────────────────────────────

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Row(
        children: [
          Text(
            'Schedule',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          // View toggle
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: false, label: const Text('Week'), icon: Icon(AppIcons.calendar, size: 16)),
              ButtonSegment(value: true, label: const Text('Month'), icon: Icon(AppIcons.grid, size: 16)),
            ],
            selected: {_isMonthView},
            onSelectionChanged: (v) => setState(() => _isMonthView = v.first),
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStatePropertyAll(
                TextStyle(fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Colour toggle
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: true, label: Text('By Engineer')),
              ButtonSegment(value: false, label: Text('By Status')),
            ],
            selected: {_colorByEngineer},
            onSelectionChanged: (v) => setState(() => _colorByEngineer = v.first),
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStatePropertyAll(
                TextStyle(fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Navigation
          _isMonthView ? _buildMonthNav(isDark) : _buildWeekNav(isDark),
        ],
      ),
    );
  }

  Widget _buildWeekNav(bool isDark) {
    final weekEnd = _weekStart.add(const Duration(days: 6));
    final fmt = DateFormat('MMM d');
    final today = DateTime.now();
    final isCurrentWeek = !_weekStart.isAfter(today) && !weekEnd.isBefore(today);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: _previousWeek,
          icon: Icon(AppIcons.arrowLeft, size: 18),
          tooltip: 'Previous week',
        ),
        TextButton(
          onPressed: () => _showDatePickerDialog(isDark),
          child: Text(
            '${fmt.format(_weekStart)} – ${fmt.format(weekEnd)}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.darkGrey,
            ),
          ),
        ),
        IconButton(
          onPressed: _nextWeek,
          icon: Icon(AppIcons.arrowRight, size: 18),
          tooltip: 'Next week',
        ),
        if (!isCurrentWeek) ...[
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: _goToToday,
            child: const Text('Today'),
          ),
        ],
      ],
    );
  }

  Widget _buildMonthNav(bool isDark) {
    final fmt = DateFormat('MMMM yyyy');
    final today = DateTime.now();
    final isCurrentMonth = _focusedDay.year == today.year && _focusedDay.month == today.month;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: _previousMonth,
          icon: Icon(AppIcons.arrowLeft, size: 18),
          tooltip: 'Previous month',
        ),
        TextButton(
          onPressed: () => _showDatePickerDialog(isDark),
          child: Text(
            fmt.format(_focusedDay),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.darkGrey,
            ),
          ),
        ),
        IconButton(
          onPressed: _nextMonth,
          icon: Icon(AppIcons.arrowRight, size: 18),
          tooltip: 'Next month',
        ),
        if (!isCurrentMonth) ...[
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: _goToToday,
            child: const Text('Today'),
          ),
        ],
      ],
    );
  }

  // ─── MINI CALENDAR DIALOG ────────────────────────────────────

  void _showDatePickerDialog(bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) {
        DateTime tempFocused = _focusedDay;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => Dialog(
            alignment: Alignment.topCenter,
            insetPadding: const EdgeInsets.only(top: 70, left: 16, right: 16),
            child: Container(
              width: 350,
              padding: const EdgeInsets.all(16),
              child: TableCalendar(
                firstDay: DateTime(2020, 1, 1),
                lastDay: DateTime(2030, 12, 31),
                focusedDay: tempFocused,
                selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
                calendarFormat: CalendarFormat.month,
                startingDayOfWeek: StartingDayOfWeek.monday,
                availableCalendarFormats: const {CalendarFormat.month: 'Month'},
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: isDark ? Colors.white : AppTheme.darkGrey,
                  ),
                  leftChevronIcon: Icon(AppIcons.arrowLeft, size: 16),
                  rightChevronIcon: Icon(AppIcons.arrowRight, size: 16),
                ),
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: (isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: TextStyle(
                    color: isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue,
                    fontWeight: FontWeight.bold,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: AppTheme.accentOrange,
                    shape: BoxShape.circle,
                  ),
                  selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                onDaySelected: (selected, focused) {
                  setState(() {
                    _selectedDay = selected;
                    _focusedDay = focused;
                    _weekStart = _startOfWeek(selected);
                  });
                  Navigator.pop(ctx);
                },
                onPageChanged: (focused) {
                  setDialogState(() => tempFocused = focused);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── MONTH VIEW ──────────────────────────────────────────────

  Widget _buildMonthView(List<DispatchedJob> allJobs, bool isDark) {
    return TableCalendar<DispatchedJob>(
      firstDay: DateTime(2020, 1, 1),
      lastDay: DateTime(2030, 12, 31),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
      calendarFormat: CalendarFormat.month,
      startingDayOfWeek: StartingDayOfWeek.monday,
      availableCalendarFormats: const {CalendarFormat.month: 'Month'},
      headerVisible: false,
      eventLoader: (day) => _getJobsForDay(day, allJobs),
      onDaySelected: (selected, focused) {
        setState(() {
          _selectedDay = selected;
          _focusedDay = focused;
          _weekStart = _startOfWeek(selected);
        });
      },
      onPageChanged: (focused) => setState(() => _focusedDay = focused),
      rowHeight: 90,
      daysOfWeekHeight: 32,
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
        ),
        weekendStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
        ),
      ),
      calendarStyle: CalendarStyle(
        outsideDaysVisible: true,
        outsideTextStyle: TextStyle(
          color: (isDark ? Colors.white : AppTheme.darkGrey).withValues(alpha: 0.3),
        ),
        cellMargin: const EdgeInsets.all(2),
        cellPadding: EdgeInsets.zero,
        todayDecoration: const BoxDecoration(),
        selectedDecoration: const BoxDecoration(),
        defaultDecoration: const BoxDecoration(),
        weekendDecoration: const BoxDecoration(),
        outsideDecoration: const BoxDecoration(),
        markerDecoration: const BoxDecoration(),
        markersMaxCount: 0,
      ),
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (ctx, day, focused) => _buildMonthDayCell(day, allJobs, isDark, isToday: false, isSelected: false, isOutside: false),
        todayBuilder: (ctx, day, focused) => _buildMonthDayCell(day, allJobs, isDark, isToday: true, isSelected: isSameDay(day, _selectedDay), isOutside: false),
        selectedBuilder: (ctx, day, focused) => _buildMonthDayCell(day, allJobs, isDark, isToday: isSameDay(day, DateTime.now()), isSelected: true, isOutside: false),
        outsideBuilder: (ctx, day, focused) => _buildMonthDayCell(day, allJobs, isDark, isToday: false, isSelected: false, isOutside: true),
      ),
    );
  }

  Widget _buildMonthDayCell(DateTime day, List<DispatchedJob> allJobs, bool isDark, {
    required bool isToday,
    required bool isSelected,
    required bool isOutside,
  }) {
    final jobs = _getJobsForDay(day, allJobs);
    final textOpacity = isOutside ? 0.3 : 1.0;

    return Container(
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark ? AppTheme.accentOrange.withValues(alpha: 0.15) : AppTheme.accentOrange.withValues(alpha: 0.08))
            : isToday
                ? (isDark ? AppTheme.darkPrimaryBlue.withValues(alpha: 0.08) : AppTheme.primaryBlue.withValues(alpha: 0.04))
                : null,
        borderRadius: BorderRadius.circular(6),
        border: isSelected
            ? Border.all(color: AppTheme.accentOrange, width: 1.5)
            : Border.all(color: isDark ? AppTheme.darkDivider : AppTheme.dividerColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day number + job count
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: isToday
                      ? BoxDecoration(
                          color: isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue,
                          shape: BoxShape.circle,
                        )
                      : null,
                  alignment: Alignment.center,
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                      color: isToday
                          ? Colors.white
                          : (isDark ? Colors.white : AppTheme.darkGrey).withValues(alpha: textOpacity),
                    ),
                  ),
                ),
                const Spacer(),
                if (jobs.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: (isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${jobs.length}',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Job dots / pills
          if (jobs.isNotEmpty)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: jobs.take(3).map((job) {
                    final color = _jobColor(job);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 1),
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: isOutside ? 0.08 : 0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        job.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: color.withValues(alpha: isOutside ? 0.4 : 0.9),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            )
          else
            const Spacer(),
        ],
      ),
    );
  }

  // ─── SELECTED DAY JOBS (MONTH VIEW) ─────────────────────────

  Widget _buildSelectedDayJobs(List<DispatchedJob> dayJobs, bool isDark) {
    final fmt = DateFormat('EEEE, MMM d');

    return Container(
      constraints: const BoxConstraints(maxHeight: 160),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: isDark ? AppTheme.darkDivider : AppTheme.dividerColor),
        ),
        color: isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
            child: Row(
              children: [
                Text(
                  '${fmt.format(_selectedDay)} (${dayJobs.length} ${dayJobs.length == 1 ? 'job' : 'jobs'})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _weekStart = _startOfWeek(_selectedDay);
                      _isMonthView = false;
                    });
                  },
                  icon: Icon(AppIcons.arrowRight, size: 14),
                  label: const Text('View Week', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          Expanded(
            child: dayJobs.isEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                    child: Text(
                      'No jobs scheduled for this day',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
                      ),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                    itemCount: dayJobs.length,
                    itemBuilder: (context, index) => SizedBox(
                      width: 180,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildJobBlock(dayJobs[index], isDark),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ─── WEEK VIEW (unchanged) ───────────────────────────────────

  Widget _buildWeekGrid(Map<int, List<DispatchedJob>> jobsByDay, bool isDark) {
    final today = DateTime.now();
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(7, (dayIndex) {
        final date = _weekStart.add(Duration(days: dayIndex));
        final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
        final jobs = jobsByDay[dayIndex] ?? [];

        return Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: dayIndex > 0
                    ? BorderSide(color: isDark ? AppTheme.darkDivider : AppTheme.dividerColor)
                    : BorderSide.none,
              ),
              color: isToday
                  ? (isDark ? AppTheme.darkPrimaryBlue.withValues(alpha: 0.08) : AppTheme.primaryBlue.withValues(alpha: 0.04))
                  : null,
            ),
            child: Column(
              children: [
                // Day header
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: isDark ? AppTheme.darkDivider : AppTheme.dividerColor),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        dayNames[dayIndex],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isToday
                              ? (isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue)
                              : (isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: isToday
                            ? BoxDecoration(
                                color: isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue,
                                shape: BoxShape.circle,
                              )
                            : null,
                        alignment: Alignment.center,
                        child: Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                            color: isToday
                                ? Colors.white
                                : (isDark ? Colors.white : AppTheme.darkGrey),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Jobs list
                Expanded(
                  child: jobs.isEmpty
                      ? const SizedBox.shrink()
                      : ListView.builder(
                          padding: const EdgeInsets.all(4),
                          itemCount: jobs.length,
                          itemBuilder: (context, index) => _buildJobBlock(jobs[index], isDark),
                        ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ─── JOB BLOCK ───────────────────────────────────────────────

  Widget _buildJobBlock(DispatchedJob job, bool isDark) {
    final color = _jobColor(job);
    final isSelected = _selectedJobId == job.id;

    return GestureDetector(
      onTap: () => setState(() => _selectedJobId = job.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isSelected ? 0.3 : 0.15),
          borderRadius: BorderRadius.circular(6),
          border: isSelected
              ? Border.all(color: color, width: 2)
              : Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              job.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppTheme.darkGrey,
              ),
            ),
            if (job.assignedToName != null)
              Text(
                job.assignedToName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
                ),
              ),
            if (job.scheduledTime != null)
              Text(
                job.scheduledTime!,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            // Status label (small)
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: _statusColor(job.status).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _statusLabel(job.status),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: _statusColor(job.status),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── UNSCHEDULED SECTION ─────────────────────────────────────

  Widget _buildUnscheduledSection(List<DispatchedJob> jobs, bool isDark) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 120),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: isDark ? AppTheme.darkDivider : AppTheme.dividerColor),
        ),
        color: isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
            child: Text(
              'Unscheduled (${jobs.length})',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              itemCount: jobs.length,
              itemBuilder: (context, index) {
                final job = jobs[index];
                final color = _jobColor(job);
                final isSelected = _selectedJobId == job.id;

                return GestureDetector(
                  onTap: () => setState(() => _selectedJobId = job.id),
                  child: Container(
                    width: 160,
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: isSelected ? 0.3 : 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? Border.all(color: color, width: 2)
                          : Border.all(color: color.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          job.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : AppTheme.darkGrey,
                          ),
                        ),
                        if (job.assignedToName != null)
                          Text(
                            job.assignedToName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
