import '../models/asset_type.dart';

/// Built-in asset types shipped with the app.
/// Based on BS 5839 and common fire safety industry practice.
class DefaultAssetTypes {
  DefaultAssetTypes._();

  static final List<AssetType> all = [
    fireAlarmPanel,
    fireAlarmInterface,
    powerSupplyUnit,
    smokeDetector,
    heatDetector,
    callPoint,
    sounderBeacon,
    fireExtinguisher,
    emergencyLighting,
    fireDoor,
    aovSmokeVent,
    sprinklerHead,
    fireBlanket,
    disabledRefugePanel,
    disabledRefugeOutstation,
    fireTelephone,
    toiletAlarmSystem,
    otherCustom,
  ];

  static AssetType? getById(String id) {
    try {
      return all.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  // ─── Fire Alarm Panel ────────────────────────────────────────

  static final fireAlarmPanel = AssetType(
    id: 'fire_alarm_panel',
    name: 'Fire Alarm Panel',
    category: 'Control',
    iconName: 'cpu',
    defaultColor: '#1E3A5F',
    variants: ['Conventional', 'Addressable', 'Analogue Addressable', 'Wireless'],
    defaultLifespanYears: 15,
    isBuiltIn: true,
    commonFaults: [
      'Logged faults',
      'Battery low/failed',
      'Earth fault',
      'Charger failure',
      'Zone fault',
      'Sounder circuit fault',
      'PSU failure',
      'Display/LED fault',
    ],
  );

  // ─── Fire Alarm Interface (I/O Module) ────────────────────────

  static final fireAlarmInterface = AssetType(
    id: 'fire_alarm_interface',
    name: 'Fire Alarm Interface',
    category: 'Control',
    iconName: 'flash',
    defaultColor: '#7C3AED',
    variants: ['Input Module', 'Output Module', 'Combined I/O', 'Relay Board', 'Mini Input Module', 'Zone Monitor'],
    defaultLifespanYears: 15,
    isBuiltIn: true,
    commonFaults: [
      'No communication',
      'LED fault',
      'Relay stuck',
      'Wiring fault',
      'Address conflict',
      'Module not responding',
      'Contact fault',
    ],
  );

  // ─── Power Supply Unit ───────────────────────────────────────

  static final powerSupplyUnit = AssetType(
    id: 'power_supply_unit',
    name: 'Power Supply Unit',
    category: 'Control',
    iconName: 'batteryCharging',
    defaultColor: '#CA8A04',
    variants: ['24V DC', 'Auxiliary PSU', 'EN54-4 Certified', 'Battery Charger', 'UPS'],
    defaultLifespanYears: 10,
    isBuiltIn: true,
    commonFaults: [
      'Battery low/failed',
      'Charger failure',
      'Output voltage incorrect',
      'Fuse blown',
      'Earth fault',
      'Mains failure indicator',
      'Battery disconnected',
    ],
  );

  // ─── Smoke Detector ──────────────────────────────────────────

  static final smokeDetector = AssetType(
    id: 'smoke_detector',
    name: 'Smoke Detector',
    category: 'Detection',
    iconName: 'radar',
    defaultColor: '#3B82F6',
    variants: ['Optical', 'Ionisation', 'Multi-sensor', 'Beam', 'Aspirating'],
    defaultLifespanYears: 10,
    isBuiltIn: true,
    commonFaults: [
      'Head dirty/contaminated',
      'Base fault',
      'Drift compensation exceeded',
      'No response to test',
      'Damaged/painted over',
      'Incorrect type for environment',
      'Loose in base',
    ],
  );

  // ─── Heat Detector ───────────────────────────────────────────

  static final heatDetector = AssetType(
    id: 'heat_detector',
    name: 'Heat Detector',
    category: 'Detection',
    iconName: 'radar_heat',
    defaultColor: '#EF4444',
    variants: ['Fixed Temperature', 'Rate of Rise', 'Combined'],
    defaultLifespanYears: 10,
    isBuiltIn: true,
    commonFaults: [
      'No response to test',
      'Head dirty/contaminated',
      'Damaged',
      'Incorrect type for environment',
      'Loose in base',
    ],
  );

  // ─── Call Point (Manual) ─────────────────────────────────────

  static final callPoint = AssetType(
    id: 'call_point',
    name: 'Call Point',
    category: 'Manual',
    iconName: 'danger',
    defaultColor: '#DC2626',
    variants: ['Conventional', 'Addressable', 'Resettable', 'Break Glass'],
    defaultLifespanYears: 15,
    isBuiltIn: true,
    commonFaults: [
      'Damaged frangible element',
      'Stuck/jammed',
      'No panel indication',
      'Obstructed/inaccessible',
      'Missing signage',
      'Failed to reset',
    ],
  );

  // ─── Sounder / Beacon / Visual Alarm ─────────────────────────

  static final sounderBeacon = AssetType(
    id: 'sounder_beacon',
    name: 'Sounder / Beacon',
    category: 'Notification',
    iconName: 'volumeHigh',
    defaultColor: '#F97316',
    variants: ['Sounder', 'Beacon', 'Combined Sounder/Beacon', 'Voice Alarm Speaker'],
    defaultLifespanYears: 15,
    isBuiltIn: true,
    commonFaults: [
      'Not functioning',
      'Low output',
      'Damaged',
      'Incorrect tone/flash pattern',
      'Wiring fault',
    ],
  );

  // ─── Fire Extinguisher ───────────────────────────────────────

  static final fireExtinguisher = AssetType(
    id: 'fire_extinguisher',
    name: 'Fire Extinguisher',
    category: 'Suppression',
    iconName: 'securitySafe',
    defaultColor: '#059669',
    variants: ['CO2', 'Dry Powder', 'AFFF Foam', 'Water', 'Wet Chemical'],
    defaultLifespanYears: 20,
    isBuiltIn: true,
    commonFaults: [
      'Low pressure',
      'Damaged/corroded',
      'Seal broken',
      'Missing pin/tamper seal',
      'Out of date',
      'Obstructed/inaccessible',
      'Missing signage',
      'Wrong type for location',
    ],
  );

  // ─── Emergency Lighting ──────────────────────────────────────

  static final emergencyLighting = AssetType(
    id: 'emergency_lighting',
    name: 'Emergency Lighting',
    category: 'Lighting',
    iconName: 'lampCharge',
    defaultColor: '#FBBF24',
    variants: ['Maintained', 'Non-maintained', 'Sustained', 'Combined'],
    defaultLifespanYears: 10,
    isBuiltIn: true,
    commonFaults: [
      'Battery failure',
      'Lamp failure',
      'Charging fault',
      'Damaged lens/diffuser',
      'Insufficient light output',
      'Failed duration test',
    ],
  );

  // ─── Fire Door ───────────────────────────────────────────────

  static final fireDoor = AssetType(
    id: 'fire_door',
    name: 'Fire Door',
    category: 'Passive',
    iconName: 'door',
    defaultColor: '#8B5CF6',
    variants: ['FD30', 'FD60', 'FD90', 'FD120'],
    isBuiltIn: true,
    commonFaults: [
      'Damaged intumescent seals',
      'Self-closer not functioning',
      'Gaps too large',
      'Hold-open device fault',
      'Missing signage',
      'Door leaf damaged',
      'Smoke seals missing/damaged',
      'Hinges loose/damaged',
    ],
  );

  // ─── AOV / Smoke Vent ────────────────────────────────────────

  static final aovSmokeVent = AssetType(
    id: 'aov_smoke_vent',
    name: 'AOV / Smoke Vent',
    category: 'Ventilation',
    iconName: 'wind',
    defaultColor: '#06B6D4',
    variants: ['Natural (AOV)', 'Mechanical', 'Smoke Shaft'],
    defaultLifespanYears: 15,
    isBuiltIn: true,
    commonFaults: [
      'Fails to open',
      'Fails to close',
      'Slow operation',
      'Actuator fault',
      'Control panel fault',
      'Obstructed',
    ],
  );

  // ─── Sprinkler Head ──────────────────────────────────────────

  static final sprinklerHead = AssetType(
    id: 'sprinkler_head',
    name: 'Sprinkler Head',
    category: 'Suppression',
    iconName: 'drop',
    defaultColor: '#0EA5E9',
    variants: ['Pendant', 'Upright', 'Sidewall', 'Concealed'],
    defaultLifespanYears: 50,
    isBuiltIn: true,
    commonFaults: [
      'Corroded',
      'Painted over',
      'Loaded/obstructed',
      'Wrong temperature rating',
      'Damaged escutcheon/cover',
      'Leaking',
    ],
  );

  // ─── Fire Blanket ────────────────────────────────────────────

  static final fireBlanket = AssetType(
    id: 'fire_blanket',
    name: 'Fire Blanket',
    category: 'Suppression',
    iconName: 'box',
    defaultColor: '#14B8A6',
    variants: ['Light Duty (kitchen)', 'Heavy Duty (industrial)'],
    defaultLifespanYears: 7,
    isBuiltIn: true,
    commonFaults: [
      'Damaged blanket',
      'Container broken/damaged',
      'Missing/obstructed',
      'Wall fixings loose',
      'Missing signage',
    ],
  );

  // ─── Disabled Refuge Panel (EVC Master) ──────────────────────

  static final disabledRefugePanel = AssetType(
    id: 'disabled_refuge_panel',
    name: 'Disabled Refuge Panel',
    category: 'Communication',
    iconName: 'slider',
    defaultColor: '#0D9488',
    variants: ['Type A (simplex)', 'Type B (duplex)', 'Combined EVC/Fire Telephone'],
    defaultLifespanYears: 15,
    isBuiltIn: true,
    commonFaults: [
      'Display fault',
      'Battery low/failed',
      'Line fault',
      'No communication with outstations',
      'PSU failure',
      'Charger fault',
      'Handset fault',
    ],
  );

  // ─── Disabled Refuge Outstation ──────────────────────────────

  static final disabledRefugeOutstation = AssetType(
    id: 'disabled_refuge_outstation',
    name: 'Disabled Refuge Outstation',
    category: 'Communication',
    iconName: 'microphone',
    defaultColor: '#0891B2',
    variants: ['Push-to-Talk', 'Hands-free', 'Combined Visual/Audio', 'Weatherproof'],
    defaultLifespanYears: 15,
    isBuiltIn: true,
    commonFaults: [
      'No communication with panel',
      'Speaker fault',
      'Microphone fault',
      'Push button stuck',
      'LED indicator fault',
      'Damaged/vandalised',
      'Wiring fault',
    ],
  );

  // ─── Fire Telephone ──────────────────────────────────────────

  static final fireTelephone = AssetType(
    id: 'fire_telephone',
    name: 'Fire Telephone',
    category: 'Communication',
    iconName: 'call',
    defaultColor: '#E11D48',
    variants: ['Type A Handset', 'Type B Handset', 'Jack Point', 'Combined Handset/Jack', 'Weatherproof'],
    defaultLifespanYears: 15,
    isBuiltIn: true,
    commonFaults: [
      'Handset fault',
      'No communication with master',
      'Jack socket damaged',
      'Wiring fault',
      'Cradle switch fault',
      'Missing handset',
      'Cord damaged',
    ],
  );

  // ─── Toilet Alarm System ─────────────────────────────────────

  static final toiletAlarmSystem = AssetType(
    id: 'toilet_alarm_system',
    name: 'Toilet Alarm System',
    category: 'Communication',
    iconName: 'notification',
    defaultColor: '#BE185D',
    variants: ['Full Kit', 'Pull Cord Only', 'Interface Unit', 'Overdoor Light', 'Reset Button'],
    defaultLifespanYears: 15,
    isBuiltIn: true,
    commonFaults: [
      'Pull cord broken/missing',
      'Overdoor light fault',
      'Interface not communicating with refuge panel',
      'Reset button stuck',
      'Wiring fault',
      'Sounder fault',
      'LED indicator fault',
      'Cord too short/too long',
    ],
  );

  // ─── Other / Custom Type ─────────────────────────────────────

  static final otherCustom = AssetType(
    id: 'other',
    name: 'Other / Custom',
    category: 'Other',
    iconName: 'setting',
    defaultColor: '#6B7280',
    isBuiltIn: true,
  );
}
