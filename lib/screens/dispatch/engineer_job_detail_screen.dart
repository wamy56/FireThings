import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/models.dart';
import '../../services/dispatch_service.dart';
import '../../services/database_helper.dart';
import '../../services/analytics_service.dart';
import '../../services/asset_service.dart';
import '../../services/remote_config_service.dart';
import '../../services/user_profile_service.dart';
import '../../services/bs5839_config_service.dart';
import '../../services/inspection_visit_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/premium_toast.dart';
import '../../widgets/premium_dialog.dart';
import '../../widgets/site_map_preview.dart';
import '../new_job/new_job_screen.dart';
import '../history/job_detail_screen.dart';
import '../assets/site_asset_register_screen.dart';

class EngineerJobDetailScreen extends StatelessWidget {
  final String companyId;
  final String jobId;

  const EngineerJobDetailScreen({
    super.key,
    required this.companyId,
    required this.jobId,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Job Details')),
      body: StreamBuilder<DispatchedJob?>(
        stream: DispatchService.instance.getJobStream(companyId, jobId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: AdaptiveLoadingIndicator());
          }

          final job = snapshot.data;
          if (job == null) {
            return const Center(child: Text('Job not found'));
          }

          return _EngineerJobContent(job: job, isDark: isDark);
        },
      ),
    );
  }
}

class _EngineerJobContent extends StatelessWidget {
  final DispatchedJob job;
  final bool isDark;

  const _EngineerJobContent({required this.job, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      children: [
        // Title and priority
        Text(
          job.title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        if (job.priority != JobPriority.normal) ...[
          const SizedBox(height: 8),
          _priorityBanner(job.priority),
        ],
        if (job.jobType != null) ...[
          const SizedBox(height: 4),
          Text(
            job.jobType!,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
            ),
          ),
        ],
        const SizedBox(height: 24),

        // Site section
        _sectionCard(context, 'Site', AppIcons.building, [
          _infoRow('Name', job.siteName),
          _infoRow('Address', job.siteAddress),
          if (job.parkingNotes != null) _infoRow('Parking', job.parkingNotes!),
          if (job.accessNotes != null) _infoRow('Access', job.accessNotes!),
          if (job.siteNotes != null) _infoRow('Notes', job.siteNotes!),
          const SizedBox(height: 12),
          SiteMapPreview(
            address: job.siteAddress,
            latitude: job.latitude,
            longitude: job.longitude,
            height: 180,
            onTap: () => _openMaps(context, job.siteAddress),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openMaps(context, job.siteAddress),
              icon: Icon(AppIcons.map),
              label: const Text('Get Directions'),
            ),
          ),
        ]),
        const SizedBox(height: 16),

        // Site Assets section (conditional)
        if (job.companySiteId != null &&
            RemoteConfigService.instance.assetRegisterEnabled) ...[
          _buildSiteAssetsSection(context),
          const SizedBox(height: 16),
        ],

        // BS 5839 Inspection section (conditional)
        if (job.companySiteId != null &&
            RemoteConfigService.instance.bs5839ModeEnabled) ...[
          _Bs5839InspectionSection(job: job, isDark: isDark),
          const SizedBox(height: 16),
        ],

        // Contact section
        if (job.contactName != null ||
            job.contactPhone != null ||
            job.contactEmail != null)
          ...[
            _sectionCard(context, 'Contact', AppIcons.user, [
              if (job.contactName != null) _infoRow('Name', job.contactName!),
              if (job.contactPhone != null)
                InkWell(
                  onTap: () {
                    AnalyticsService.instance.logDispatchContactCalled(job.companyId);
                    _launchUrl('tel:${job.contactPhone}');
                  },
                  child: _infoRow('Phone', job.contactPhone!,
                      valueColor: isDark
                          ? AppTheme.darkPrimaryBlue
                          : AppTheme.primaryBlue),
                ),
              if (job.contactEmail != null)
                InkWell(
                  onTap: () => _launchUrl('mailto:${job.contactEmail}'),
                  child: _infoRow('Email', job.contactEmail!,
                      valueColor: isDark
                          ? AppTheme.darkPrimaryBlue
                          : AppTheme.primaryBlue),
                ),
            ]),
            const SizedBox(height: 16),
          ],

        // Schedule section
        if (job.scheduledDate != null || job.estimatedDuration != null)
          ...[
            _sectionCard(context, 'Schedule', AppIcons.calendar, [
              if (job.scheduledDate != null)
                _infoRow('Date',
                    '${job.scheduledDate!.day}/${job.scheduledDate!.month}/${job.scheduledDate!.year}'),
              if (job.scheduledTime != null) _infoRow('Time', job.scheduledTime!),
              if (job.estimatedDuration != null)
                _infoRow('Duration', job.estimatedDuration!),
            ]),
            const SizedBox(height: 16),
          ],

        // System info
        if (job.systemCategory != null ||
            job.panelMake != null ||
            job.panelLocation != null)
          ...[
            _sectionCard(context, 'System', AppIcons.flash, [
              if (job.systemCategory != null)
                _infoRow('Category', job.systemCategory!),
              if (job.panelMake != null) _infoRow('Panel Make', job.panelMake!),
              if (job.panelLocation != null)
                _infoRow('Panel Location', job.panelLocation!),
              if (job.numberOfZones != null)
                _infoRow('Zones', '${job.numberOfZones}'),
            ]),
            const SizedBox(height: 16),
          ],

        // Description
        if (job.description != null) ...[
          _sectionCard(context, 'Notes', AppIcons.note, [
            Text(job.description!, style: const TextStyle(fontSize: 14)),
          ]),
          const SizedBox(height: 16),
        ],

        const SizedBox(height: 8),

        // Action buttons based on current status
        ..._buildActionButtons(context),

        const SizedBox(height: 40),
      ],
    );
  }

  List<Widget> _buildActionButtons(BuildContext context) {
    switch (job.status) {
      case DispatchedJobStatus.assigned:
      case DispatchedJobStatus.accepted:
        return [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () =>
                  _updateStatus(context, DispatchedJobStatus.enRoute),
              icon: Icon(AppIcons.routing),
              label: const Text('En Route'),
            ),
          ),
        ];
      case DispatchedJobStatus.enRoute:
        return [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () =>
                  _updateStatus(context, DispatchedJobStatus.onSite),
              icon: Icon(AppIcons.location),
              label: const Text('Arrived On Site'),
            ),
          ),
        ];
      case DispatchedJobStatus.onSite:
        return [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  adaptivePageRoute(
                    builder: (_) => NewJobScreen(dispatchedJob: job),
                  ),
                );
              },
              icon: Icon(AppIcons.clipboardTick),
              label: const Text('Create Jobsheet'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () =>
                  _updateStatus(context, DispatchedJobStatus.completed),
              icon: Icon(AppIcons.tickCircle),
              label: const Text('Complete Without Jobsheet'),
            ),
          ),
        ];
      case DispatchedJobStatus.completed:
        if (job.linkedJobsheetId != null) {
          return [
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => _viewLinkedJobsheet(context, job.linkedJobsheetId!),
                icon: Icon(AppIcons.document),
                label: const Text('View Linked Jobsheet'),
              ),
            ),
          ];
        }
        return [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  adaptivePageRoute(
                    builder: (_) => NewJobScreen(dispatchedJob: job),
                  ),
                );
              },
              icon: Icon(AppIcons.clipboardTick),
              label: const Text('Create Jobsheet'),
            ),
          ),
        ];
      default:
        return [];
    }
  }

  Future<void> _viewLinkedJobsheet(BuildContext context, String jobsheetId) async {
    try {
      // Try local DB first
      var jobsheet = await DatabaseHelper.instance.getJobsheetById(jobsheetId);

      // Firestore fallback for jobsheets created on another device
      if (jobsheet == null) {
        final companyId = UserProfileService.instance.companyId;
        if (companyId != null) {
          final doc = await FirebaseFirestore.instance
              .collection('companies')
              .doc(companyId)
              .collection('completed_jobsheets')
              .doc(jobsheetId)
              .get();
          if (doc.exists && doc.data() != null) {
            jobsheet = Jobsheet.fromJson(doc.data()!);
          }
        }
      }

      if (jobsheet != null && context.mounted) {
        Navigator.push(
          context,
          adaptivePageRoute(
            builder: (_) => JobDetailScreen(jobsheet: jobsheet!),
          ),
        );
      } else if (context.mounted) {
        context.showErrorToast('Jobsheet not found');
      }
    } catch (e) {
      if (context.mounted) {
        context.showErrorToast('Failed to load jobsheet');
      }
    }
  }

  Future<void> _updateStatus(
    BuildContext context,
    DispatchedJobStatus newStatus,
  ) async {
    try {
      final oldStatus = job.status;
      await DispatchService.instance.updateJobStatus(
        companyId: job.companyId,
        jobId: job.id,
        newStatus: newStatus,
      );
      AnalyticsService.instance.logDispatchJobStatusChanged(
        job.companyId,
        oldStatus.name,
        newStatus.name,
      );
      if (newStatus == DispatchedJobStatus.accepted) {
        AnalyticsService.instance.logDispatchJobAccepted(
          job.companyId,
          job.id,
        );
      } else if (newStatus == DispatchedJobStatus.completed) {
        AnalyticsService.instance.logDispatchJobCompleted(
          job.companyId,
          job.id,
          job.linkedJobsheetId != null,
        );
      }
    } catch (e) {
      if (context.mounted) {
        context.showErrorToast('Failed to update status');
      }
    }
  }


  Widget _buildSiteAssetsSection(BuildContext context) {
    final basePath = 'companies/${job.companyId}';
    final siteId = job.companySiteId!;

    return FutureBuilder<List<Asset>>(
      future: AssetService.instance.getAssetsStream(basePath, siteId).first,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _sectionCard(context, 'Site Assets', AppIcons.clipboard, [
            const SizedBox(
              height: 40,
              child: Center(child: AdaptiveLoadingIndicator()),
            ),
          ]);
        }

        final assets = snapshot.data ?? [];
        if (assets.isEmpty) {
          return _sectionCard(context, 'Site Assets', AppIcons.clipboard, [
            Text(
              'No assets registered at this site',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
              ),
            ),
          ]);
        }

        final active = assets.where((a) => a.complianceStatus != AssetComplianceStatus.decommissioned).toList();
        final pass = active.where((a) => a.complianceStatus == AssetComplianceStatus.pass).length;
        final fail = active.where((a) => a.complianceStatus == AssetComplianceStatus.fail).length;
        final untested = active.where((a) => a.complianceStatus == AssetComplianceStatus.untested).length;

        // Lifecycle warnings
        final now = DateTime.now();
        final lifecycleWarnings = active.where((a) {
          if (a.installDate == null || a.expectedLifespanYears == null) return false;
          final age = now.difference(a.installDate!).inDays / 365.25;
          final remaining = a.expectedLifespanYears! - age;
          return remaining < 1;
        }).length;

        return _sectionCard(context, 'Site Assets', AppIcons.clipboard, [
          Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 14),
              children: [
                TextSpan(
                  text: '${active.length} assets: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(
                  text: '$pass pass',
                  style: TextStyle(
                    color: AppTheme.successGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (fail > 0) ...[
                  const TextSpan(text: ', '),
                  TextSpan(
                    text: '$fail fail',
                    style: TextStyle(
                      color: AppTheme.errorRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (untested > 0) ...[
                  const TextSpan(text: ', '),
                  TextSpan(
                    text: '$untested untested',
                    style: TextStyle(
                      color: AppTheme.accentOrange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (lifecycleWarnings > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(AppIcons.danger, size: 14, color: AppTheme.accentOrange),
                const SizedBox(width: 4),
                Text(
                  '$lifecycleWarnings asset${lifecycleWarnings == 1 ? '' : 's'} approaching end of life',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.accentOrange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SiteAssetRegisterScreen(
                      siteId: siteId,
                      siteName: job.siteName,
                      siteAddress: job.siteAddress,
                      basePath: basePath,
                    ),
                  ),
                );
              },
              icon: Icon(AppIcons.clipboard),
              label: const Text('View Asset Register'),
            ),
          ),
        ]);
      },
    );
  }

  Widget _sectionCard(
    BuildContext context,
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.cardPadding),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: isDark ? null : AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.mediumGrey),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.mediumGrey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _priorityBanner(JobPriority priority) {
    final isEmergency = priority == JobPriority.emergency;
    final color = isEmergency ? Colors.red : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(AppIcons.warning, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            isEmergency ? 'Emergency Priority' : 'Urgent Priority',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _openMaps(BuildContext context, String address) {
    AnalyticsService.instance.logDispatchDirectionsOpened(job.companyId);
    final encodedAddress = Uri.encodeComponent(address);

    final options = <ActionSheetOption>[
      if (PlatformUtils.isApple)
        ActionSheetOption(
          label: 'Apple Maps',
          icon: AppIcons.map,
          onTap: () => _launchUrl('https://maps.apple.com/?daddr=$encodedAddress'),
        ),
      ActionSheetOption(
        label: 'Google Maps',
        icon: AppIcons.location,
        onTap: () => _launchUrl('https://www.google.com/maps/search/?api=1&query=$encodedAddress'),
      ),
      ActionSheetOption(
        label: 'Waze',
        icon: AppIcons.routing,
        onTap: () => _launchUrl('https://waze.com/ul?q=$encodedAddress&navigate=yes'),
      ),
    ];

    showAdaptiveActionSheet(
      context: context,
      title: 'Open with',
      options: options,
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _Bs5839InspectionSection extends StatefulWidget {
  final DispatchedJob job;
  final bool isDark;

  const _Bs5839InspectionSection({required this.job, required this.isDark});

  @override
  State<_Bs5839InspectionSection> createState() =>
      _Bs5839InspectionSectionState();
}

class _Bs5839InspectionSectionState extends State<_Bs5839InspectionSection> {
  bool _creating = false;

  String get _basePath => 'companies/${widget.job.companyId}';
  String get _siteId => widget.job.companySiteId!;

  Future<void> _startVisit() async {
    setState(() => _creating = true);
    try {
      final profile = UserProfileService.instance;
      final visitId = InspectionVisitService.instance
          .generateId(_basePath, _siteId);
      final visit = InspectionVisit(
        id: visitId,
        siteId: _siteId,
        engineerId: profile.profile?.uid ?? '',
        engineerName: profile.resolveEngineerName(),
        visitType: InspectionVisitType.routineService,
        visitDate: DateTime.now(),
        jobsheetId: widget.job.linkedJobsheetId,
        dispatchedJobId: widget.job.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await InspectionVisitService.instance
          .saveVisit(_basePath, _siteId, visit);
      if (mounted) {
        context.showSuccessToast('Compliance visit started');
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        context.showErrorToast('Failed to start visit: $e');
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Bs5839SystemConfig?>(
      future: Bs5839ConfigService.instance.getConfig(_basePath, _siteId),
      builder: (context, configSnap) {
        if (configSnap.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final config = configSnap.data;
        if (config == null) return const SizedBox.shrink();

        return StreamBuilder<List<InspectionVisit>>(
          stream: InspectionVisitService.instance
              .getVisitsStream(_basePath, _siteId),
          builder: (context, visitSnap) {
            final visits = visitSnap.data ?? [];
            final linkedVisit = visits
                .where((v) => v.dispatchedJobId == widget.job.id)
                .toList();
            final activeVisit = linkedVisit.isNotEmpty
                ? linkedVisit.first
                : null;
            final isCompleted = activeVisit?.completedAt != null;

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.cardPadding),
              decoration: BoxDecoration(
                color: widget.isDark
                    ? AppTheme.darkSurfaceElevated
                    : Colors.white,
                borderRadius:
                    BorderRadius.circular(AppTheme.cardRadius),
                boxShadow:
                    widget.isDark ? null : AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(AppIcons.shield, size: 18,
                          color: AppTheme.mediumGrey),
                      const SizedBox(width: 8),
                      Text(
                        'BS 5839 Inspection',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: widget.isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.mediumGrey,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          config.category.displayLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (activeVisit == null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _creating ? null : _startVisit,
                        icon: _creating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : Icon(AppIcons.play),
                        label: const Text(
                            'Start Compliance Visit'),
                      ),
                    )
                  else ...[
                    _visitRow(
                      'Visit Type',
                      activeVisit.visitType.displayLabel,
                    ),
                    _visitRow(
                      'Status',
                      isCompleted
                          ? activeVisit.declaration.displayLabel
                          : 'In Progress',
                    ),
                    if (isCompleted &&
                        activeVisit.reportPdfUrl != null) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            launchUrl(
                              Uri.parse(activeVisit.reportPdfUrl!),
                              mode:
                                  LaunchMode.externalApplication,
                            );
                          },
                          icon: Icon(AppIcons.document),
                          label: const Text('View Report'),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _visitRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: widget.isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.mediumGrey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
