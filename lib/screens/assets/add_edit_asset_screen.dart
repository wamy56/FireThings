import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/asset.dart';
import '../../models/asset_type.dart';
import '../../data/default_asset_types.dart';
import '../../services/asset_service.dart';
import '../../services/asset_type_service.dart';
import '../../services/analytics_service.dart';
import '../../services/auth_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../widgets/widgets.dart';

class AddEditAssetScreen extends StatefulWidget {
  final String basePath;
  final String siteId;
  final Asset? asset; // null = create, non-null = edit
  final String? presetFloorPlanId;
  final double? presetXPercent;
  final double? presetYPercent;

  const AddEditAssetScreen({
    super.key,
    required this.basePath,
    required this.siteId,
    this.asset,
    this.presetFloorPlanId,
    this.presetXPercent,
    this.presetYPercent,
  });

  @override
  State<AddEditAssetScreen> createState() => _AddEditAssetScreenState();
}

class _AddEditAssetScreenState extends State<AddEditAssetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  // Controllers
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _serialController = TextEditingController();
  final _referenceController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _zoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();

  // State
  List<AssetType> _assetTypes = [];
  String? _selectedTypeId;
  String? _selectedVariant;
  DateTime? _installDate;
  DateTime? _warrantyExpiry;
  int? _expectedLifespan;
  bool _isSaving = false;

  bool get _isEditing => widget.asset != null;

  @override
  void initState() {
    super.initState();
    _loadAssetTypes();
    if (_isEditing) {
      _populateFields(widget.asset!);
    }
  }

  @override
  void dispose() {
    _makeController.dispose();
    _modelController.dispose();
    _serialController.dispose();
    _referenceController.dispose();
    _barcodeController.dispose();
    _zoneController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _populateFields(Asset asset) {
    _selectedTypeId = asset.assetTypeId;
    _selectedVariant = asset.variant;
    _makeController.text = asset.make ?? '';
    _modelController.text = asset.model ?? '';
    _serialController.text = asset.serialNumber ?? '';
    _referenceController.text = asset.reference ?? '';
    _barcodeController.text = asset.barcode ?? '';
    _zoneController.text = asset.zone ?? '';
    _locationController.text = asset.locationDescription ?? '';
    _notesController.text = asset.notes ?? '';
    _installDate = asset.installDate;
    _warrantyExpiry = asset.warrantyExpiry;
    _expectedLifespan = asset.expectedLifespanYears;
  }

  Future<void> _loadAssetTypes() async {
    final types =
        await AssetTypeService.instance.getAssetTypes(widget.basePath);
    if (mounted) {
      setState(() => _assetTypes = types);
      // Auto-suggest reference if creating
      if (!_isEditing && _selectedTypeId != null) {
        _suggestReference();
      }
    }
  }

  AssetType? get _selectedType {
    if (_selectedTypeId == null) return null;
    try {
      return _assetTypes.firstWhere((t) => t.id == _selectedTypeId);
    } catch (_) {
      return DefaultAssetTypes.getById(_selectedTypeId!);
    }
  }

  void _onTypeChanged(String? typeId) {
    setState(() {
      _selectedTypeId = typeId;
      _selectedVariant = null;
      final type = _selectedType;
      if (type != null) {
        _expectedLifespan = type.defaultLifespanYears;
      }
    });
    if (!_isEditing) _suggestReference();
  }

  Future<void> _suggestReference() async {
    if (_selectedTypeId == null) return;
    final prefix = _getRefPrefix(_selectedTypeId!);
    final ref = await AssetService.instance
        .suggestNextReference(widget.basePath, widget.siteId, prefix);
    if (mounted && _referenceController.text.isEmpty) {
      _referenceController.text = ref;
    }
  }

  String _getRefPrefix(String typeId) {
    switch (typeId) {
      case 'fire_alarm_panel': return 'FAP';
      case 'smoke_detector': return 'SD';
      case 'heat_detector': return 'HD';
      case 'call_point': return 'CP';
      case 'sounder_beacon': return 'SB';
      case 'fire_extinguisher': return 'FE';
      case 'emergency_lighting': return 'EL';
      case 'fire_door': return 'FD';
      case 'aov_smoke_vent': return 'AV';
      case 'sprinkler_head': return 'SH';
      case 'fire_blanket': return 'FB';
      default: return 'AST';
    }
  }

  Future<void> _pickDate({required bool isInstallDate}) async {
    final initial = isInstallDate
        ? (_installDate ?? DateTime.now())
        : (_warrantyExpiry ?? DateTime.now().add(const Duration(days: 365)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2050),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isInstallDate) {
          _installDate = picked;
        } else {
          _warrantyExpiry = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTypeId == null) {
      context.showWarningToast('Please select an asset type');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception('Not signed in');
      final now = DateTime.now();

      final asset = Asset(
        id: _isEditing ? widget.asset!.id : const Uuid().v4(),
        siteId: widget.siteId,
        assetTypeId: _selectedTypeId!,
        variant: _selectedVariant,
        make: _makeController.text.trim().isEmpty
            ? null
            : _makeController.text.trim(),
        model: _modelController.text.trim().isEmpty
            ? null
            : _modelController.text.trim(),
        serialNumber: _serialController.text.trim().isEmpty
            ? null
            : _serialController.text.trim(),
        reference: _referenceController.text.trim().isEmpty
            ? null
            : _referenceController.text.trim(),
        barcode: _barcodeController.text.trim().isEmpty
            ? null
            : _barcodeController.text.trim(),
        zone: _zoneController.text.trim().isEmpty
            ? null
            : _zoneController.text.trim(),
        locationDescription: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        installDate: _installDate,
        warrantyExpiry: _warrantyExpiry,
        expectedLifespanYears: _expectedLifespan,
        complianceStatus: _isEditing
            ? widget.asset!.complianceStatus
            : Asset.statusUntested,
        createdBy: _isEditing ? widget.asset!.createdBy : user.uid,
        createdAt: _isEditing ? widget.asset!.createdAt : now,
        updatedAt: now,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        lastModifiedAt: now,
        // Preserve existing fields when editing, or use preset from floor plan placement
        floorPlanId: _isEditing
            ? widget.asset!.floorPlanId
            : widget.presetFloorPlanId,
        xPercent: _isEditing
            ? widget.asset!.xPercent
            : widget.presetXPercent,
        yPercent: _isEditing
            ? widget.asset!.yPercent
            : widget.presetYPercent,
        lastServiceDate: _isEditing ? widget.asset!.lastServiceDate : null,
        lastServiceBy: _isEditing ? widget.asset!.lastServiceBy : null,
        lastServiceByName:
            _isEditing ? widget.asset!.lastServiceByName : null,
        nextServiceDue: _isEditing ? widget.asset!.nextServiceDue : null,
        photoUrl: _isEditing ? widget.asset!.photoUrl : null,
      );

      if (_isEditing) {
        await AssetService.instance
            .updateAsset(widget.basePath, widget.siteId, asset);
        AnalyticsService.instance
            .logAssetEdited(assetType: asset.assetTypeId);
      } else {
        await AssetService.instance
            .createAsset(widget.basePath, widget.siteId, asset);
        AnalyticsService.instance.logAssetCreated(
          assetType: asset.assetTypeId,
          siteId: widget.siteId,
          hasBarcode: asset.barcode != null,
        );
      }

      if (mounted) {
        context.showSuccessToast(
            _isEditing ? 'Asset updated' : 'Asset added');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        context.showErrorToast('Failed to save asset');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final variants = _selectedType?.variants ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Asset' : 'Add Asset'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: KeyboardDismissWrapper(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppTheme.screenPadding),
            children: [
              // Asset Type
              _SectionTitle('Asset Type'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedTypeId,
                decoration: InputDecoration(
                  labelText: 'Asset Type *',
                  prefixIcon: Icon(
                    _selectedType != null
                        ? _iconForType(_selectedType)
                        : AppIcons.category,
                  ),
                ),
                items: _assetTypes
                    .map((t) => DropdownMenuItem(
                          value: t.id,
                          child: Text(t.name),
                        ))
                    .toList(),
                onChanged: _onTypeChanged,
                validator: (v) =>
                    v == null ? 'Please select an asset type' : null,
              ),
              if (variants.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedVariant,
                  decoration: const InputDecoration(
                    labelText: 'Variant',
                    prefixIcon: Icon(AppIcons.layer),
                  ),
                  items: variants
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedVariant = v),
                ),
              ],

              const SizedBox(height: AppTheme.sectionGap),

              // Identity
              _SectionTitle('Identity'),
              const SizedBox(height: 8),
              CustomTextField(
                controller: _makeController,
                label: 'Make / Manufacturer',
                prefixIcon: const Icon(AppIcons.building),
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _modelController,
                label: 'Model',
                prefixIcon: const Icon(AppIcons.tag),
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _serialController,
                label: 'Serial Number',
                prefixIcon: const Icon(AppIcons.clipboard),
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _referenceController,
                label: 'Reference (e.g. SD-001)',
                prefixIcon: const Icon(AppIcons.document),
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _barcodeController,
                label: 'Barcode / QR Code',
                prefixIcon: const Icon(AppIcons.scanner),
              ),

              const SizedBox(height: AppTheme.sectionGap),

              // Location
              _SectionTitle('Location'),
              const SizedBox(height: 8),
              CustomTextField(
                controller: _zoneController,
                label: 'Zone',
                prefixIcon: const Icon(AppIcons.map),
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _locationController,
                label: 'Location Description',
                prefixIcon: const Icon(AppIcons.location),
                maxLines: 2,
              ),

              const SizedBox(height: AppTheme.sectionGap),

              // Dates & Lifecycle
              _SectionTitle('Dates & Lifecycle'),
              const SizedBox(height: 8),
              _DatePickerTile(
                label: 'Install Date',
                value: _installDate,
                onTap: () => _pickDate(isInstallDate: true),
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _DatePickerTile(
                label: 'Warranty Expiry',
                value: _warrantyExpiry,
                onTap: () => _pickDate(isInstallDate: false),
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: TextEditingController(
                    text: _expectedLifespan?.toString() ?? ''),
                label: 'Expected Lifespan (years)',
                prefixIcon: const Icon(AppIcons.clock),
                keyboardType: TextInputType.number,
                onChanged: (v) =>
                    _expectedLifespan = int.tryParse(v),
              ),

              const SizedBox(height: AppTheme.sectionGap),

              // Notes
              _SectionTitle('Notes'),
              const SizedBox(height: 8),
              CustomTextField(
                controller: _notesController,
                label: 'Notes (optional)',
                prefixIcon: const Icon(AppIcons.note),
                maxLines: 3,
              ),

              const SizedBox(height: 100), // Bottom padding for FAB
            ],
          ),
        ),
      ),
    );
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
      default: return AppIcons.setting;
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : AppTheme.textPrimary,
      ),
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final bool isDark;

  const _DatePickerTile({
    required this.label,
    required this.value,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(AppIcons.calendar),
          suffixIcon: const Icon(AppIcons.arrowDown, size: 18),
        ),
        child: Text(
          value != null
              ? '${value!.day}/${value!.month}/${value!.year}'
              : 'Not set',
          style: TextStyle(
            color: value != null
                ? (isDark ? Colors.white : AppTheme.textPrimary)
                : (isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
          ),
        ),
      ),
    );
  }
}
