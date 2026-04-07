import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/dispatched_job.dart';
import '../../models/company_member.dart';
import '../../services/dispatch_service.dart';
import '../../services/company_service.dart';
import '../../services/user_profile_service.dart';
import '../../utils/adaptive_widgets.dart';
import '../../utils/responsive.dart';
import '../../utils/theme.dart';
import '../../services/analytics_service.dart';
import '../../services/geocoding_service.dart';
import '../../widgets/job_map.dart';
import 'web_job_detail_panel.dart';
import 'package:go_router/go_router.dart';
import 'schedule/schedule_helpers.dart';
import 'schedule/schedule_header.dart';
import 'schedule/week_view.dart';
import 'schedule/month_view.dart';
import 'schedule/day_view.dart';
import 'schedule/route_builder.dart';
import 'schedule/route_controls.dart';
import 'schedule/unscheduled_strip.dart';

class WebScheduleScreen extends StatefulWidget {
  const WebScheduleScreen({super.key});

  @override
  State<WebScheduleScreen> createState() => _WebScheduleScreenState();
}

class _WebScheduleScreenState extends State<WebScheduleScreen>
    with SingleTickerProviderStateMixin {
  late DateTime _weekStart;
  String? _selectedJobId;
  bool _panelVisible = false;
  bool _panelAnimateIn = true;
  List<CompanyMember> _members = [];
  bool _colorByEngineer = true;
  ScheduleViewMode _viewMode = ScheduleViewMode.week;
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  /// For narrower screens: toggle between calendar and map tabs.
  bool _showMapTab = false;

  /// Route view state: selected engineer for route overlay.
  String? _routeEngineerId;

  /// Cache of geocoded coordinates keyed by job id.
  final Map<String, LatLng> _geocodedLocations = {};

  /// Job IDs currently being geocoded (to avoid duplicate requests).
  final Set<String> _geocodingInProgress = {};

  Stream<List<DispatchedJob>>? _jobsStream;

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
    final now = DateTime.now();
    _weekStart = _startOfWeek(now);
    _focusedDay = now;
    _selectedDay = now;
    _loadMembers();
    _initJobsStream();
    AnalyticsService.instance.logWebScheduleViewed();
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
    super.dispose();
  }

  DateTime _startOfWeek(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  Future<void> _loadMembers() async {
    final companyId = _companyId;
    if (companyId == null) return;
    try {
      final members =
          await CompanyService.instance.getCompanyMembers(companyId);
      if (mounted) setState(() => _members = members);
    } catch (_) {}
  }

  void _previousWeek() =>
      setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));
  void _nextWeek() =>
      setState(() => _weekStart = _weekStart.add(const Duration(days: 7)));
  void _previousMonth() => setState(
      () => _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1));
  void _nextMonth() => setState(
      () => _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1));

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _weekStart = _startOfWeek(now);
      _focusedDay = now;
      _selectedDay = now;
    });
  }

  void _onDatePicked(DateTime selected) {
    setState(() {
      _selectedDay = selected;
      _focusedDay = selected;
      _weekStart = _startOfWeek(selected);
    });
  }

  Color _jobColorFn(DispatchedJob job) =>
      jobColor(job, _colorByEngineer, _members);

  /// Handle a job being dropped on a new date (week view drag-and-drop).
  Future<void> _handleJobDrop(DispatchedJob job, DateTime newDate) async {
    final companyId = _companyId;
    if (companyId == null) return;

    // Store old values for undo
    final oldDate = job.scheduledDate;
    final oldTime = job.scheduledTime;

    try {
      await DispatchService.instance.rescheduleJob(
        companyId: companyId,
        jobId: job.id,
        newDate: newDate,
      );

      if (!mounted) return;

      final dateFmt = '${newDate.day}/${newDate.month}/${newDate.year}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Job rescheduled to $dateFmt'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              try {
                await DispatchService.instance.rescheduleJob(
                  companyId: companyId,
                  jobId: job.id,
                  newDate: oldDate,
                  newTime: oldTime ?? '',
                );
              } catch (_) {}
            },
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to reschedule job')),
        );
      }
    }
  }

  Map<int, List<DispatchedJob>> _groupJobsByWeekDay(
      List<DispatchedJob> allJobs) {
    final weekEnd = _weekStart.add(const Duration(days: 7));
    final Map<int, List<DispatchedJob>> jobsByDay = {
      for (var i = 0; i < 7; i++) i: []
    };
    for (final job in allJobs) {
      if (job.scheduledDate == null) continue;
      final d = job.scheduledDate!;
      if (d.isBefore(_weekStart) || !d.isBefore(weekEnd)) continue;
      jobsByDay[d.weekday - 1]!.add(job);
    }
    return jobsByDay;
  }

  /// Get jobs visible in the current view for the map.
  List<DispatchedJob> _getMapJobs(List<DispatchedJob> allJobs) {
    switch (_viewMode) {
      case ScheduleViewMode.week:
        final weekEnd = _weekStart.add(const Duration(days: 7));
        return allJobs.where((j) {
          if (j.scheduledDate == null) return false;
          return !j.scheduledDate!.isBefore(_weekStart) &&
              j.scheduledDate!.isBefore(weekEnd);
        }).toList();
      case ScheduleViewMode.month:
      case ScheduleViewMode.day:
        return allJobs
            .where((j) =>
                j.scheduledDate != null &&
                isSameDay(j.scheduledDate!, _selectedDay))
            .toList();
    }
  }

  /// Build map pins from a list of jobs, using geocoded fallback for jobs
  /// without stored coordinates.
  ({List<JobMapPin> pins, int missingCount}) _buildMapPins(
      List<DispatchedJob> jobs) {
    final pins = <JobMapPin>[];
    int missing = 0;
    final toGeocode = <DispatchedJob>[];

    for (final job in jobs) {
      LatLng? location;

      if (job.latitude != null && job.longitude != null) {
        location = LatLng(job.latitude!, job.longitude!);
      } else if (_geocodedLocations.containsKey(job.id)) {
        location = _geocodedLocations[job.id]!;
      } else if (job.siteAddress.trim().isNotEmpty) {
        toGeocode.add(job);
      }

      if (location != null) {
        pins.add(JobMapPin(
          jobId: job.id,
          location: location,
          color: _jobColorFn(job),
          title: job.title,
          engineerName: job.assignedToName,
          scheduledTime: job.scheduledTime,
          statusLabel: jobStatusLabel(job.status),
        ));
      } else {
        missing++;
      }
    }

    // Fire off geocoding for jobs that need it (non-blocking).
    if (toGeocode.isNotEmpty) {
      _geocodeJobs(toGeocode);
    }

    return (pins: pins, missingCount: missing);
  }

  /// Geocode a batch of jobs and update state when done.
  Future<void> _geocodeJobs(List<DispatchedJob> jobs) async {
    bool anyResolved = false;
    for (final job in jobs) {
      if (_geocodingInProgress.contains(job.id)) continue;
      _geocodingInProgress.add(job.id);

      final result =
          await GeocodingService.instance.geocode(job.siteAddress);
      _geocodingInProgress.remove(job.id);

      if (result != null) {
        _geocodedLocations[job.id] = LatLng(result.lat, result.lng);
        anyResolved = true;
      }
    }
    if (anyResolved && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final companyId = _companyId;
    final screenSize = context.screenSize;
    final isLargeScreen = screenSize == ScreenSize.large;

    if (companyId == null) {
      return const Center(child: Text('No company found'));
    }

    return StreamBuilder<List<DispatchedJob>>(
      stream: _jobsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: AdaptiveLoadingIndicator());
        }

        final allJobs = snapshot.data ?? [];
        final unscheduled =
            allJobs.where((j) => j.scheduledDate == null).toList();
        final mapJobs = _getMapJobs(allJobs);
        final mapData = _buildMapPins(mapJobs);

        return Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderWithMapToggle(isDark, isLargeScreen),
                Expanded(
                  child: isLargeScreen
                      ? _buildSplitLayout(allJobs, mapData, isDark)
                      : _showMapTab
                          ? _buildMapWithRouteControls(allJobs, mapData, isDark)
                          : _buildCalendarView(allJobs, isDark),
                ),
                UnscheduledStrip(
                  jobs: unscheduled,
                  isDark: isDark,
                  selectedJobId: _selectedJobId,
                  jobColorFn: _jobColorFn,
                  onJobTap: _selectJob,
                ),
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
    );
  }

  Widget _buildHeaderWithMapToggle(bool isDark, bool isLargeScreen) {
    return ScheduleHeader(
      viewMode: _viewMode,
      onViewModeChanged: (v) => setState(() => _viewMode = v),
      colorByEngineer: _colorByEngineer,
      onColorModeChanged: (v) => setState(() => _colorByEngineer = v),
      weekStart: _weekStart,
      focusedDay: _focusedDay,
      selectedDay: _selectedDay,
      isDark: isDark,
      onPreviousWeek: _previousWeek,
      onNextWeek: _nextWeek,
      onPreviousMonth: _previousMonth,
      onNextMonth: _nextMonth,
      onGoToToday: _goToToday,
      onDatePicked: _onDatePicked,
      showMapToggle: !isLargeScreen,
      showMapTab: _showMapTab,
      onMapToggle: (v) => setState(() => _showMapTab = v),
    );
  }

  /// Large screens: calendar on left, map on right.
  /// Build map pins with route modifications when an engineer is selected.
  ({List<JobMapPin> pins, List<LatLng>? routePoints, int missingCount})
      _buildMapDataWithRoute(
    List<DispatchedJob> allJobs,
    ({List<JobMapPin> pins, int missingCount}) baseData,
  ) {
    if (_routeEngineerId == null) {
      return (
        pins: baseData.pins,
        routePoints: null,
        missingCount: baseData.missingCount,
      );
    }

    // Find engineer name
    final engineer = _members.where((m) => m.uid == _routeEngineerId).firstOrNull;
    if (engineer == null) {
      return (
        pins: baseData.pins,
        routePoints: null,
        missingCount: baseData.missingCount,
      );
    }

    final route = buildEngineerRoute(
      engineerId: _routeEngineerId!,
      engineerName: engineer.displayName,
      date: _selectedDay,
      allJobs: allJobs,
    );

    if (route == null || route.orderedJobs.isEmpty) {
      return (
        pins: baseData.pins,
        routePoints: null,
        missingCount: baseData.missingCount,
      );
    }

    // Rebuild pins: number route jobs, fade others
    final routeJobIds = route.orderedJobs.map((j) => j.id).toSet();
    final pins = <JobMapPin>[];
    int seq = 1;
    for (final pin in baseData.pins) {
      if (routeJobIds.contains(pin.jobId)) {
        pins.add(JobMapPin(
          jobId: pin.jobId,
          location: pin.location,
          color: pin.color,
          title: pin.title,
          engineerName: pin.engineerName,
          scheduledTime: pin.scheduledTime,
          statusLabel: pin.statusLabel,
          sequenceNumber: seq++,
        ));
      } else {
        // Fade non-route pins
        pins.add(JobMapPin(
          jobId: pin.jobId,
          location: pin.location,
          color: Colors.grey,
          title: pin.title,
          engineerName: pin.engineerName,
          scheduledTime: pin.scheduledTime,
          statusLabel: pin.statusLabel,
        ));
      }
    }

    return (
      pins: pins,
      routePoints: route.allPoints,
      missingCount: baseData.missingCount,
    );
  }

  Widget _buildSplitLayout(
    List<DispatchedJob> allJobs,
    ({List<JobMapPin> pins, int missingCount}) mapData,
    bool isDark,
  ) {
    final routeData = _buildMapDataWithRoute(allJobs, mapData);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: _buildCalendarView(allJobs, isDark),
        ),
        VerticalDivider(
          width: 1,
          color: isDark ? AppTheme.darkDivider : AppTheme.dividerColor,
        ),
        Expanded(
          flex: 2,
          child: Stack(
            children: [
              JobMap(
                pins: routeData.pins,
                routePoints: routeData.routePoints,
                missingLocationCount: routeData.missingCount,
                onPinTap: _selectJob,
              ),
              Positioned(
                top: 8,
                right: 8,
                child: RouteControls(
                  members: _members,
                  selectedEngineerId: _routeEngineerId,
                  selectedDate: _selectedDay,
                  isDark: isDark,
                  onEngineerChanged: (id) =>
                      setState(() => _routeEngineerId = id),
                  onDateChanged: _onDatePicked,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Narrower screens: full-width map with route controls.
  Widget _buildMapWithRouteControls(
    List<DispatchedJob> allJobs,
    ({List<JobMapPin> pins, int missingCount}) mapData,
    bool isDark,
  ) {
    final routeData = _buildMapDataWithRoute(allJobs, mapData);

    return Stack(
      children: [
        JobMap(
          pins: routeData.pins,
          routePoints: routeData.routePoints,
          missingLocationCount: routeData.missingCount,
          onPinTap: _selectJob,
        ),
        Positioned(
          top: 8,
          right: 8,
          child: RouteControls(
            members: _members,
            selectedEngineerId: _routeEngineerId,
            selectedDate: _selectedDay,
            isDark: isDark,
            onEngineerChanged: (id) =>
                setState(() => _routeEngineerId = id),
            onDateChanged: _onDatePicked,
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarView(List<DispatchedJob> allJobs, bool isDark) {
    switch (_viewMode) {
      case ScheduleViewMode.week:
        return ScheduleWeekView(
          weekStart: _weekStart,
          jobsByDay: _groupJobsByWeekDay(allJobs),
          isDark: isDark,
          selectedJobId: _selectedJobId,
          colorByEngineer: _colorByEngineer,
          jobColorFn: _jobColorFn,
          onJobTap: _selectJob,
          onDayHeaderTap: (date) {
            setState(() {
              _selectedDay = date;
              _focusedDay = date;
              _viewMode = ScheduleViewMode.day;
            });
          },
          onJobDropped: _handleJobDrop,
        );
      case ScheduleViewMode.month:
        return ScheduleMonthView(
          allJobs: allJobs,
          focusedDay: _focusedDay,
          selectedDay: _selectedDay,
          isDark: isDark,
          selectedJobId: _selectedJobId,
          jobColorFn: _jobColorFn,
          onDaySelected: (selected, focused) {
            setState(() {
              _selectedDay = selected;
              _focusedDay = focused;
              _weekStart = _startOfWeek(selected);
            });
          },
          onPageChanged: (focused) => setState(() => _focusedDay = focused),
          onJobTap: _selectJob,
        );
      case ScheduleViewMode.day:
        final dayJobs = allJobs
            .where((j) =>
                j.scheduledDate != null &&
                isSameDay(j.scheduledDate!, _selectedDay))
            .toList();
        return ScheduleDayView(
          date: _selectedDay,
          dayJobs: dayJobs,
          isDark: isDark,
          selectedJobId: _selectedJobId,
          jobColorFn: _jobColorFn,
          onJobTap: _selectJob,
        );
    }
  }
}
