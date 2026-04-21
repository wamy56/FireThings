import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../data/cause_effect_templates.dart';
import '../../models/asset.dart';
import '../../models/bs5839_system_config.dart';
import '../../models/cause_effect_test.dart';
import '../../services/asset_service.dart';
import '../../services/bs5839_config_service.dart';
import '../../services/cause_effect_service.dart';
import '../../utils/adaptive_widgets.dart';
import '../../utils/icon_map.dart';
import '../../utils/theme.dart';
import '../../widgets/widgets.dart';

class CauseEffectTestScreen extends StatefulWidget {
  final String basePath;
  final String siteId;
  final String visitId;

  const CauseEffectTestScreen({
    super.key,
    required this.basePath,
    required this.siteId,
    required this.visitId,
  });

  @override
  State<CauseEffectTestScreen> createState() => _CauseEffectTestScreenState();
}

class _CauseEffectTestScreenState extends State<CauseEffectTestScreen> {
  static const _uuid = Uuid();

  final _assetService = AssetService.instance;
  final _configService = Bs5839ConfigService.instance;
  final _ceService = CauseEffectService.instance;

  int _currentStep = 0;
  bool _isLoading = true;

  List<Asset> _assets = [];
  Bs5839SystemConfig? _config;

  // Step 1 — trigger
  Asset? _selectedTriggerAsset;
  String _triggerDescription = '';
  CauseEffectTemplateEntry? _selectedTemplate;

  // Step 2 — expected effects
  List<_EditableEffect> _effects = [];

  // Step 3 — execution results
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final assetsStream =
          _assetService.getAssetsStream(widget.basePath, widget.siteId);
      _assets = await assetsStream.first;
      _config =
          await _configService.getConfig(widget.basePath, widget.siteId);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_stepTitle),
        actions: [
          if (_currentStep > 0)
            TextButton(
              onPressed: () => setState(() => _currentStep--),
              child: const Text('Back'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: AdaptiveLoadingIndicator())
          : _buildStep(),
    );
  }

  String get _stepTitle {
    switch (_currentStep) {
      case 0:
        return 'Choose Trigger';
      case 1:
        return 'Expected Effects';
      case 2:
        return 'Execute Test';
      default:
        return 'Cause & Effect Test';
    }
  }

  Widget _buildStep() {
    switch (_currentStep) {
      case 0:
        return _buildTriggerStep();
      case 1:
        return _buildEffectsStep();
      case 2:
        return _buildExecuteStep();
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── Step 1: Choose Trigger ─────────────────────────────────────────

  Widget _buildTriggerStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final triggerAssets = _assets.where((a) => _isTriggerAssetType(a)).toList();

    return ListView(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      children: [
        Text('Select Trigger Device',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        if (triggerAssets.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'No trigger devices found in asset register. Add MCPs, detectors, or beam detectors first.',
              style: TextStyle(color: Colors.orange, fontSize: 13),
            ),
          )
        else
          ...triggerAssets.map((asset) => _buildAssetTile(asset, isDark)),
        const SizedBox(height: AppTheme.sectionGap),
        Text('Or Use Template',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        ...CauseEffectTemplates.all
            .map((t) => _buildTemplateTile(t, isDark)),
        const SizedBox(height: AppTheme.sectionGap),
        CustomTextField(
          label: 'Trigger Description',
          hint: 'e.g. Activate MCP at main entrance',
          initialValue: _triggerDescription,
          onChanged: (v) => _triggerDescription = v,
          maxLines: 2,
        ),
        const SizedBox(height: 24),
        AnimatedSaveButton(
          label: 'Next — Define Effects',
          enabled: _selectedTriggerAsset != null ||
              _selectedTemplate != null ||
              _triggerDescription.trim().isNotEmpty,
          onPressed: () async {
            _prepareEffectsFromSelection();
            setState(() => _currentStep = 1);
          },
          backgroundColor: AppTheme.primaryBlue,
        ),
      ],
    );
  }

  Widget _buildAssetTile(Asset asset, bool isDark) {
    final isSelected = _selectedTriggerAsset?.id == asset.id;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTriggerAsset = asset;
          _selectedTemplate = null;
          if (_triggerDescription.isEmpty) {
            _triggerDescription =
                'Activate ${asset.assetTypeId} — ${asset.reference ?? asset.id}';
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryBlue.withValues(alpha: 0.1)
              : (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryBlue.withValues(alpha: 0.5)
                : (isDark ? Colors.white12 : Colors.grey.shade200),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? AppIcons.tickCircle : Icons.radio_button_unchecked,
              size: 20,
              color: isSelected ? AppTheme.primaryBlue : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asset.reference ?? asset.id,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 14),
                  ),
                  Text(
                    '${asset.assetTypeId}${asset.locationDescription != null ? ' · ${asset.locationDescription}' : ''}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (asset.zone != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Z${asset.zone}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateTile(CauseEffectTemplateEntry template, bool isDark) {
    final isSelected = _selectedTemplate?.name == template.name;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTemplate = template;
          _selectedTriggerAsset = null;
          _triggerDescription = template.triggerDescription;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryBlue.withValues(alpha: 0.1)
              : (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryBlue.withValues(alpha: 0.5)
                : (isDark ? Colors.white12 : Colors.grey.shade200),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? AppIcons.tickCircle : Icons.radio_button_unchecked,
              size: 20,
              color: isSelected ? AppTheme.primaryBlue : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 14),
                  ),
                  Text(
                    '${template.expectedEffectTypes.length} expected effects',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isTriggerAssetType(Asset asset) {
    final type = asset.assetTypeId.toLowerCase();
    return type.contains('call_point') ||
        type.contains('mcp') ||
        type.contains('smoke_detector') ||
        type.contains('heat_detector') ||
        type.contains('beam_detector') ||
        type.contains('multi_sensor') ||
        type.contains('flame_detector');
  }

  void _prepareEffectsFromSelection() {
    if (_effects.isNotEmpty) return;

    List<EffectType> effectTypes = [];

    if (_selectedTemplate != null) {
      effectTypes = _selectedTemplate!.expectedEffectTypes;
    } else if (_selectedTriggerAsset != null && _config != null) {
      final defaults =
          CauseEffectTemplates.mcpDefaultEffects[_config!.category];
      if (defaults != null) {
        effectTypes = defaults;
      } else {
        effectTypes = [
          EffectType.sounderActivation,
          EffectType.beaconActivation,
        ];
        if (_config!.arcConnected) {
          effectTypes.add(EffectType.arcSignalFire);
        }
      }
    }

    _effects = effectTypes
        .map((type) => _EditableEffect(
              id: _uuid.v4(),
              effectType: type,
              expectedBehaviour: _defaultBehaviour(type),
            ))
        .toList();
  }

  String _defaultBehaviour(EffectType type) {
    switch (type) {
      case EffectType.sounderActivation:
        return 'All sounders activate';
      case EffectType.beaconActivation:
        return 'All beacons flash';
      case EffectType.voiceAlarmMessage:
        return 'Evacuation message plays';
      case EffectType.aovOpen:
        return 'AOV opens';
      case EffectType.doorHoldOpenRelease:
        return 'Door releases and closes';
      case EffectType.liftHomingGroundFloor:
        return 'Lift homes to ground floor';
      case EffectType.liftHomingOtherFloor:
        return 'Lift homes to designated floor';
      case EffectType.gasShutoff:
        return 'Gas supply shuts off';
      case EffectType.ventilationShutdown:
        return 'Ventilation system shuts down';
      case EffectType.arcSignalFire:
        return 'Fire signal received at ARC';
      case EffectType.arcSignalFault:
        return 'Fault signal received at ARC';
      case EffectType.arcSignalPreAlarm:
        return 'Pre-alarm signal received at ARC';
      case EffectType.bmsSignal:
        return 'BMS receives fire signal';
      case EffectType.sprinklerRelease:
        return 'Sprinkler head releases';
      case EffectType.smokeCurtainDeploy:
        return 'Smoke curtain deploys';
      case EffectType.otherInterface:
        return '';
    }
  }

  // ─── Step 2: Define Expected Effects ────────────────────────────────

  Widget _buildEffectsStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppTheme.screenPadding),
            children: [
              Text(
                'Define what should happen when the trigger is activated.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ..._effects.asMap().entries.map(
                  (entry) => _buildEffectEditor(entry.key, entry.value, isDark)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _addEffect,
                icon: const Icon(AppIcons.add, size: 18),
                label: const Text('Add Effect'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          child: AnimatedSaveButton(
            label: 'Next — Execute Test',
            enabled: _effects.isNotEmpty,
            onPressed: () async {
              setState(() => _currentStep = 2);
            },
            backgroundColor: AppTheme.primaryBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildEffectEditor(int index, _EditableEffect effect, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Effect ${index + 1}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              if (_effects.length > 1)
                IconButton(
                  icon: Icon(AppIcons.trash,
                      size: 16, color: Colors.red.shade400),
                  onPressed: () =>
                      setState(() => _effects.removeAt(index)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<EffectType>(
            initialValue: effect.effectType,
            decoration: InputDecoration(
              labelText: 'Effect Type',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: EffectType.values
                .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e.displayLabel, style: const TextStyle(fontSize: 14)),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  _effects[index] = effect.copyWith(
                    effectType: v,
                    expectedBehaviour: effect.expectedBehaviour.isEmpty
                        ? _defaultBehaviour(v)
                        : effect.expectedBehaviour,
                  );
                });
              }
            },
          ),
          const SizedBox(height: 10),
          CustomTextField(
            label: 'Expected Behaviour',
            hint: 'What should happen?',
            initialValue: effect.expectedBehaviour,
            onChanged: (v) {
              _effects[index] = effect.copyWith(expectedBehaviour: v);
            },
          ),
          const SizedBox(height: 10),
          CustomTextField(
            label: 'Target Description',
            hint: 'e.g. All sounders on floor 2',
            initialValue: effect.targetDescription ?? '',
            onChanged: (v) {
              _effects[index] = effect.copyWith(
                  targetDescription: v.isEmpty ? null : v);
            },
          ),
        ],
      ),
    );
  }

  void _addEffect() {
    setState(() {
      _effects.add(_EditableEffect(
        id: _uuid.v4(),
        effectType: EffectType.sounderActivation,
        expectedBehaviour: _defaultBehaviour(EffectType.sounderActivation),
      ));
    });
  }

  // ─── Step 3: Execute Test ───────────────────────────────────────────

  Widget _buildExecuteStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppTheme.screenPadding),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(AppIcons.flash,
                        size: 18, color: AppTheme.primaryBlue),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _triggerDescription.isNotEmpty
                            ? _triggerDescription
                            : 'Trigger device',
                        style: TextStyle(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ..._effects.asMap().entries.map((entry) =>
                  _buildExecutionCard(entry.key, entry.value, isDark)),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _notesController,
                label: 'Test Notes',
                hint: 'Any additional observations',
                maxLines: 3,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          child: AnimatedSaveButton(
            label: 'Save Test Results',
            onPressed: _saveTest,
            backgroundColor: AppTheme.primaryBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildExecutionCard(int index, _EditableEffect effect, bool isDark) {
    final isArc = effect.effectType == EffectType.arcSignalFire ||
        effect.effectType == EffectType.arcSignalFault ||
        effect.effectType == EffectType.arcSignalPreAlarm;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: effect.passed
            ? Colors.green.withValues(alpha: 0.05)
            : (isDark
                ? Colors.white.withValues(alpha: 0.02)
                : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: effect.passed
              ? Colors.green.withValues(alpha: 0.3)
              : (isDark ? Colors.white12 : Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  effect.effectType.displayLabel,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _effects[index] =
                        effect.copyWith(passed: !effect.passed);
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: effect.passed
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    effect.passed ? 'Pass' : 'Fail',
                    style: TextStyle(
                      color: effect.passed ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Expected: ${effect.expectedBehaviour}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 10),
          CustomTextField(
            label: 'Actual Behaviour',
            hint: 'What actually happened?',
            initialValue: effect.actualBehaviour ?? '',
            onChanged: (v) {
              _effects[index] =
                  effect.copyWith(actualBehaviour: v.isEmpty ? null : v);
            },
          ),
          if (isArc) ...[
            const SizedBox(height: 10),
            CustomTextField(
              label: 'Transmission Time (seconds)',
              hint: 'e.g. 30',
              initialValue: effect.measuredTimeSeconds?.toString() ?? '',
              keyboardType: TextInputType.number,
              onChanged: (v) {
                _effects[index] = effect.copyWith(
                    measuredTimeSeconds: int.tryParse(v));
              },
            ),
          ],
          if (effect.effectType == EffectType.otherInterface) ...[
            const SizedBox(height: 10),
            CustomTextField(
              label: 'Notes',
              hint: 'Describe the interface',
              initialValue: effect.notes ?? '',
              onChanged: (v) {
                _effects[index] =
                    effect.copyWith(notes: v.isEmpty ? null : v);
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _saveTest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final testId =
        _ceService.generateId(widget.basePath, widget.siteId);

    final expectedEffects = _effects
        .map((e) => ExpectedEffect(
              id: e.id,
              effectType: e.effectType,
              targetDescription: e.targetDescription,
              expectedBehaviour: e.expectedBehaviour,
              actualBehaviour: e.actualBehaviour,
              measuredTimeSeconds: e.measuredTimeSeconds,
              passed: e.passed,
              notes: e.notes,
            ))
        .toList();

    final overallPassed = expectedEffects.every((e) => e.passed);

    final test = CauseEffectTest(
      id: testId,
      siteId: widget.siteId,
      visitId: widget.visitId,
      triggerAssetId: _selectedTriggerAsset?.id ?? '',
      triggerAssetReference:
          _selectedTriggerAsset?.reference ?? _selectedTemplate?.name ?? '',
      triggerDescription: _triggerDescription,
      expectedEffects: expectedEffects,
      testedAt: DateTime.now(),
      testedByEngineerId: user.uid,
      testedByEngineerName: user.displayName ?? 'Unknown',
      overallPassed: overallPassed,
      notes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
    );

    await _ceService.saveTest(widget.basePath, widget.siteId, test);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(overallPassed
              ? 'Test saved — all effects passed'
              : 'Test saved — some effects failed'),
        ),
      );
      Navigator.of(context).pop();
    }
  }
}

class _EditableEffect {
  final String id;
  final EffectType effectType;
  final String? targetAssetId;
  final String? targetDescription;
  final String expectedBehaviour;
  final String? actualBehaviour;
  final int? measuredTimeSeconds;
  final bool passed;
  final String? notes;

  _EditableEffect({
    required this.id,
    required this.effectType,
    this.targetAssetId,
    this.targetDescription,
    required this.expectedBehaviour,
    this.actualBehaviour,
    this.measuredTimeSeconds,
    this.passed = false,
    this.notes,
  });

  _EditableEffect copyWith({
    String? id,
    EffectType? effectType,
    String? targetAssetId,
    String? targetDescription,
    String? expectedBehaviour,
    String? actualBehaviour,
    int? measuredTimeSeconds,
    bool? passed,
    String? notes,
  }) {
    return _EditableEffect(
      id: id ?? this.id,
      effectType: effectType ?? this.effectType,
      targetAssetId: targetAssetId ?? this.targetAssetId,
      targetDescription: targetDescription ?? this.targetDescription,
      expectedBehaviour: expectedBehaviour ?? this.expectedBehaviour,
      actualBehaviour: actualBehaviour ?? this.actualBehaviour,
      measuredTimeSeconds: measuredTimeSeconds ?? this.measuredTimeSeconds,
      passed: passed ?? this.passed,
      notes: notes ?? this.notes,
    );
  }
}
