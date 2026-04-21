import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/bs5839_system_config.dart';
import '../../services/auth_service.dart';
import '../../services/bs5839_config_service.dart';
import '../../utils/adaptive_widgets.dart';
import '../../utils/icon_map.dart';
import '../../utils/theme.dart';
import '../../widgets/widgets.dart';

class Bs5839SystemConfigScreen extends StatefulWidget {
  final String basePath;
  final String siteId;
  final String siteName;

  const Bs5839SystemConfigScreen({
    super.key,
    required this.basePath,
    required this.siteId,
    required this.siteName,
  });

  @override
  State<Bs5839SystemConfigScreen> createState() =>
      _Bs5839SystemConfigScreenState();
}

class _Bs5839SystemConfigScreenState extends State<Bs5839SystemConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = Bs5839ConfigService.instance;
  final _authService = AuthService();

  final _responsibleNameController = TextEditingController();
  final _responsibleRoleController = TextEditingController();
  final _responsibleEmailController = TextEditingController();
  final _responsiblePhoneController = TextEditingController();
  final _categoryJustificationController = TextEditingController();
  final _panelMakeController = TextEditingController();
  final _panelModelController = TextEditingController();
  final _panelSerialController = TextEditingController();
  final _arcProviderController = TextEditingController();
  final _arcAccountRefController = TextEditingController();
  final _arcMaxTimeController = TextEditingController();
  final _numberOfZonesController = TextEditingController();

  Bs5839SystemCategory _category = Bs5839SystemCategory.l1;
  bool _hasSleepingAccommodation = false;
  bool _cyberSecurityRequired = false;
  bool _arcConnected = false;
  ArcTransmissionMethod _arcTransmissionMethod = ArcTransmissionMethod.none;
  DateTime? _originalCommissionDate;
  DateTime? _lastModificationDate;
  String? _zonePlanUrl;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isExisting = false;
  Bs5839SystemConfig? _existingConfig;

  @override
  void initState() {
    super.initState();
    _numberOfZonesController.text = '1';
    _loadConfig();
  }

  @override
  void dispose() {
    _responsibleNameController.dispose();
    _responsibleRoleController.dispose();
    _responsibleEmailController.dispose();
    _responsiblePhoneController.dispose();
    _categoryJustificationController.dispose();
    _panelMakeController.dispose();
    _panelModelController.dispose();
    _panelSerialController.dispose();
    _arcProviderController.dispose();
    _arcAccountRefController.dispose();
    _arcMaxTimeController.dispose();
    _numberOfZonesController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final config = await _service.getConfig(widget.basePath, widget.siteId);
    if (!mounted) return;

    if (config != null) {
      _existingConfig = config;
      _isExisting = true;
      _category = config.category;
      _categoryJustificationController.text =
          config.categoryJustification ?? '';
      _responsibleNameController.text = config.responsiblePersonName;
      _responsibleRoleController.text = config.responsiblePersonRole ?? '';
      _responsibleEmailController.text = config.responsiblePersonEmail ?? '';
      _responsiblePhoneController.text = config.responsiblePersonPhone ?? '';
      _hasSleepingAccommodation = config.hasSleepingAccommodation;
      _numberOfZonesController.text = config.numberOfZones.toString();
      _cyberSecurityRequired = config.cyberSecurityRequired;
      _panelMakeController.text = config.panelMake ?? '';
      _panelModelController.text = config.panelModel ?? '';
      _panelSerialController.text = config.panelSerialNumber ?? '';
      _arcConnected = config.arcConnected;
      _arcTransmissionMethod = config.arcTransmissionMethod;
      _arcProviderController.text = config.arcProvider ?? '';
      _arcAccountRefController.text = config.arcAccountRef ?? '';
      _arcMaxTimeController.text =
          config.arcMaxTransmissionTimeSeconds?.toString() ?? '';
      _originalCommissionDate = config.originalCommissionDate;
      _lastModificationDate = config.lastModificationDate;
      _zonePlanUrl = config.zonePlanUrl;
    }

    setState(() => _isLoading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = _authService.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final numberOfZones =
          int.tryParse(_numberOfZonesController.text) ?? 1;
      final arcMaxTime = _arcConnected
          ? int.tryParse(_arcMaxTimeController.text)
          : null;

      final config = Bs5839SystemConfig(
        id: 'current',
        siteId: widget.siteId,
        category: _category,
        categoryJustification:
            _categoryJustificationController.text.trim().isEmpty
                ? null
                : _categoryJustificationController.text.trim(),
        responsiblePersonName: _responsibleNameController.text.trim(),
        responsiblePersonRole:
            _responsibleRoleController.text.trim().isEmpty
                ? null
                : _responsibleRoleController.text.trim(),
        responsiblePersonEmail:
            _responsibleEmailController.text.trim().isEmpty
                ? null
                : _responsibleEmailController.text.trim(),
        responsiblePersonPhone:
            _responsiblePhoneController.text.trim().isEmpty
                ? null
                : _responsiblePhoneController.text.trim(),
        originalCommissionDate: _originalCommissionDate,
        lastModificationDate: _lastModificationDate,
        arcConnected: _arcConnected,
        arcTransmissionMethod:
            _arcConnected ? _arcTransmissionMethod : ArcTransmissionMethod.none,
        arcProvider: _arcConnected
            ? (_arcProviderController.text.trim().isEmpty
                ? null
                : _arcProviderController.text.trim())
            : null,
        arcAccountRef: _arcConnected
            ? (_arcAccountRefController.text.trim().isEmpty
                ? null
                : _arcAccountRefController.text.trim())
            : null,
        arcMaxTransmissionTimeSeconds: arcMaxTime,
        zonePlanUrl: _zonePlanUrl,
        zonePlanLastReviewedAt:
            _zonePlanUrl != null ? now : _existingConfig?.zonePlanLastReviewedAt,
        hasSleepingAccommodation: _hasSleepingAccommodation,
        numberOfZones: numberOfZones,
        cyberSecurityRequired: _cyberSecurityRequired,
        panelMake: _panelMakeController.text.trim().isEmpty
            ? null
            : _panelMakeController.text.trim(),
        panelModel: _panelModelController.text.trim().isEmpty
            ? null
            : _panelModelController.text.trim(),
        panelSerialNumber: _panelSerialController.text.trim().isEmpty
            ? null
            : _panelSerialController.text.trim(),
        createdAt: _existingConfig?.createdAt ?? now,
        updatedAt: now,
        createdBy: _existingConfig?.createdBy ?? user.uid,
        updatedBy: user.uid,
      );

      await _service.saveConfig(widget.basePath, widget.siteId, config);

      final findings = await _service.detectProhibitedVariations(
        basePath: widget.basePath,
        siteId: widget.siteId,
        config: config,
      );

      if (findings.isNotEmpty && mounted) {
        await _service.autoCreateProhibitedVariations(
          basePath: widget.basePath,
          siteId: widget.siteId,
          findings: findings,
          engineerId: user.uid,
          engineerName: user.displayName ?? 'Unknown',
        );

        if (mounted) {
          _showProhibitedVariationsDialog(findings);
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('BS 5839 configuration saved')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showProhibitedVariationsDialog(
      List<ProhibitedVariationFinding> findings) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(AppIcons.warning, color: Colors.red.shade400, size: 22),
            const SizedBox(width: 8),
            const Text('Prohibited Variations Detected'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The following prohibited variations have been '
                'auto-logged. The site cannot be declared satisfactory '
                'until these are resolved.',
              ),
              const SizedBox(height: 12),
              ...findings.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            f.rule.clauseReference,
                            style: TextStyle(
                              color: Colors.red.shade400,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            f.description,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(true);
            },
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickZonePlan() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() => _isSaving = true);
    try {
      final url = await _service.uploadZonePlan(
        basePath: widget.basePath,
        siteId: widget.siteId,
        fileBytes: file.bytes!,
        fileName: file.name,
      );
      setState(() => _zonePlanUrl = url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zone plan uploaded')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickDate(
    DateTime? current,
    void Function(DateTime) onPicked,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(1970),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => onPicked(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isExisting
            ? 'Edit BS 5839 Configuration'
            : 'BS 5839 Configuration'),
      ),
      body: _isLoading
          ? const Center(child: AdaptiveLoadingIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppTheme.screenPadding),
                children: [
                  _buildSectionHeader('System Category', AppIcons.category),
                  const SizedBox(height: 12),
                  _buildCategorySelector(isDark),
                  const SizedBox(height: 8),
                  CustomTextField(
                    controller: _categoryJustificationController,
                    label: 'Category Justification',
                    maxLines: 2,
                  ),
                  const SizedBox(height: AppTheme.sectionGap),
                  _buildSectionHeader(
                      'Responsible Person', AppIcons.profile),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _responsibleNameController,
                    label: 'Name',
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _responsibleRoleController,
                    label: 'Role',
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _responsibleEmailController,
                    label: 'Email',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _responsiblePhoneController,
                    label: 'Phone',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: AppTheme.sectionGap),
                  _buildSectionHeader(
                      'Building Characteristics', AppIcons.building),
                  const SizedBox(height: 12),
                  _buildSwitchTile(
                    'Sleeping Accommodation',
                    'Building contains rooms used for sleeping',
                    _hasSleepingAccommodation,
                    (v) => setState(
                        () => _hasSleepingAccommodation = v),
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _numberOfZonesController,
                    label: 'Number of Zones',
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      final n = int.tryParse(v);
                      if (n == null || n < 1) return 'Must be at least 1';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppTheme.sectionGap),
                  _buildSectionHeader('Panel Details', AppIcons.cpu),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _panelMakeController,
                    label: 'Panel Make',
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _panelModelController,
                    label: 'Panel Model',
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _panelSerialController,
                    label: 'Serial Number',
                  ),
                  const SizedBox(height: 12),
                  _buildSwitchTile(
                    'Remote Access / Network Connected',
                    'Panel has network/remote access (triggers cyber security checks)',
                    _cyberSecurityRequired,
                    (v) => setState(() => _cyberSecurityRequired = v),
                  ),
                  const SizedBox(height: AppTheme.sectionGap),
                  _buildSectionHeader('ARC Connection', AppIcons.wifi),
                  const SizedBox(height: 12),
                  _buildSwitchTile(
                    'Connected to ARC',
                    'Alarm Receiving Centre connection',
                    _arcConnected,
                    (v) => setState(() => _arcConnected = v),
                  ),
                  if (_arcConnected) ...[
                    const SizedBox(height: 12),
                    _buildArcTransmissionMethodSelector(isDark),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: _arcProviderController,
                      label: 'ARC Provider',
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: _arcAccountRefController,
                      label: 'Account Reference',
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: _arcMaxTimeController,
                      label: 'Max Transmission Time (seconds)',
                      keyboardType: TextInputType.number,
                    ),
                  ],
                  const SizedBox(height: AppTheme.sectionGap),
                  _buildSectionHeader('Dates', AppIcons.calendar),
                  const SizedBox(height: 12),
                  _buildDateTile(
                    'Original Commission Date',
                    _originalCommissionDate,
                    (d) => _originalCommissionDate = d,
                  ),
                  const SizedBox(height: 12),
                  _buildDateTile(
                    'Last Modification Date',
                    _lastModificationDate,
                    (d) => _lastModificationDate = d,
                  ),
                  const SizedBox(height: AppTheme.sectionGap),
                  _buildSectionHeader('Zone Plan', AppIcons.map),
                  const SizedBox(height: 12),
                  _buildZonePlanSection(isDark),
                  const SizedBox(height: AppTheme.sectionGap),
                  _buildSaveButton(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryBlue),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  Widget _buildCategorySelector(bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: Bs5839SystemCategory.values.map((cat) {
        final selected = _category == cat;
        return ChoiceChip(
          label: Text(cat.name.toUpperCase()),
          selected: selected,
          onSelected: (_) => setState(() => _category = cat),
          selectedColor: AppTheme.primaryBlue.withValues(alpha: 0.2),
          labelStyle: TextStyle(
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected
                ? AppTheme.primaryBlue
                : (isDark ? Colors.white70 : Colors.black87),
            fontSize: 13,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildArcTransmissionMethodSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transmission Method',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.white60 : Colors.black54,
              ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ArcTransmissionMethod.values
              .where((m) => m != ArcTransmissionMethod.none)
              .map((method) {
            final selected = _arcTransmissionMethod == method;
            return ChoiceChip(
              label: Text(method.displayLabel),
              selected: selected,
              onSelected: (_) =>
                  setState(() => _arcTransmissionMethod = method),
              selectedColor: AppTheme.primaryBlue.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
                color: selected
                    ? AppTheme.primaryBlue
                    : (isDark ? Colors.white70 : Colors.black87),
                fontSize: 12,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              Text(
                subtitle,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
        AdaptiveSwitch(value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _buildDateTile(
    String label,
    DateTime? value,
    void Function(DateTime) onPicked,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => _pickDate(value, onPicked),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark ? Colors.white24 : Colors.black12,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value != null
                        ? '${value.day}/${value.month}/${value.year}'
                        : 'Not set',
                    style: TextStyle(
                      color: value != null
                          ? null
                          : (isDark ? Colors.white38 : Colors.black38),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              AppIcons.calendar,
              size: 18,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZonePlanSection(bool isDark) {
    if (_zonePlanUrl != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              _zonePlanUrl!,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                height: 80,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Zone plan uploaded'),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: _pickZonePlan,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Replace'),
              ),
              TextButton.icon(
                onPressed: () async {
                  await _service.deleteZonePlan(
                    basePath: widget.basePath,
                    siteId: widget.siteId,
                  );
                  setState(() => _zonePlanUrl = null);
                },
                icon: Icon(Icons.delete_outline,
                    size: 16, color: Colors.red.shade400),
                label: Text('Remove',
                    style: TextStyle(color: Colors.red.shade400)),
              ),
            ],
          ),
        ],
      );
    }

    return OutlinedButton.icon(
      onPressed: _pickZonePlan,
      icon: const Icon(AppIcons.documentUpload, size: 18),
      label: const Text('Upload Zone Plan'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
      ),
    );
  }

  Widget _buildSaveButton() {
    return AnimatedSaveButton(
      onPressed: _save,
      enabled: !_isSaving,
      label: _isExisting ? 'Update Configuration' : 'Save Configuration',
    );
  }
}
