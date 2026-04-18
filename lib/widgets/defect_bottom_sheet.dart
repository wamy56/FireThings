import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/asset.dart';
import '../models/asset_type.dart';
import '../models/defect.dart';
import '../models/service_record.dart';
import '../services/asset_service.dart';
import '../services/defect_service.dart';
import '../services/service_history_service.dart';
import '../services/analytics_service.dart';
import '../services/remote_config_service.dart';
import '../utils/theme.dart';
import '../utils/icon_map.dart';
import '../screens/quoting/quote_screen.dart';
import 'custom_text_field.dart';
import 'premium_toast.dart';

/// Shows the defect recording bottom sheet.
/// Returns `true` if a defect was successfully recorded.
Future<bool?> showDefectBottomSheet({
  required BuildContext context,
  required String basePath,
  required String siteId,
  required Asset asset,
  AssetType? assetType,
  String? jobsheetId,
  String? siteName,
  String? customerName,
  String? customerAddress,
  String? customerEmail,
  String? customerPhone,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DefectBottomSheet(
      basePath: basePath,
      siteId: siteId,
      asset: asset,
      assetType: assetType,
      jobsheetId: jobsheetId,
      siteName: siteName,
      customerName: customerName,
      customerAddress: customerAddress,
      customerEmail: customerEmail,
      customerPhone: customerPhone,
    ),
  );
}

class DefectBottomSheet extends StatefulWidget {
  final String basePath;
  final String siteId;
  final Asset asset;
  final AssetType? assetType;
  final String? jobsheetId;
  final String? siteName;
  final String? customerName;
  final String? customerAddress;
  final String? customerEmail;
  final String? customerPhone;

  const DefectBottomSheet({
    super.key,
    required this.basePath,
    required this.siteId,
    required this.asset,
    this.assetType,
    this.jobsheetId,
    this.siteName,
    this.customerName,
    this.customerAddress,
    this.customerEmail,
    this.customerPhone,
  });

  @override
  State<DefectBottomSheet> createState() => _DefectBottomSheetState();
}

class _DefectBottomSheetState extends State<DefectBottomSheet> {
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

      // Defect and service record are now saved. Update asset status
      // in a separate try/catch so a failure here doesn't show a
      // misleading "Failed to save defect" message.
      try {
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
      } catch (e) {
        debugPrint('Failed to update asset status after defect save: $e');
        if (mounted) {
          context.showErrorToast('Defect saved but failed to update asset status');
        }
      }

      AnalyticsService.instance.logAssetTested(
        assetType: widget.asset.assetTypeId,
        result: 'fail',
        siteId: widget.siteId,
      );

      if (mounted) {
        if (RemoteConfigService.instance.quotingEnabled) {
          _showSuccessWithQuoteOption(defect);
        } else {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        context.showErrorToast('Failed to save defect');
        setState(() => _isSaving = false);
      }
    }
  }

  void _showSuccessWithQuoteOption(Defect defect) {
    setState(() => _isSaving = false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(AppIcons.tickCircle, color: AppTheme.successGreen, size: 22),
            const SizedBox(width: 8),
            const Text('Defect Recorded'),
          ],
        ),
        content: const Text(
          'Would you like to create a repair quote for this defect?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(true);
            },
            child: const Text('Not Now'),
          ),
          ElevatedButton.icon(
            icon: Icon(AppIcons.receipt, size: 18),
            label: const Text('Create Quote'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentOrange,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(true);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QuoteScreen(
                    fromDefect: defect,
                    siteId: widget.siteId,
                    siteName: widget.siteName,
                    customerName: widget.customerName,
                    customerAddress: widget.customerAddress,
                    customerEmail: widget.customerEmail,
                    customerPhone: widget.customerPhone,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
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
                  isExpanded: true,
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
                  onChanged: (val) =>
                      setState(() => _selectedCommonFault = val),
                ),
                const SizedBox(height: 16),
              ],

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
