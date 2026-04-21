import '../models/bs5839_system_config.dart';
import '../models/cause_effect_test.dart';

class CauseEffectTemplateEntry {
  final String name;
  final String triggerDescription;
  final List<EffectType> expectedEffectTypes;

  const CauseEffectTemplateEntry({
    required this.name,
    required this.triggerDescription,
    required this.expectedEffectTypes,
  });
}

class CauseEffectTemplates {
  CauseEffectTemplates._();

  static const List<CauseEffectTemplateEntry> all = [
    CauseEffectTemplateEntry(
      name: 'MCP — Full Alarm',
      triggerDescription: 'Activate manual call point',
      expectedEffectTypes: [
        EffectType.sounderActivation,
        EffectType.beaconActivation,
        EffectType.arcSignalFire,
      ],
    ),
    CauseEffectTemplateEntry(
      name: 'MCP — Full Alarm with AOV',
      triggerDescription: 'Activate manual call point (AOV zone)',
      expectedEffectTypes: [
        EffectType.sounderActivation,
        EffectType.beaconActivation,
        EffectType.aovOpen,
        EffectType.arcSignalFire,
      ],
    ),
    CauseEffectTemplateEntry(
      name: 'MCP — Full Alarm with Door Release',
      triggerDescription: 'Activate manual call point (door hold-open zone)',
      expectedEffectTypes: [
        EffectType.sounderActivation,
        EffectType.beaconActivation,
        EffectType.doorHoldOpenRelease,
        EffectType.arcSignalFire,
      ],
    ),
    CauseEffectTemplateEntry(
      name: 'Smoke Detector — Full Alarm',
      triggerDescription: 'Activate smoke detector via test equipment',
      expectedEffectTypes: [
        EffectType.sounderActivation,
        EffectType.beaconActivation,
        EffectType.arcSignalFire,
      ],
    ),
    CauseEffectTemplateEntry(
      name: 'Detector — Pre-Alarm (Double Knock)',
      triggerDescription:
          'Activate single detector in double-knock zone',
      expectedEffectTypes: [
        EffectType.arcSignalPreAlarm,
      ],
    ),
    CauseEffectTemplateEntry(
      name: 'Fire Alarm — Lift Homing',
      triggerDescription: 'Activate device in lift zone',
      expectedEffectTypes: [
        EffectType.sounderActivation,
        EffectType.liftHomingGroundFloor,
        EffectType.arcSignalFire,
      ],
    ),
    CauseEffectTemplateEntry(
      name: 'Fire Alarm — Gas Shutoff',
      triggerDescription: 'Activate device in gas shutoff zone',
      expectedEffectTypes: [
        EffectType.sounderActivation,
        EffectType.gasShutoff,
        EffectType.arcSignalFire,
      ],
    ),
    CauseEffectTemplateEntry(
      name: 'Fire Alarm — Ventilation Shutdown',
      triggerDescription: 'Activate device in ventilation zone',
      expectedEffectTypes: [
        EffectType.sounderActivation,
        EffectType.ventilationShutdown,
        EffectType.arcSignalFire,
      ],
    ),
    CauseEffectTemplateEntry(
      name: 'Fault Condition — ARC',
      triggerDescription: 'Disconnect zone or simulate panel fault',
      expectedEffectTypes: [
        EffectType.arcSignalFault,
      ],
    ),
    CauseEffectTemplateEntry(
      name: 'Voice Alarm — Evacuation',
      triggerDescription: 'Trigger voice alarm evacuation message',
      expectedEffectTypes: [
        EffectType.voiceAlarmMessage,
        EffectType.arcSignalFire,
      ],
    ),
    CauseEffectTemplateEntry(
      name: 'Smoke Curtain Deployment',
      triggerDescription: 'Activate detector in smoke curtain zone',
      expectedEffectTypes: [
        EffectType.sounderActivation,
        EffectType.smokeCurtainDeploy,
        EffectType.arcSignalFire,
      ],
    ),
  ];

  static const Map<Bs5839SystemCategory, List<EffectType>> mcpDefaultEffects = {
    Bs5839SystemCategory.l1: [
      EffectType.sounderActivation,
      EffectType.beaconActivation,
      EffectType.aovOpen,
      EffectType.doorHoldOpenRelease,
      EffectType.liftHomingGroundFloor,
      EffectType.arcSignalFire,
    ],
    Bs5839SystemCategory.l2: [
      EffectType.sounderActivation,
      EffectType.beaconActivation,
      EffectType.doorHoldOpenRelease,
      EffectType.arcSignalFire,
    ],
    Bs5839SystemCategory.l3: [
      EffectType.sounderActivation,
      EffectType.beaconActivation,
      EffectType.arcSignalFire,
    ],
    Bs5839SystemCategory.l4: [
      EffectType.sounderActivation,
      EffectType.beaconActivation,
      EffectType.arcSignalFire,
    ],
    Bs5839SystemCategory.l5: [
      EffectType.sounderActivation,
      EffectType.beaconActivation,
      EffectType.arcSignalFire,
    ],
    Bs5839SystemCategory.p1: [
      EffectType.sounderActivation,
      EffectType.arcSignalFire,
    ],
    Bs5839SystemCategory.p2: [
      EffectType.sounderActivation,
      EffectType.arcSignalFire,
    ],
    Bs5839SystemCategory.m: [
      EffectType.sounderActivation,
      EffectType.beaconActivation,
    ],
  };
}
