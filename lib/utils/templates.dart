import '../models/models.dart';

/// Pre-loaded job templates for common fire alarm jobs
class Templates {
  // Private constructor to prevent instantiation
  Templates._();

  // Common dropdown options reused across templates
  static const _passFail = ['Pass', 'Fail'];
  static const _passFailNa = ['Pass', 'Fail', 'N/A'];
  static const _yesNo = ['Yes', 'No'];
  static const _complianceStatus = [
    'Compliant',
    'Non-compliant',
    'Compliant with recommendations',
  ];
  static const _detectorTypes = [
    'Smoke - Optical',
    'Smoke - Ionisation',
    'Heat - Fixed Temperature',
    'Heat - Rate of Rise',
    'Multi-sensor',
    'Beam',
    'Carbon Monoxide (CO)',
    'Flame',
    'Aspirating (ASD/VESDA)',
    'Linear Heat',
    'Duct Detector',
  ];

  /// Get all pre-loaded templates
  static List<JobTemplate> getPreloadedTemplates() {
    return [
      batteryReplacementTemplate,
      detectorReplacementTemplate,
      annualInspectionTemplate,
      quarterlyTestTemplate,
      panelCommissioningTemplate,
      faultFindingTemplate,
      weeklyTestTemplate,
      emergencyLightingTemplate,
    ];
  }

  // ---------------------------------------------------------------------------
  // Battery Replacement
  // ---------------------------------------------------------------------------
  static final batteryReplacementTemplate = JobTemplate(
    id: 'battery_replacement',
    name: 'Battery Replacement',
    description: 'Panel battery replacement job',
    fields: [
      TemplateField(
        id: 'panel_make',
        label: 'Panel Make/Model',
        type: FieldType.text,
        required: true,
      ),
      TemplateField(
        id: 'panel_location',
        label: 'Panel Location',
        type: FieldType.text,
        required: true,
      ),
      TemplateField(
        id: 'battery_quantity',
        label: 'Number of Batteries',
        type: FieldType.number,
        required: true,
      ),
      TemplateField(
        id: 'battery_type',
        label: 'Battery Type',
        type: FieldType.dropdown,
        options: [
          '12V 7Ah',
          '12V 17Ah',
          '12V 26Ah',
          '24V 7Ah',
          '24V 17Ah',
          '24V 26Ah',
        ],
        required: true,
      ),
      TemplateField(
        id: 'battery_condition_on_arrival',
        label: 'Battery Condition on Arrival',
        type: FieldType.dropdown,
        options: ['Good', 'Fair', 'Poor'],
      ),
      TemplateField(
        id: 'old_battery_make',
        label: 'Old Battery Make',
        type: FieldType.text,
      ),
      TemplateField(
        id: 'old_battery_date',
        label: 'Old Battery Date Code',
        type: FieldType.text,
      ),
      TemplateField(
        id: 'new_battery_make',
        label: 'New Battery Make',
        type: FieldType.text,
        required: true,
      ),
      TemplateField(
        id: 'new_battery_date',
        label: 'New Battery Date Code',
        type: FieldType.text,
        required: true,
      ),
      TemplateField(
        id: 'new_battery_serial',
        label: 'New Battery Serial Number(s)',
        type: FieldType.multiline,
      ),
      TemplateField(
        id: 'voltage_before',
        label: 'Voltage Before Replacement (V)',
        type: FieldType.number,
        required: true,
      ),
      TemplateField(
        id: 'voltage_after',
        label: 'Voltage After Replacement (V)',
        type: FieldType.number,
        required: true,
      ),
      TemplateField(
        id: 'load_test',
        label: 'Load Test',
        type: FieldType.dropdown,
        options: _passFailNa,
        required: true,
      ),
      TemplateField(
        id: 'charger_test',
        label: 'Charger Test',
        type: FieldType.dropdown,
        options: _passFailNa,
        required: true,
      ),
      TemplateField(
        id: 'next_replacement',
        label: 'Next Replacement Due',
        type: FieldType.date,
      ),
      TemplateField(
        id: 'disposal_method',
        label: 'Battery Disposal Method',
        type: FieldType.dropdown,
        options: ['Returned to base', 'Customer disposal', 'Recycling center'],
      ),
    ],
  );

  // ---------------------------------------------------------------------------
  // Detector Replacement (with repeating section)
  // ---------------------------------------------------------------------------
  static final detectorReplacementTemplate = JobTemplate(
    id: 'detector_replacement',
    name: 'Detector Replacement',
    description: 'Smoke/heat detector replacement (single or multiple)',
    fields: [
      TemplateField(
        id: 'panel_make_model',
        label: 'Panel Make/Model',
        type: FieldType.text,
        required: true,
      ),
      TemplateField(
        id: 'panel_location',
        label: 'Panel Location',
        type: FieldType.text,
      ),
      TemplateField(
        id: 'detector_entries',
        label: 'Detector Replacements',
        type: FieldType.repeatGroup,
        required: true,
        minEntries: 1,
        children: [
          TemplateField(
            id: 'detector_location',
            label: 'Detector Location',
            type: FieldType.text,
            required: true,
          ),
          TemplateField(
            id: 'zone_number',
            label: 'Zone Number',
            type: FieldType.text,
            required: true,
          ),
          TemplateField(
            id: 'detector_address',
            label: 'Detector Address (if addressable)',
            type: FieldType.text,
          ),
          TemplateField(
            id: 'old_detector_type',
            label: 'Old Detector Type',
            type: FieldType.dropdown,
            options: _detectorTypes,
          ),
          TemplateField(
            id: 'old_detector_make',
            label: 'Old Detector Make/Model',
            type: FieldType.text,
          ),
          TemplateField(
            id: 'reason_for_replacement',
            label: 'Reason for Replacement',
            type: FieldType.dropdown,
            options: [
              'End of life',
              'Faulty',
              'Upgrade',
              'Damaged',
              'Wrong type',
            ],
            required: true,
          ),
          TemplateField(
            id: 'new_detector_type',
            label: 'New Detector Type',
            type: FieldType.dropdown,
            options: _detectorTypes,
            required: true,
          ),
          TemplateField(
            id: 'new_detector_make',
            label: 'New Detector Make/Model',
            type: FieldType.text,
            required: true,
          ),
          TemplateField(
            id: 'new_detector_serial',
            label: 'New Detector Serial Number',
            type: FieldType.text,
            required: true,
          ),
          TemplateField(
            id: 'base_replaced',
            label: 'Base Replaced',
            type: FieldType.checkbox,
          ),
          TemplateField(
            id: 'functional_test',
            label: 'Functional Test',
            type: FieldType.dropdown,
            options: _passFail,
            required: true,
          ),
          TemplateField(
            id: 'panel_indication',
            label: 'Correct Panel Indication',
            type: FieldType.dropdown,
            options: _passFailNa,
          ),
        ],
      ),
    ],
  );

  // ---------------------------------------------------------------------------
  // Annual Inspection (BS 5839-1:2025 aligned)
  // ---------------------------------------------------------------------------
  static final annualInspectionTemplate = JobTemplate(
    id: 'annual_inspection',
    name: 'Annual Inspection',
    description: 'Full system annual service and inspection per BS 5839-1:2025',
    fields: [
      // --- System Information ---
      TemplateField(
        id: 'panel_make_model',
        label: 'Panel Make/Model',
        type: FieldType.text,
        required: true,
      ),
      TemplateField(
        id: 'system_type',
        label: 'System Type',
        type: FieldType.dropdown,
        options: ['Conventional', 'Addressable', 'Hybrid', 'Wireless'],
        required: true,
      ),
      TemplateField(
        id: 'total_zones',
        label: 'Total Number of Zones',
        type: FieldType.number,
        required: true,
      ),
      TemplateField(
        id: 'total_devices',
        label: 'Total Number of Devices',
        type: FieldType.number,
        required: true,
      ),

      // --- Visual & Panel Checks ---
      TemplateField(
        id: 'visual_inspection',
        label: 'Visual Inspection',
        type: FieldType.dropdown,
        options: _passFailNa,
        required: true,
      ),
      TemplateField(
        id: 'panel_test',
        label: 'Panel Function Test',
        type: FieldType.dropdown,
        options: _passFail,
        required: true,
      ),
      TemplateField(
        id: 'system_log_checked',
        label: 'System Log Checked',
        type: FieldType.dropdown,
        options: _passFailNa,
        required: true,
      ),
      TemplateField(
        id: 'logbook_review_findings',
        label: 'Logbook Review Findings',
        type: FieldType.multiline,
      ),

      // --- Device Testing ---
      TemplateField(
        id: 'detectors_tested',
        label: 'Percentage of Detectors Tested',
        type: FieldType.dropdown,
        options: ['100%', '50%', '25%', 'As per client requirement'],
        required: true,
      ),
      TemplateField(
        id: 'call_points_tested',
        label: 'Call Points Tested',
        type: FieldType.dropdown,
        options: ['All', 'Sample', 'None'],
        required: true,
      ),
      TemplateField(
        id: 'sounders_tested',
        label: 'Sounders/Beacons Tested',
        type: FieldType.dropdown,
        options: _passFailNa,
        required: true,
      ),

      // --- Interface Testing ---
      TemplateField(
        id: 'cause_effect_tested',
        label: 'Cause & Effect Tested',
        type: FieldType.dropdown,
        options: _passFailNa,
        required: true,
      ),
      TemplateField(
        id: 'door_holders_tested',
        label: 'Door Holders/Closers Tested',
        type: FieldType.dropdown,
        options: _passFailNa,
      ),
      TemplateField(
        id: 'aov_interface_tested',
        label: 'AOV/Smoke Vent Interface Tested',
        type: FieldType.dropdown,
        options: _passFailNa,
      ),
      TemplateField(
        id: 'arc_transmission_test',
        label: 'ARC/Monitoring Transmission Test',
        type: FieldType.dropdown,
        options: _passFailNa,
      ),

      // --- Battery & Power ---
      TemplateField(
        id: 'battery_condition',
        label: 'Battery Condition',
        type: FieldType.dropdown,
        options: ['Good', 'Fair', 'Requires replacement'],
        required: true,
      ),
      TemplateField(
        id: 'standby_voltage',
        label: 'Standby Voltage (V)',
        type: FieldType.number,
      ),
      TemplateField(
        id: 'alarm_voltage',
        label: 'Alarm Voltage (V)',
        type: FieldType.number,
      ),
      TemplateField(
        id: 'earth_fault_test',
        label: 'Earth Fault Test',
        type: FieldType.dropdown,
        options: _passFailNa,
      ),

      // --- Site & Documentation ---
      TemplateField(
        id: 'zone_chart_accurate',
        label: 'Zone Chart Accurate',
        type: FieldType.dropdown,
        options: _passFailNa,
      ),
      TemplateField(
        id: 'drawings_updated',
        label: 'Drawings Up to Date',
        type: FieldType.dropdown,
        options: _passFailNa,
      ),
      TemplateField(
        id: 'building_changes_noted',
        label: 'Building Changes Since Last Visit',
        type: FieldType.dropdown,
        options: _yesNo,
        required: true,
      ),
      TemplateField(
        id: 'building_changes_details',
        label: 'Building Changes Details',
        type: FieldType.multiline,
      ),

      // --- False Alarms ---
      TemplateField(
        id: 'false_alarm_count',
        label: 'False Alarms in Past 12 Months',
        type: FieldType.number,
      ),
      TemplateField(
        id: 'false_alarm_history',
        label: 'False Alarm Details',
        type: FieldType.multiline,
      ),

      // --- Compliance & Recommendations ---
      TemplateField(
        id: 'system_compliance_status',
        label: 'System Compliance Status',
        type: FieldType.dropdown,
        options: _complianceStatus,
        required: true,
      ),
      TemplateField(
        id: 'recommended_remedial_works',
        label: 'Recommended Remedial Works',
        type: FieldType.multiline,
        required: true,
      ),
      TemplateField(
        id: 'next_service_due',
        label: 'Next Service Due',
        type: FieldType.date,
        required: true,
      ),
    ],
  );

  // ---------------------------------------------------------------------------
  // Quarterly Test
  // ---------------------------------------------------------------------------
  static final quarterlyTestTemplate = JobTemplate(
    id: 'quarterly_test',
    name: 'Quarterly Test',
    description: 'Routine quarterly testing per BS 5839-1:2025',
    fields: [
      TemplateField(
        id: 'panel_make_model',
        label: 'Panel Make/Model',
        type: FieldType.text,
        required: true,
      ),
      TemplateField(
        id: 'zone_tested',
        label: 'Zone(s) Tested',
        type: FieldType.text,
        required: true,
      ),
      TemplateField(
        id: 'call_point_tested',
        label: 'Call Point Tested (Location)',
        type: FieldType.text,
        required: true,
      ),
      TemplateField(
        id: 'devices_tested_details',
        label: 'Devices Tested Details',
        type: FieldType.multiline,
      ),
      TemplateField(
        id: 'alarm_activation',
        label: 'Alarm Activation',
        type: FieldType.dropdown,
        options: _passFail,
        required: true,
      ),
      TemplateField(
        id: 'sounders_operated',
        label: 'All Sounders Operated',
        type: FieldType.dropdown,
        options: _passFailNa,
        required: true,
      ),
      TemplateField(
        id: 'beacons_operated',
        label: 'All Beacons Operated',
        type: FieldType.dropdown,
        options: _passFailNa,
      ),
      TemplateField(
        id: 'panel_indication',
        label: 'Correct Panel Indication',
        type: FieldType.dropdown,
        options: _passFail,
        required: true,
      ),
      TemplateField(
        id: 'visual_inspection',
        label: 'Visual Inspection',
        type: FieldType.dropdown,
        options: _passFailNa,
      ),
      TemplateField(
        id: 'panel_faults_checked',
        label: 'Outstanding Panel Faults Checked',
        type: FieldType.dropdown,
        options: _passFailNa,
        required: true,
      ),
      TemplateField(
        id: 'arc_signal_test',
        label: 'ARC/Monitoring Signal Test',
        type: FieldType.dropdown,
        options: _passFailNa,
      ),
      TemplateField(
        id: 'building_changes_noted',
        label: 'Building Changes Noted',
        type: FieldType.dropdown,
        options: _yesNo,
      ),
      TemplateField(
        id: 'system_reset',
        label: 'System Reset Successfully',
        type: FieldType.dropdown,
        options: _passFail,
        required: true,
      ),
      TemplateField(
        id: 'recommended_actions',
        label: 'Recommended Actions',
        type: FieldType.multiline,
      ),
    ],
  );

  // ---------------------------------------------------------------------------
  // Panel Commissioning
  // ---------------------------------------------------------------------------
  static final panelCommissioningTemplate = JobTemplate(
    id: 'panel_commissioning',
    name: 'Panel Commissioning',
    description: 'New panel installation and commissioning',
    fields: [
      TemplateField(
        id: 'panel_make_model',
        label: 'Panel Make/Model',
        type: FieldType.text,
        required: true,
      ),
      TemplateField(
        id: 'panel_serial',
        label: 'Panel Serial Number',
        type: FieldType.text,
        required: true,
      ),
      TemplateField(
        id: 'firmware_version',
        label: 'Firmware/Software Version',
        type: FieldType.text,
      ),
      TemplateField(
        id: 'panel_location',
        label: 'Panel Location',
        type: FieldType.text,
        required: true,
      ),
      TemplateField(
        id: 'system_category',
        label: 'System Category',
        type: FieldType.dropdown,
        options: ['L1', 'L2', 'L3', 'L4', 'L5', 'M', 'P1', 'P2'],
        required: true,
      ),
      TemplateField(
        id: 'zones_configured',
        label: 'Number of Zones Configured',
        type: FieldType.number,
        required: true,
      ),
      TemplateField(
        id: 'network_config',
        label: 'Network/Repeater Configuration',
        type: FieldType.multiline,
      ),

      // --- Power & Battery ---
      TemplateField(
        id: 'power_supply_test',
        label: 'Power Supply Test',
        type: FieldType.dropdown,
        options: _passFail,
        required: true,
      ),
      TemplateField(
        id: 'battery_capacity',
        label: 'Battery Capacity (Ah)',
        type: FieldType.number,
        required: true,
      ),
      TemplateField(
        id: 'charging_test',
        label: 'Charging Test',
        type: FieldType.dropdown,
        options: _passFail,
        required: true,
      ),

      // --- Device & Interface Testing ---
      TemplateField(
        id: 'all_devices_tested',
        label: 'All Devices Tested',
        type: FieldType.dropdown,
        options: _passFailNa,
        required: true,
      ),
      TemplateField(
        id: 'cause_effect_programmed',
        label: 'Cause & Effect Programmed',
        type: FieldType.dropdown,
        options: _passFailNa,
        required: true,
      ),
      TemplateField(
        id: 'false_alarm_prevention',
        label: 'False Alarm Prevention Configured',
        type: FieldType.dropdown,
        options: _passFailNa,
      ),
      TemplateField(
        id: 'arc_monitoring_setup',
        label: 'ARC/Monitoring Setup',
        type: FieldType.dropdown,
        options: _passFailNa,
      ),
      TemplateField(
        id: 'sounder_db_levels',
        label: 'Sounder dB Levels Measured',
        type: FieldType.multiline,
      ),

      // --- Documentation & Handover ---
      TemplateField(
        id: 'zone_chart_provided',
        label: 'Zone Chart Provided',
        type: FieldType.dropdown,
        options: _passFailNa,
        required: true,
      ),
      TemplateField(
        id: 'as_built_drawings',
        label: 'As-Built Drawings Provided',
        type: FieldType.dropdown,
        options: _passFailNa,
        required: true,
      ),
      TemplateField(
        id: 'logbook_provided',
        label: 'Logbook Provided',
        type: FieldType.dropdown,
        options: _passFailNa,
      ),
      TemplateField(
        id: 'om_manual_provided',
        label: 'O&M Manual Provided',
        type: FieldType.dropdown,
        options: _passFailNa,
      ),
      TemplateField(
        id: 'cause_effect_provided',
        label: 'Cause & Effect Document Provided',
        type: FieldType.dropdown,
        options: _passFailNa,
      ),
      TemplateField(
        id: 'user_training',
        label: 'User Training Provided',
        type: FieldType.dropdown,
        options: _passFailNa,
      ),
      TemplateField(
        id: 'handover_witness',
        label: 'Handover Witness (Name)',
        type: FieldType.text,
      ),
    ],
  );

  // ---------------------------------------------------------------------------
  // Fault Finding & Repair
  // ---------------------------------------------------------------------------
  static final faultFindingTemplate = JobTemplate(
    id: 'fault_finding',
    name: 'Fault Finding & Repair',
    description: 'Investigate and repair system faults',
    fields: [
      TemplateField(
        id: 'arrival_time',
        label: 'Arrival Time',
        type: FieldType.text,
      ),
      TemplateField(
        id: 'departure_time',
        label: 'Departure Time',
        type: FieldType.text,
      ),
      TemplateField(
        id: 'fault_reported',
        label: 'Fault Reported',
        type: FieldType.multiline,
        required: true,
      ),
      TemplateField(
        id: 'fault_type',
        label: 'Fault Type',
        type: FieldType.dropdown,
        options: [
          'Fire',
          'Fault',
          'Pre-alarm',
          'Disablement',
          'Test',
          'Sounder fault',
          'Power supply fault',
          'Communication fault',
          'Other',
        ],
        required: true,
      ),
      TemplateField(
        id: 'severity',
        label: 'Severity',
        type: FieldType.dropdown,
        options: ['Critical', 'Major', 'Minor'],
        required: true,
      ),
      TemplateField(
        id: 'affected_zone',
        label: 'Affected Zone/Device',
        type: FieldType.text,
        required: true,
      ),
      TemplateField(
        id: 'panel_event_reference',
        label: 'Panel Event Log Reference',
        type: FieldType.text,
      ),
      TemplateField(
        id: 'investigation_findings',
        label: 'Investigation Findings',
        type: FieldType.multiline,
        required: true,
      ),
      TemplateField(
        id: 'cause_identified',
        label: 'Cause Identified',
        type: FieldType.text,
        required: true,
      ),
      TemplateField(
        id: 'action_taken',
        label: 'Action Taken',
        type: FieldType.multiline,
        required: true,
      ),
      TemplateField(
        id: 'parts_used',
        label: 'Parts Used',
        type: FieldType.multiline,
      ),
      TemplateField(
        id: 'fault_cleared',
        label: 'Fault Cleared',
        type: FieldType.dropdown,
        options: _passFailNa,
        required: true,
      ),
      TemplateField(
        id: 'system_tested',
        label: 'System Tested After Repair',
        type: FieldType.dropdown,
        options: _passFailNa,
        required: true,
      ),
      TemplateField(
        id: 'follow_up_required',
        label: 'Follow-up Required',
        type: FieldType.checkbox,
      ),
      TemplateField(
        id: 'follow_up_details',
        label: 'Follow-up Details',
        type: FieldType.multiline,
      ),
    ],
  );

  // ---------------------------------------------------------------------------
  // Weekly Test (NEW)
  // ---------------------------------------------------------------------------
  static final weeklyTestTemplate = JobTemplate(
    id: 'weekly_test',
    name: 'Weekly Test',
    description: 'Weekly fire alarm call point test',
    fields: [
      TemplateField(
        id: 'panel_make_model',
        label: 'Panel Make/Model',
        type: FieldType.text,
        required: true,
      ),
      TemplateField(
        id: 'call_point_location',
        label: 'Call Point Tested (Location)',
        type: FieldType.text,
        required: true,
      ),
      TemplateField(
        id: 'call_point_zone',
        label: 'Zone Number',
        type: FieldType.text,
      ),
      TemplateField(
        id: 'alarm_activation',
        label: 'Alarm Activation',
        type: FieldType.dropdown,
        options: _passFail,
        required: true,
      ),
      TemplateField(
        id: 'sounders_operated',
        label: 'All Sounders Operated',
        type: FieldType.dropdown,
        options: _passFailNa,
        required: true,
      ),
      TemplateField(
        id: 'beacons_operated',
        label: 'All Beacons Operated',
        type: FieldType.dropdown,
        options: _passFailNa,
      ),
      TemplateField(
        id: 'panel_indication_correct',
        label: 'Correct Panel Indication',
        type: FieldType.dropdown,
        options: _passFail,
        required: true,
      ),
      TemplateField(
        id: 'system_reset',
        label: 'System Reset Successfully',
        type: FieldType.dropdown,
        options: _passFail,
        required: true,
      ),
    ],
  );

  // ---------------------------------------------------------------------------
  // Emergency Lighting Annual Test (NEW)
  // ---------------------------------------------------------------------------
  static final emergencyLightingTemplate = JobTemplate(
    id: 'emergency_lighting_annual',
    name: 'Emergency Lighting Annual Test',
    description: 'Annual 3-hour duration test for emergency lighting',
    fields: [
      TemplateField(
        id: 'total_luminaires',
        label: 'Total Number of Luminaires',
        type: FieldType.number,
        required: true,
      ),
      TemplateField(
        id: 'total_exit_signs',
        label: 'Total Number of Exit Signs',
        type: FieldType.number,
        required: true,
      ),
      TemplateField(
        id: 'luminaires_passed',
        label: 'Luminaires Passed',
        type: FieldType.number,
        required: true,
      ),
      TemplateField(
        id: 'luminaires_failed',
        label: 'Luminaires Failed',
        type: FieldType.number,
        required: true,
      ),
      TemplateField(
        id: 'exit_signs_passed',
        label: 'Exit Signs Passed',
        type: FieldType.number,
        required: true,
      ),
      TemplateField(
        id: 'exit_signs_failed',
        label: 'Exit Signs Failed',
        type: FieldType.number,
        required: true,
      ),
      TemplateField(
        id: 'battery_duration_achieved',
        label: '3-Hour Battery Duration Achieved',
        type: FieldType.dropdown,
        options: _passFail,
        required: true,
      ),
      TemplateField(
        id: 'charging_systems_functional',
        label: 'Charging Systems Functional',
        type: FieldType.dropdown,
        options: _passFail,
        required: true,
      ),
      TemplateField(
        id: 'lux_levels_adequate',
        label: 'Lux Levels Adequate',
        type: FieldType.dropdown,
        options: _passFailNa,
      ),
      TemplateField(
        id: 'signage_condition',
        label: 'Signage Condition',
        type: FieldType.dropdown,
        options: _passFail,
      ),
      TemplateField(
        id: 'failed_units_details',
        label: 'Failed Units Details',
        type: FieldType.multiline,
      ),
      TemplateField(
        id: 'system_compliance',
        label: 'System Compliance Status',
        type: FieldType.dropdown,
        options: _complianceStatus,
        required: true,
      ),
      TemplateField(
        id: 'recommended_remedial_works',
        label: 'Recommended Remedial Works',
        type: FieldType.multiline,
      ),
      TemplateField(
        id: 'next_test_due',
        label: 'Next Test Due',
        type: FieldType.date,
        required: true,
      ),
    ],
  );
}
