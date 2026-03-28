import '../models/asset_type.dart';
import '../models/checklist_item.dart';

/// Built-in asset types shipped with the app.
/// Based on BS 5839 and common fire safety industry practice.
class DefaultAssetTypes {
  DefaultAssetTypes._();

  static final List<AssetType> all = [
    fireAlarmPanel,
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
    defaultChecklist: [
      ChecklistItem(id: 'fap_visual', label: 'Visual inspection', isRequired: true),
      ChecklistItem(id: 'fap_zone_leds', label: 'Check zone indicators/LEDs', isRequired: true),
      ChecklistItem(id: 'fap_battery', label: 'Battery voltage', resultType: 'number', isRequired: true),
      ChecklistItem(id: 'fap_charger', label: 'Charger output', resultType: 'pass_fail', isRequired: true),
      ChecklistItem(id: 'fap_faults', label: 'Check logged faults', isRequired: true),
      ChecklistItem(id: 'fap_earth', label: 'Earth fault test', isRequired: true),
      ChecklistItem(id: 'fap_sounder', label: 'Sounder/beacon activation', isRequired: true),
      ChecklistItem(id: 'fap_isolations', label: 'Check zone isolations removed', isRequired: true),
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
    defaultChecklist: [
      ChecklistItem(id: 'sd_visual', label: 'Visual inspection (damage/dust/paint)', isRequired: true),
      ChecklistItem(id: 'sd_functional', label: 'Functional test', isRequired: true),
      ChecklistItem(id: 'sd_panel', label: 'Panel indication', isRequired: true),
      ChecklistItem(id: 'sd_sounder', label: 'Sounder/beacon activation', isRequired: true),
      ChecklistItem(id: 'sd_sensitivity', label: 'Sensitivity check', isRequired: false),
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
    defaultChecklist: [
      ChecklistItem(id: 'hd_visual', label: 'Visual inspection', isRequired: true),
      ChecklistItem(id: 'hd_functional', label: 'Functional test', isRequired: true),
      ChecklistItem(id: 'hd_panel', label: 'Panel indication', isRequired: true),
      ChecklistItem(id: 'hd_sounder', label: 'Sounder/beacon activation', isRequired: true),
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
    defaultChecklist: [
      ChecklistItem(id: 'cp_visual', label: 'Visual inspection (damage/obstruction/signage)', isRequired: true),
      ChecklistItem(id: 'cp_functional', label: 'Functional test', isRequired: true),
      ChecklistItem(id: 'cp_panel', label: 'Panel indication', isRequired: true),
      ChecklistItem(id: 'cp_reset', label: 'Reset correctly', isRequired: true),
      ChecklistItem(id: 'cp_frangible', label: 'Frangible element intact (if break glass)', isRequired: false),
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
    defaultChecklist: [
      ChecklistItem(id: 'sb_visual', label: 'Visual inspection', isRequired: true),
      ChecklistItem(id: 'sb_functional', label: 'Functional test', isRequired: true),
      ChecklistItem(id: 'sb_adequate', label: 'Sound level adequate', isRequired: true),
      ChecklistItem(id: 'sb_db', label: 'dB reading at 1m', resultType: 'number', isRequired: false),
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
    defaultChecklist: [
      ChecklistItem(id: 'fe_visual', label: 'Visual inspection (condition/corrosion)', isRequired: true),
      ChecklistItem(id: 'fe_pressure', label: 'Pressure gauge green', isRequired: true),
      ChecklistItem(id: 'fe_pin', label: 'Safety pin/tamper seal', isRequired: true),
      ChecklistItem(id: 'fe_instructions', label: 'Instructions legible', isRequired: true),
      ChecklistItem(id: 'fe_signage', label: 'Signage', isRequired: true),
      ChecklistItem(id: 'fe_accessible', label: 'Accessible', isRequired: true),
      ChecklistItem(id: 'fe_weight', label: 'Weight check (kg)', resultType: 'number', isRequired: false),
      ChecklistItem(id: 'fe_discharge', label: 'Last discharge test date', resultType: 'text', isRequired: false),
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
    defaultChecklist: [
      ChecklistItem(id: 'el_visual', label: 'Visual inspection', isRequired: true),
      ChecklistItem(id: 'el_functional', label: 'Functional test (simulate mains failure)', isRequired: true),
      ChecklistItem(id: 'el_duration', label: '3-hour duration test (annual)', resultType: 'pass_fail', isRequired: false),
      ChecklistItem(id: 'el_output', label: 'Light output adequate', isRequired: true),
      ChecklistItem(id: 'el_charging', label: 'Charging indicator active', isRequired: true),
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
    defaultChecklist: [
      ChecklistItem(id: 'fd_leaf', label: 'Door leaf condition', isRequired: true),
      ChecklistItem(id: 'fd_intumescent', label: 'Intumescent seals', isRequired: true),
      ChecklistItem(id: 'fd_smoke_seals', label: 'Smoke seals', isRequired: true),
      ChecklistItem(id: 'fd_closer', label: 'Self-closer operation', isRequired: true),
      ChecklistItem(id: 'fd_hinges', label: 'Hinges secure', isRequired: true),
      ChecklistItem(id: 'fd_gaps', label: 'Gaps within tolerance', isRequired: true),
      ChecklistItem(id: 'fd_signage', label: 'Signage correct', isRequired: true),
      ChecklistItem(id: 'fd_holdopen', label: 'Hold-open device (if fitted)', isRequired: false),
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
    defaultChecklist: [
      ChecklistItem(id: 'av_visual', label: 'Visual inspection', isRequired: true),
      ChecklistItem(id: 'av_cycle', label: 'Open/close cycle', isRequired: true),
      ChecklistItem(id: 'av_local', label: 'Activation from local control', isRequired: true),
      ChecklistItem(id: 'av_panel', label: 'Activation from fire panel', isRequired: true),
      ChecklistItem(id: 'av_fullopen', label: 'Full open achieved', isRequired: true),
      ChecklistItem(id: 'av_reclose', label: 'Re-close correctly', isRequired: true),
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
    defaultChecklist: [
      ChecklistItem(id: 'sh_visual', label: 'Visual inspection (corrosion/paint/loading)', isRequired: true),
      ChecklistItem(id: 'sh_orientation', label: 'Correct orientation', isRequired: true),
      ChecklistItem(id: 'sh_clearance', label: 'Clearance below (min 500mm)', isRequired: true),
      ChecklistItem(id: 'sh_temp', label: 'Correct temperature rating', isRequired: true),
      ChecklistItem(id: 'sh_escutcheon', label: 'Escutcheon/cover plate intact', isRequired: true),
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
    defaultChecklist: [
      ChecklistItem(id: 'fb_container', label: 'Container condition', isRequired: true),
      ChecklistItem(id: 'fb_accessible', label: 'Accessible/unobstructed', isRequired: true),
      ChecklistItem(id: 'fb_blanket', label: 'Blanket undamaged/clean', isRequired: true),
      ChecklistItem(id: 'fb_signage', label: 'Signage visible', isRequired: true),
      ChecklistItem(id: 'fb_fixings', label: 'Wall fixings secure', isRequired: true),
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
    defaultChecklist: [
      ChecklistItem(id: 'other_visual', label: 'Visual inspection', isRequired: true),
      ChecklistItem(id: 'other_functional', label: 'Functional test', isRequired: false),
      ChecklistItem(id: 'other_notes', label: 'Notes', resultType: 'text', isRequired: false),
    ],
  );
}
