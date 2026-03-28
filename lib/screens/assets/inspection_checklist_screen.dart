import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../models/asset.dart';
import '../../models/asset_type.dart';
import '../../models/checklist_item.dart';
import '../../models/service_record.dart';
import '../../services/asset_service.dart';
import '../../services/service_history_service.dart';
import '../../services/analytics_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/premium_dialog.dart';
import '../../widgets/premium_toast.dart';
import '../../widgets/keyboard_dismiss_wrapper.dart';

class InspectionChecklistScreen extends StatefulWidget {
  final String basePath;
  final String siteId;
  final Asset asset;
  final AssetType assetType;
  final String? jobsheetId;

  const InspectionChecklistScreen({
    super.key,
    required this.basePath,
    required this.siteId,
    required this.asset,
    required this.assetType,
    this.jobsheetId,
  });

  @override
  State<InspectionChecklistScreen> createState() =>
      _InspectionChecklistScreenState();
}

class _InspectionChecklistScreenState extends State<InspectionChecklistScreen> {
  final Map<String, String> _results = {};
  final Map<String, TextEditingController> _noteControllers = {};
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, bool> _noteExpanded = {};
  final _defectNoteController = TextEditingController();
  final _generalNotesController = TextEditingController();
  String? _defectSeverity;
  String? _defectAction;
  final List<Uint8List> _defectPhotos = [];
  bool _isSaving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    for (final item in widget.assetType.defaultChecklist) {
      _noteControllers[item.id] = TextEditingController();
      if (item.resultType == 'text' || item.resultType == 'number') {
        _textControllers[item.id] = TextEditingController();
      }
    }
  }

  @override
  void dispose() {
    for (final c in _noteControllers.values) {
      c.dispose();
    }
    for (final c in _textControllers.values) {
      c.dispose();
    }
    _defectNoteController.dispose();
    _generalNotesController.dispose();
    super.dispose();
  }

  bool get _hasAnyFail {
    for (final item in widget.assetType.defaultChecklist) {
      final result = _results[item.id];
      if (result == null) continue;
      if (item.resultType == 'pass_fail' && result == 'fail') return true;
      if (item.resultType == 'yes_no' && result == 'no' && item.isRequired) {
        return true;
      }
    }
    return false;
  }

  String get _overallResult {
    for (final item in widget.assetType.defaultChecklist) {
      if (!item.isRequired) continue;
      final result = _results[item.id];
      if (item.resultType == 'pass_fail' && result == 'fail') return 'fail';
      if (item.resultType == 'yes_no' && result == 'no') return 'fail';
    }
    return 'pass';
  }

  bool get _isComplete {
    if (widget.assetType.defaultChecklist.isEmpty) return true;
    for (final item in widget.assetType.defaultChecklist) {
      if (!item.isRequired) continue;
      if (item.resultType == 'pass_fail' || item.resultType == 'yes_no') {
        if (_results[item.id] == null) return false;
      }
      if (item.resultType == 'number' || item.resultType == 'text') {
        final controller = _textControllers[item.id];
        if (controller == null || controller.text.trim().isEmpty) return false;
      }
    }
    return true;
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;
    final confirmed = await showAdaptiveAlertDialog<bool>(
      context: context,
      title: 'Discard Changes?',
      message: 'You have unsaved inspection data. Are you sure you want to leave?',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep Editing',
      isDestructive: true,
    );
    return confirmed == true;
  }

  Future<void> _pickPhoto() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        imageQuality: 80,
      );
      if (image == null) return;
      final bytes = await File(image.path).readAsBytes();
      setState(() {
        _defectPhotos.add(bytes);
        _hasChanges = true;
      });
    } catch (e) {
      if (mounted) context.showErrorToast('Failed to capture photo');
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in');

      final recordId = const Uuid().v4();
      final now = DateTime.now();

      // Build checklist results
      final checklistResults = <ChecklistResult>[];
      for (final item in widget.assetType.defaultChecklist) {
        String result;
        if (item.resultType == 'text' || item.resultType == 'number') {
          result = _textControllers[item.id]?.text.trim() ?? '';
        } else {
          result = _results[item.id] ?? 'n/a';
        }
        checklistResults.add(ChecklistResult(
          checklistItemId: item.id,
          label: item.label,
          result: result,
          note: _noteControllers[item.id]?.text.trim().isNotEmpty == true
              ? _noteControllers[item.id]!.text.trim()
              : null,
        ));
      }

      // Upload defect photos
      List<String> photoUrls = [];
      if (_defectPhotos.isNotEmpty) {
        photoUrls = await ServiceHistoryService.instance.uploadDefectPhotos(
          basePath: widget.basePath,
          siteId: widget.siteId,
          assetId: widget.asset.id,
          recordId: recordId,
          photos: _defectPhotos,
        );
      }

      // Create service record
      final record = ServiceRecord(
        id: recordId,
        assetId: widget.asset.id,
        siteId: widget.siteId,
        jobsheetId: widget.jobsheetId,
        engineerId: user.uid,
        engineerName: user.displayName ?? 'Unknown',
        serviceDate: now,
        overallResult: _overallResult,
        checklistResults: checklistResults,
        defectNote: _defectNoteController.text.trim().isNotEmpty
            ? _defectNoteController.text.trim()
            : null,
        defectPhotoUrls: photoUrls,
        defectSeverity: _hasAnyFail ? _defectSeverity : null,
        defectAction: _hasAnyFail ? _defectAction : null,
        notes: _generalNotesController.text.trim().isNotEmpty
            ? _generalNotesController.text.trim()
            : null,
        createdAt: now,
      );

      await ServiceHistoryService.instance
          .createRecord(widget.basePath, widget.siteId, record);

      // Update asset compliance
      await AssetService.instance.updateAsset(
        widget.basePath,
        widget.siteId,
        widget.asset.copyWith(
          complianceStatus: _overallResult,
          lastServiceDate: now,
          lastServiceBy: user.uid,
          lastServiceByName: user.displayName ?? 'Unknown',
          nextServiceDue: DateTime(now.year + 1, now.month, now.day),
        ),
      );

      AnalyticsService.instance.logAssetTested(
        assetType: widget.asset.assetTypeId,
        result: _overallResult,
        siteId: widget.siteId,
      );

      if (mounted) {
        context.showSuccessToast('Inspection saved');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) context.showErrorToast('Failed to save inspection');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  IconData _iconForType(AssetType type) {
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
      default: return AppIcons.setting;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final type = widget.assetType;
    final typeColor =
        Color(int.parse(type.defaultColor.replaceFirst('#', '0xFF')));

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) nav.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Inspect ${widget.asset.reference ?? type.name}'),
          actions: [
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: AdaptiveLoadingIndicator(),
                ),
              )
            else
              TextButton(
                onPressed: _isComplete ? _save : null,
                child: const Text('Save'),
              ),
          ],
        ),
        body: KeyboardDismissWrapper(
          child: ListView(
            padding: const EdgeInsets.all(AppTheme.screenPadding),
            children: [
              // Asset identity header
              _buildAssetHeader(isDark, typeColor),
              const SizedBox(height: 24),

              // Checklist items
              if (widget.assetType.defaultChecklist.isEmpty)
                _buildEmptyChecklist(isDark)
              else
                ...widget.assetType.defaultChecklist.map(
                    (item) => _buildChecklistItem(item, isDark)),

              // Defect section
              _buildDefectSection(isDark),

              // General notes
              const SizedBox(height: 24),
              CustomTextField(
                controller: _generalNotesController,
                label: 'General Notes',
                hint: 'Any additional observations...',
                maxLines: 3,
                prefixIcon: Icon(AppIcons.note),
                onChanged: (_) => _markChanged(),
              ),

              // Save button
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isComplete && !_isSaving ? _save : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _isSaving ? 'Saving...' : 'Save Inspection',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssetHeader(bool isDark, Color typeColor) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.cardPadding),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_iconForType(widget.assetType),
                color: typeColor, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.asset.reference ?? widget.assetType.name,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700),
                ),
                if (widget.asset.variant != null)
                  Text(
                    '${widget.assetType.name} — ${widget.asset.variant}',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textSecondary,
                    ),
                  )
                else
                  Text(
                    widget.assetType.name,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textSecondary,
                    ),
                  ),
                if (widget.asset.locationDescription != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.asset.locationDescription!,
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
        ],
      ),
    );
  }

  Widget _buildEmptyChecklist(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.cardPadding),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Icon(AppIcons.clipboardTick,
              size: 32,
              color:
                  isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
          const SizedBox(height: 8),
          Text(
            'No checklist defined for this asset type.\nYou can still save general notes.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color:
                  isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(ChecklistItem item, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label + required indicator
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.label,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                if (item.isRequired)
                  Text(
                    'Required',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.accentOrange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
            if (item.description != null) ...[
              const SizedBox(height: 4),
              Text(
                item.description!,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Input by type
            _buildResultInput(item, isDark),

            // Optional note
            const SizedBox(height: 8),
            if (_noteExpanded[item.id] == true) ...[
              CustomTextField(
                controller: _noteControllers[item.id]!,
                label: 'Note',
                hint: 'Optional note for this item...',
                maxLines: 2,
                onChanged: (_) => _markChanged(),
              ),
            ] else
              GestureDetector(
                onTap: () =>
                    setState(() => _noteExpanded[item.id] = true),
                child: Row(
                  children: [
                    Icon(AppIcons.note,
                        size: 14,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      'Add note',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultInput(ChecklistItem item, bool isDark) {
    switch (item.resultType) {
      case 'pass_fail':
        return _buildToggleButtons(
          item.id,
          [('pass', 'Pass', const Color(0xFF4CAF50)),
           ('fail', 'Fail', const Color(0xFFD32F2F))],
          isDark,
        );
      case 'yes_no':
        return _buildToggleButtons(
          item.id,
          [('yes', 'Yes', const Color(0xFF4CAF50)),
           ('no', 'No', const Color(0xFFD32F2F))],
          isDark,
        );
      case 'number':
        return CustomTextField(
          controller: _textControllers[item.id]!,
          label: 'Value',
          keyboardType: TextInputType.number,
          onChanged: (_) {
            _markChanged();
            setState(() {});
          },
        );
      case 'text':
        return CustomTextField(
          controller: _textControllers[item.id]!,
          label: 'Value',
          onChanged: (_) {
            _markChanged();
            setState(() {});
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildToggleButtons(
      String itemId,
      List<(String value, String label, Color color)> options,
      bool isDark) {
    final selected = _results[itemId];
    return Row(
      children: options.map((option) {
        final isSelected = selected == option.$1;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
                right: option != options.last ? 10 : 0),
            child: GestureDetector(
              onTap: () {
                setState(() => _results[itemId] = option.$1);
                _markChanged();
              },
              child: AnimatedContainer(
                duration: AppTheme.fastAnimation,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? option.$3.withValues(alpha: 0.12)
                      : isDark
                          ? AppTheme.darkSurfaceElevated
                          : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? option.$3
                        : isDark
                            ? Colors.grey.shade700
                            : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isSelected)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(
                          option.$1 == 'pass' || option.$1 == 'yes'
                              ? AppIcons.tickCircle
                              : AppIcons.close,
                          size: 18,
                          color: option.$3,
                        ),
                      ),
                    Text(
                      option.$2,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? option.$3
                            : isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDefectSection(bool isDark) {
    return AnimatedSize(
      duration: AppTheme.normalAnimation,
      curve: AppTheme.defaultCurve,
      child: _hasAnyFail
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Row(
                  children: [
                    Icon(AppIcons.danger,
                        size: 18, color: const Color(0xFFD32F2F)),
                    const SizedBox(width: 8),
                    const Text(
                      'Defect Details',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.darkSurfaceElevated
                        : Colors.white,
                    borderRadius:
                        BorderRadius.circular(AppTheme.cardRadius),
                    boxShadow: AppTheme.cardShadow,
                    border: Border.all(
                      color: const Color(0xFFD32F2F).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Severity
                      DropdownButtonFormField<String>(
                        initialValue: _defectSeverity,
                        decoration: const InputDecoration(
                          labelText: 'Severity',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'minor', child: Text('Minor')),
                          DropdownMenuItem(
                              value: 'major', child: Text('Major')),
                          DropdownMenuItem(
                              value: 'critical', child: Text('Critical')),
                        ],
                        onChanged: (val) {
                          setState(() => _defectSeverity = val);
                          _markChanged();
                        },
                      ),
                      const SizedBox(height: 12),

                      // Action
                      DropdownButtonFormField<String>(
                        initialValue: _defectAction,
                        decoration: const InputDecoration(
                          labelText: 'Action',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'rectified_on_site',
                              child: Text('Rectified on site')),
                          DropdownMenuItem(
                              value: 'quote_required',
                              child: Text('Quote required')),
                          DropdownMenuItem(
                              value: 'replacement_needed',
                              child: Text('Replacement needed')),
                        ],
                        onChanged: (val) {
                          setState(() => _defectAction = val);
                          _markChanged();
                        },
                      ),
                      const SizedBox(height: 12),

                      // Defect note
                      CustomTextField(
                        controller: _defectNoteController,
                        label: 'Defect Description',
                        hint: 'Describe the defect...',
                        maxLines: 3,
                        onChanged: (_) => _markChanged(),
                      ),
                      const SizedBox(height: 12),

                      // Photos
                      Text(
                        'Defect Photos',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ..._defectPhotos.asMap().entries.map((entry) {
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    entry.value,
                                    width: 72,
                                    height: 72,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: -4,
                                  right: -4,
                                  child: GestureDetector(
                                    onTap: () => setState(() =>
                                        _defectPhotos
                                            .removeAt(entry.key)),
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close,
                                          size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                          GestureDetector(
                            onTap: _pickPhoto,
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.grey.shade700
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: Icon(
                                AppIcons.camera,
                                color: isDark
                                    ? AppTheme.darkTextSecondary
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            )
          : const SizedBox.shrink(),
    );
  }

  void _markChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }
}
