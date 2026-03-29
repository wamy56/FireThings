import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../models/asset.dart';
import '../../models/asset_type.dart';
import '../../models/defect.dart';
import '../../models/service_record.dart';
import '../../data/default_asset_types.dart';
import '../../services/asset_service.dart';
import '../../services/defect_service.dart';
import '../../services/service_history_service.dart';
import '../../services/analytics_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/premium_dialog.dart';
import '../../widgets/premium_toast.dart';

class BatchTestScreen extends StatefulWidget {
  final String basePath;
  final String siteId;
  final List<Asset> assets;
  final List<AssetType> assetTypes;
  final String? jobsheetId;

  const BatchTestScreen({
    super.key,
    required this.basePath,
    required this.siteId,
    required this.assets,
    required this.assetTypes,
    this.jobsheetId,
  });

  @override
  State<BatchTestScreen> createState() => _BatchTestScreenState();
}

class _BatchTestScreenState extends State<BatchTestScreen> {
  int _currentIndex = 0;
  final List<String> _outcomes = []; // "pass", "fail", "skipped"
  bool _isComplete = false;
  bool _isSaving = false;
  int _defectsRecorded = 0;

  // Pre-loaded open defect counts per asset
  Map<String, int> _openDefectCounts = {};

  @override
  void initState() {
    super.initState();
    _outcomes.addAll(List.filled(widget.assets.length, ''));
    _loadOpenDefectCounts();
  }

  Future<void> _loadOpenDefectCounts() async {
    final counts = <String, int>{};
    for (final asset in widget.assets) {
      final defects = await DefectService.instance.getOpenDefectsForAsset(
        widget.basePath,
        widget.siteId,
        asset.id,
      );
      if (defects.isNotEmpty) {
        counts[asset.id] = defects.length;
      }
    }
    if (mounted) {
      setState(() {
        _openDefectCounts = counts;
      });
    }
  }

  AssetType? _getAssetType(String typeId) {
    try {
      return widget.assetTypes.firstWhere((t) => t.id == typeId);
    } catch (_) {
      return DefaultAssetTypes.getById(typeId);
    }
  }

  IconData _iconForType(AssetType? type) {
    if (type == null) return AppIcons.setting;
    switch (type.iconName) {
      case 'cpu': return AppIcons.cpu;
      case 'radar': return AppIcons.radar;
      case 'danger': return AppIcons.danger;
      case 'volumeHigh': return AppIcons.volumeHigh;
      case 'securitySafe': return AppIcons.securitySafe;
      case 'lampCharge': return AppIcons.lampCharge;
      case 'wind': return AppIcons.wind;
      case 'drop': return AppIcons.drop;
      case 'box': return AppIcons.box;
      case 'radar_heat': return AppIcons.radar;
      case 'door': return AppIcons.securitySafe;
      default: return AppIcons.setting;
    }
  }

  Future<void> _passCurrentAsset() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in');

      final asset = widget.assets[_currentIndex];
      final now = DateTime.now();
      final recordId = const Uuid().v4();

      // Create pass service record
      final record = ServiceRecord(
        id: recordId,
        assetId: asset.id,
        siteId: widget.siteId,
        jobsheetId: widget.jobsheetId,
        engineerId: user.uid,
        engineerName: user.displayName ?? 'Unknown',
        serviceDate: now,
        overallResult: 'pass',
        createdAt: now,
      );

      await ServiceHistoryService.instance
          .createRecord(widget.basePath, widget.siteId, record);

      // Update asset compliance
      await AssetService.instance.updateAsset(
        widget.basePath,
        widget.siteId,
        asset.copyWith(
          complianceStatus: Asset.statusPass,
          lastServiceDate: now,
          lastServiceBy: user.uid,
          lastServiceByName: user.displayName ?? 'Unknown',
          nextServiceDue: DateTime(now.year + 1, now.month, now.day),
        ),
      );

      // Auto-rectify any open defects
      final rectifiedCount = await DefectService.instance.rectifyAllForAsset(
        widget.basePath,
        widget.siteId,
        asset.id,
        rectifiedBy: user.uid,
        rectifiedByName: user.displayName ?? 'Unknown',
      );

      if (rectifiedCount > 0 && mounted) {
        // Update local count
        _openDefectCounts.remove(asset.id);
      }

      AnalyticsService.instance.logAssetTested(
        assetType: asset.assetTypeId,
        result: 'pass',
        siteId: widget.siteId,
      );

      setState(() {
        _outcomes[_currentIndex] = 'pass';
        _isSaving = false;
      });
      _advance();
    } catch (e) {
      if (mounted) {
        context.showErrorToast('Failed to save — try again');
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _failCurrentAsset() async {
    final asset = widget.assets[_currentIndex];
    final assetType = _getAssetType(asset.assetTypeId);

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DefectBottomSheet(
        basePath: widget.basePath,
        siteId: widget.siteId,
        asset: asset,
        assetType: assetType,
        jobsheetId: widget.jobsheetId,
      ),
    );

    if (result == true) {
      setState(() {
        _outcomes[_currentIndex] = 'fail';
        _defectsRecorded++;
        // Update open defect count for this asset
        _openDefectCounts[asset.id] =
            (_openDefectCounts[asset.id] ?? 0) + 1;
      });
      _advance();
    }
  }

  void _skip() {
    setState(() => _outcomes[_currentIndex] = 'skipped');
    _advance();
  }

  void _advance() {
    if (_currentIndex + 1 >= widget.assets.length) {
      _complete();
    } else {
      setState(() => _currentIndex++);
    }
  }

  void _complete() {
    final passCount = _outcomes.where((o) => o == 'pass').length;
    final failCount = _outcomes.where((o) => o == 'fail').length;
    final skippedCount = _outcomes.where((o) => o == 'skipped').length;

    AnalyticsService.instance.logBatchTestingCompleted(
      siteId: widget.siteId,
      passCount: passCount,
      failCount: failCount,
      skippedCount: skippedCount,
    );

    setState(() => _isComplete = true);
  }

  Future<bool> _confirmExit() async {
    final confirmed = await showAdaptiveAlertDialog<bool>(
      context: context,
      title: 'Stop Batch Testing?',
      message:
          'Tests already saved will be kept. Are you sure you want to stop?',
      confirmLabel: 'Stop',
      cancelLabel: 'Continue Testing',
      isDestructive: true,
    );
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isComplete) return _buildSummary(isDark);

    final asset = widget.assets[_currentIndex];
    final assetType = _getAssetType(asset.assetTypeId);
    final typeColor = assetType != null
        ? Color(
            int.parse(assetType.defaultColor.replaceFirst('#', '0xFF')))
        : Colors.grey;
    final progress = (_currentIndex + 1) / widget.assets.length;
    final hasOpenDefects = (_openDefectCounts[asset.id] ?? 0) > 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        final shouldPop = await _confirmExit();
        if (shouldPop && mounted) nav.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
              'Testing ${_currentIndex + 1} of ${widget.assets.length}'),
          leading: IconButton(
            icon: const Icon(AppIcons.close),
            onPressed: () async {
              final nav = Navigator.of(context);
              final shouldPop = await _confirmExit();
              if (shouldPop && mounted) nav.pop();
            },
          ),
        ),
        body: Column(
          children: [
            // Progress bar
            LinearProgressIndicator(
              value: progress,
              backgroundColor: isDark
                  ? Colors.grey.shade800
                  : Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.accentOrange),
              minHeight: 4,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.screenPadding),
                child: Column(
                  children: [
                    const Spacer(),
                    // Asset card
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.darkSurfaceElevated
                                : Colors.white,
                            borderRadius:
                                BorderRadius.circular(AppTheme.cardRadius),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color:
                                      typeColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(_iconForType(assetType),
                                    color: typeColor, size: 36),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                asset.reference ??
                                    assetType?.name ??
                                    'Asset',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (asset.variant != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '${assetType?.name ?? ''} — ${asset.variant}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? AppTheme.darkTextSecondary
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                              if (asset.locationDescription != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  asset.locationDescription!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? AppTheme.darkTextSecondary
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                              if (asset.zone != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Zone: ${asset.zone}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppTheme.darkTextSecondary
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Defect badge
                        if (hasOpenDefects)
                          Positioned(
                            top: -6,
                            right: -6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD32F2F),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(AppIcons.danger,
                                      color: Colors.white, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_openDefectCounts[asset.id]} open',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    // Action buttons
                    if (_isSaving)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: CircularProgressIndicator(),
                      )
                    else ...[
                      // Pass button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _passCurrentAsset,
                          icon: const Icon(AppIcons.tickCircle),
                          label: const Text('Pass'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Fail button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _failCurrentAsset,
                          icon: Icon(AppIcons.close),
                          label: const Text('Fail'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD32F2F),
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Skip button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _skip,
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Skip'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(bool isDark) {
    final passCount = _outcomes.where((o) => o == 'pass').length;
    final failCount = _outcomes.where((o) => o == 'fail').length;
    final skippedCount = _outcomes.where((o) => o == 'skipped').length;

    return Scaffold(
      appBar: AppBar(title: const Text('Batch Test Complete')),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        child: Column(
          children: [
            const Spacer(),
            Icon(AppIcons.tickCircle,
                size: 64, color: const Color(0xFF4CAF50)),
            const SizedBox(height: 16),
            const Text(
              'Testing Complete',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.assets.length} assets processed',
              style: TextStyle(
                fontSize: 15,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            // Stat cards
            Row(
              children: [
                _StatCard(
                  label: 'Pass',
                  count: passCount,
                  color: const Color(0xFF4CAF50),
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: 'Fail',
                  count: failCount,
                  color: const Color(0xFFD32F2F),
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: 'Skipped',
                  count: skippedCount,
                  color: Colors.grey,
                  isDark: isDark,
                ),
              ],
            ),
            if (_defectsRecorded > 0) ...[
              const SizedBox(height: 16),
              Text(
                '$_defectsRecorded defect${_defectsRecorded == 1 ? '' : 's'} recorded',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFD32F2F),
                ),
              ),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Done',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ─── Defect Bottom Sheet ───────────────────────────────────────────

class _DefectBottomSheet extends StatefulWidget {
  final String basePath;
  final String siteId;
  final Asset asset;
  final AssetType? assetType;
  final String? jobsheetId;

  const _DefectBottomSheet({
    required this.basePath,
    required this.siteId,
    required this.asset,
    this.assetType,
    this.jobsheetId,
  });

  @override
  State<_DefectBottomSheet> createState() => _DefectBottomSheetState();
}

class _DefectBottomSheetState extends State<_DefectBottomSheet> {
  String _severity = Defect.severityMinor;
  String? _selectedCommonFault;
  final _descriptionController = TextEditingController();
  final List<Uint8List> _photos = [];
  bool _isSaving = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() => _photos.add(bytes));
      }
    } catch (e) {
      if (mounted) context.showErrorToast('Failed to capture photo');
    }
  }

  Future<void> _submit() async {
    // Must have either a common fault or description
    final description = _selectedCommonFault != null
        ? (_descriptionController.text.trim().isNotEmpty
            ? '${_selectedCommonFault!} — ${_descriptionController.text.trim()}'
            : _selectedCommonFault!)
        : _descriptionController.text.trim();

    if (description.isEmpty) {
      context.showErrorToast('Select a fault or add a description');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in');

      final now = DateTime.now();
      final recordId = const Uuid().v4();
      final defectId = const Uuid().v4();

      // Upload photos
      List<String> photoUrls = [];
      if (_photos.isNotEmpty) {
        photoUrls = await DefectService.instance.uploadDefectPhotos(
          basePath: widget.basePath,
          siteId: widget.siteId,
          assetId: widget.asset.id,
          defectId: defectId,
          photos: _photos,
        );
      }

      // Create service record (fail)
      final record = ServiceRecord(
        id: recordId,
        assetId: widget.asset.id,
        siteId: widget.siteId,
        jobsheetId: widget.jobsheetId,
        engineerId: user.uid,
        engineerName: user.displayName ?? 'Unknown',
        serviceDate: now,
        overallResult: 'fail',
        defectNote: description,
        defectPhotoUrls: photoUrls,
        defectSeverity: _severity,
        createdAt: now,
      );

      await ServiceHistoryService.instance
          .createRecord(widget.basePath, widget.siteId, record);

      // Create standalone defect
      final defect = Defect(
        id: defectId,
        assetId: widget.asset.id,
        siteId: widget.siteId,
        severity: _severity,
        description: description,
        commonFaultId: _selectedCommonFault,
        photoUrls: photoUrls,
        status: Defect.statusOpen,
        createdBy: user.uid,
        createdByName: user.displayName ?? 'Unknown',
        createdAt: now,
        serviceRecordId: recordId,
      );

      await DefectService.instance
          .createDefect(widget.basePath, widget.siteId, defect);

      // Update asset compliance
      await AssetService.instance.updateAsset(
        widget.basePath,
        widget.siteId,
        widget.asset.copyWith(
          complianceStatus: Asset.statusFail,
          lastServiceDate: now,
          lastServiceBy: user.uid,
          lastServiceByName: user.displayName ?? 'Unknown',
          nextServiceDue: DateTime(now.year + 1, now.month, now.day),
        ),
      );

      AnalyticsService.instance.logAssetTested(
        assetType: widget.asset.assetTypeId,
        result: 'fail',
        siteId: widget.siteId,
      );

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        context.showErrorToast('Failed to save defect');
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final commonFaults = widget.assetType?.commonFaults ?? [];
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Record Defect',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                widget.asset.reference ?? widget.assetType?.name ?? 'Asset',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 20),

              // Severity picker
              Text(
                'Severity',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _SeverityChip(
                    label: 'Minor',
                    color: Colors.grey,
                    selected: _severity == Defect.severityMinor,
                    onTap: () =>
                        setState(() => _severity = Defect.severityMinor),
                  ),
                  const SizedBox(width: 8),
                  _SeverityChip(
                    label: 'Major',
                    color: const Color(0xFFF59E0B),
                    selected: _severity == Defect.severityMajor,
                    onTap: () =>
                        setState(() => _severity = Defect.severityMajor),
                  ),
                  const SizedBox(width: 8),
                  _SeverityChip(
                    label: 'Critical',
                    color: const Color(0xFFD32F2F),
                    selected: _severity == Defect.severityCritical,
                    onTap: () =>
                        setState(() => _severity = Defect.severityCritical),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Common faults dropdown
              if (commonFaults.isNotEmpty) ...[
                Text(
                  'Common Fault',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCommonFault,
                  decoration: InputDecoration(
                    hintText: 'Select a common fault (optional)',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('None'),
                    ),
                    ...commonFaults.map((fault) => DropdownMenuItem(
                          value: fault,
                          child: Text(fault, overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedCommonFault = val);
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Description
              Text(
                'Description',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              CustomTextField(
                controller: _descriptionController,
                label: 'Description',
                hint: _selectedCommonFault != null
                    ? 'Additional notes (optional)'
                    : 'Describe the defect',
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Photos
              Text(
                'Photos',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 72,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    // Add photo button
                    GestureDetector(
                      onTap: _takePhoto,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? Colors.grey.shade600
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Icon(
                          AppIcons.camera,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade500,
                        ),
                      ),
                    ),
                    // Photo thumbnails
                    ..._photos.asMap().entries.map((entry) => Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(
                                  entry.value,
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () => setState(
                                      () => _photos.removeAt(entry.key)),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(AppIcons.close,
                                        color: Colors.white, size: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD32F2F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Record Defect',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Severity Chip ─────────────────────────────────────────────────

class _SeverityChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _SeverityChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}

// ─── Stat Card ─────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.label,
    required this.count,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color:
                    isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
