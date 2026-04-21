import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/bs5839_2025_reference.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../data/prohibited_variation_rules.dart';
import '../../models/asset.dart';
import '../../models/bs5839_variation.dart';
import '../../services/bs5839_config_service.dart';
import '../../services/variation_service.dart';
import '../../utils/icon_map.dart';
import '../../utils/theme.dart';
import '../../widgets/widgets.dart';

class AddEditVariationScreen extends StatefulWidget {
  final String basePath;
  final String siteId;
  final Bs5839Variation? variation;

  const AddEditVariationScreen({
    super.key,
    required this.basePath,
    required this.siteId,
    this.variation,
  });

  @override
  State<AddEditVariationScreen> createState() => _AddEditVariationScreenState();
}

class _AddEditVariationScreenState extends State<AddEditVariationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = VariationService.instance;

  late final TextEditingController _clauseController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _justificationController;
  late final TextEditingController _agreedByNameController;
  late final TextEditingController _agreedByRoleController;

  DateTime? _dateAgreed;
  VariationStatus _status = VariationStatus.active;
  List<String> _evidencePhotoUrls = [];
  bool _isUploading = false;

  bool get _isEditing => widget.variation != null;

  @override
  void initState() {
    super.initState();
    final v = widget.variation;
    _clauseController = TextEditingController(text: v?.clauseReference ?? '');
    _descriptionController = TextEditingController(text: v?.description ?? '');
    _justificationController =
        TextEditingController(text: v?.justification ?? '');
    _agreedByNameController =
        TextEditingController(text: v?.agreedByName ?? '');
    _agreedByRoleController =
        TextEditingController(text: v?.agreedByRole ?? '');
    _dateAgreed = v?.dateAgreed;
    _status = v?.status ?? VariationStatus.active;
    _evidencePhotoUrls = List.from(v?.evidencePhotoUrls ?? []);
  }

  @override
  void dispose() {
    _clauseController.dispose();
    _descriptionController.dispose();
    _justificationController.dispose();
    _agreedByNameController.dispose();
    _agreedByRoleController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final id = _isEditing
        ? widget.variation!.id
        : _service.generateId(widget.basePath, widget.siteId);

    var variation = Bs5839Variation(
      id: id,
      siteId: widget.siteId,
      clauseReference: _clauseController.text.trim(),
      description: _descriptionController.text.trim(),
      justification: _justificationController.text.trim(),
      isProhibited: widget.variation?.isProhibited ?? false,
      prohibitedRuleId: widget.variation?.prohibitedRuleId,
      status: _status,
      agreedByName: _agreedByNameController.text.trim().isNotEmpty
          ? _agreedByNameController.text.trim()
          : null,
      agreedByRole: _agreedByRoleController.text.trim().isNotEmpty
          ? _agreedByRoleController.text.trim()
          : null,
      dateAgreed: _dateAgreed,
      loggedByEngineerId:
          widget.variation?.loggedByEngineerId ?? user.uid,
      loggedByEngineerName:
          widget.variation?.loggedByEngineerName ?? user.displayName,
      loggedAt: widget.variation?.loggedAt ?? now,
      rectifiedAt: _status == VariationStatus.rectified
          ? (widget.variation?.rectifiedAt ?? now)
          : null,
      rectifiedByVisitId: widget.variation?.rectifiedByVisitId,
      evidencePhotoUrls: _evidencePhotoUrls,
    );

    if (!_isEditing) {
      final isProhibited = await _checkProhibitedRules(variation);
      if (isProhibited != null) {
        variation = variation.copyWith(
          isProhibited: true,
          prohibitedRuleId: isProhibited,
        );
      }
    }

    await _service.saveVariation(widget.basePath, widget.siteId, variation);

    if (!_isEditing && variation.isProhibited && mounted) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(AppIcons.danger, color: Colors.red.shade400),
              const SizedBox(width: 8),
              const Expanded(child: Text('Prohibited Variation')),
            ],
          ),
          content: Text(
            'This variation matches a prohibited rule under '
            '${variation.clauseReference}. The site cannot be declared '
            'satisfactory until this is remediated.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }

    if (mounted) Navigator.pop(context);
  }

  Future<String?> _checkProhibitedRules(Bs5839Variation variation) async {
    final configService = Bs5839ConfigService.instance;
    final config = await configService.getConfig(
        widget.basePath, widget.siteId);
    if (config == null) return null;

    for (final rule in ProhibitedVariationRules.all) {
      if (rule.clauseReference == variation.clauseReference) {
        if (!rule.check(config, const <Asset>[])) {
          return rule.id;
        }
      }
    }
    return null;
  }

  Future<void> _pickEvidence() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) return;

    final variationId = _isEditing
        ? widget.variation!.id
        : _service.generateId(widget.basePath, widget.siteId);

    setState(() => _isUploading = true);
    try {
      for (final file in result.files) {
        if (file.bytes == null) continue;
        final url = await _service.uploadEvidencePhoto(
          basePath: widget.basePath,
          siteId: widget.siteId,
          variationId: variationId,
          fileBytes: file.bytes!,
          fileName: file.name,
        );
        setState(() => _evidencePhotoUrls.add(url));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _removePhoto(String url) async {
    if (!_isEditing) {
      setState(() => _evidencePhotoUrls.remove(url));
      return;
    }

    await _service.removeEvidencePhoto(
      basePath: widget.basePath,
      siteId: widget.siteId,
      variationId: widget.variation!.id,
      photoUrl: url,
    );
    setState(() => _evidencePhotoUrls.remove(url));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateAgreed ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _dateAgreed = picked);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isProhibited =
        widget.variation?.isProhibited == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Variation' : 'Add Variation'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          children: [
            if (isProhibited)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.red.shade400.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(AppIcons.danger,
                        color: Colors.red.shade400, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This is a prohibited variation — site cannot be declared satisfactory.',
                        style: TextStyle(
                          color: Colors.red.shade400,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            _buildClauseField(),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _descriptionController,
              label: 'Description',
              maxLines: 3,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _justificationController,
              label: 'Justification',
              maxLines: 3,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: AppTheme.sectionGap),
            Text('Agreed By',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _agreedByNameController,
              label: 'Name',
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _agreedByRoleController,
              label: 'Role',
            ),
            const SizedBox(height: 12),
            _buildDateTile(isDark),
            const SizedBox(height: AppTheme.sectionGap),
            Text('Status',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _buildStatusSelector(isDark),
            const SizedBox(height: AppTheme.sectionGap),
            Text('Evidence Photos',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _buildEvidenceSection(isDark),
            const SizedBox(height: 32),
            AnimatedSaveButton(
              onPressed: _save,
              label: _isEditing ? 'Update Variation' : 'Save Variation',
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildClauseField() {
    return Autocomplete<Bs5839ClauseReference>(
      initialValue: TextEditingValue(text: _clauseController.text),
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) return const [];
        return Bs58392025Reference.search(textEditingValue.text).take(5);
      },
      displayStringForOption: (option) => option.clause,
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        _clauseController.text = controller.text;
        return CustomTextField(
          controller: controller,
          focusNode: focusNode,
          label: 'Clause Reference',
          hint: 'e.g. 6.6, 25.4',
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Required' : null,
          onChanged: (v) => _clauseController.text = v,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 400),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(
                      '${option.clause} — ${option.title}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(
                      option.summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDateTile(bool isDark) {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  Text('Date Agreed',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey)),
                  const SizedBox(height: 2),
                  Text(
                    _dateAgreed != null
                        ? DateFormat('dd MMM yyyy').format(_dateAgreed!)
                        : 'Not set',
                    style: const TextStyle(fontSize: 15),
                  ),
                ],
              ),
            ),
            const Icon(AppIcons.calendar, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSelector(bool isDark) {
    return Wrap(
      spacing: 8,
      children: VariationStatus.values.map((s) {
        final selected = _status == s;
        return ChoiceChip(
          label: Text(s.displayLabel),
          selected: selected,
          onSelected: (v) {
            if (v) setState(() => _status = s);
          },
        );
      }).toList(),
    );
  }

  Widget _buildEvidenceSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_evidencePhotoUrls.isNotEmpty) ...[
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _evidencePhotoUrls.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final url = _evidencePhotoUrls[index];
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        url,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 100,
                          height: 100,
                          color: isDark ? Colors.white10 : Colors.grey.shade100,
                          child: const Icon(AppIcons.image, size: 24),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _removePhoto(url),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          onPressed: _isUploading ? null : _pickEvidence,
          icon: _isUploading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(AppIcons.camera, size: 18),
          label: Text(_isUploading ? 'Uploading...' : 'Add Evidence Photo'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 44),
          ),
        ),
      ],
    );
  }
}
