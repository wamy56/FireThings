import '../models/models.dart';

/// Pre-loaded job templates for common fire alarm jobs
class Templates {
  // Private constructor to prevent instantiation
  Templates._();

  /// Get all pre-loaded templates
  static List<JobTemplate> getPreloadedTemplates() {
    return [
      batteryReplacementTemplate,
      detectorReplacementTemplate,
      annualInspectionTemplate,
      quarterlyTestTemplate,
      panelCommissioningTemplate,
      faultFindingTemplate,
    ];
  }

  /// Battery Replacement Template
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
        type: FieldType.dropdown,
        options: ['1', '2', '3', '4'],
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
        id: 'new_battery_serial',
        label: 'New Battery Serial Number(s)',
        type: FieldType.multiline,
      ),
      TemplateField(
        id: 'voltage_before',
        label: 'Voltage Before Replacement (V)',
        type: FieldType.number,
      ),
      TemplateField(
        id: 'voltage_after',
        label: 'Voltage After Replacement (V)',
        type: FieldType.number,
        required: true,
      ),
      TemplateField(
        id: 'load_test',
        label: 'Load Test Passed',
        type: FieldType.checkbox,
      ),
      TemplateField(
        id: 'charger_test',
        label: 'Charger Test Passed',
        type: FieldType.checkbox,
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

  /// Detector Replacement Template
  static final detectorReplacementTemplate = JobTemplate(
    id: 'detector_replacement',
    name: 'Detector Replacement',
    description: 'Smoke/heat detector replacement',
    fields: [
      TemplateField(
        id: 'detector_location',
        label: 'Detector Location/Zone',
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
        options: [
          'Smoke - Optical',
          'Smoke - Ionisation',
          'Heat - Fixed Temperature',
          'Heat - Rate of Rise',
          'Multi-sensor',
          'Beam',
        ],
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
        options: ['End of life', 'Faulty', 'Upgrade', 'Damaged', 'Wrong type'],
        required: true,
      ),
      TemplateField(
        id: 'new_detector_type',
        label: 'New Detector Type',
        type: FieldType.dropdown,
        options: [
          'Smoke - Optical',
          'Smoke - Ionisation',
          'Heat - Fixed Temperature',
          'Heat - Rate of Rise',
          'Multi-sensor',
          'Beam',
        ],
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
      ),
      TemplateField(
        id: 'base_replaced',
        label: 'Base Replaced',
        type: FieldType.checkbox,
      ),
      TemplateField(
        id: 'functional_test',
        label: 'Functional Test Result',
        type: FieldType.dropdown,
        options: ['Pass', 'Fail'],
        required: true,
      ),
      TemplateField(
        id: 'panel_indication',
        label: 'Correct Panel Indication',
        type: FieldType.checkbox,
      ),
    ],
  );

  /// Annual Inspection Template
  static final annualInspectionTemplate = JobTemplate(
    id: 'annual_inspection',
    name: 'Annual Inspection',
    description: 'Full system annual service and inspection',
    fields: [
      TemplateField(
        id: 'panel_make_model',
        label: 'Panel Make/Model',
        type: FieldType.text,
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
      TemplateField(
        id: 'visual_inspection',
        label: 'Visual Inspection Completed',
        type: FieldType.checkbox,
        required: true,
      ),
      TemplateField(
        id: 'panel_test',
        label: 'Panel Function Test',
        type: FieldType.dropdown,
        options: ['Pass', 'Fail'],
        required: true,
      ),
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
        type: FieldType.checkbox,
      ),
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
        options: ['Pass', 'Fail', 'N/A'],
      ),
      TemplateField(
        id: 'system_log_checked',
        label: 'System Log Checked',
        type: FieldType.checkbox,
      ),
      TemplateField(
        id: 'drawings_updated',
        label: 'Drawings Updated',
        type: FieldType.checkbox,
      ),
      TemplateField(
        id: 'next_service_due',
        label: 'Next Service Due',
        type: FieldType.date,
        required: true,
      ),
    ],
  );

  /// Quarterly Test Template
  static final quarterlyTestTemplate = JobTemplate(
    id: 'quarterly_test',
    name: 'Quarterly Test',
    description: 'Routine quarterly testing',
    fields: [
      TemplateField(
        id: 'panel_make_model',
        label: 'Panel Make/Model',
        type: FieldType.text,
        required: true,
      ),
      TemplateField(
        id: 'call_point_tested',
        label: 'Call Point Tested',
        type: FieldType.text,
        required: true,
      ),
      TemplateField(
        id: 'alarm_activation',
        label: 'Alarm Activation Successful',
        type: FieldType.checkbox,
        required: true,
      ),
      TemplateField(
        id: 'sounders_operated',
        label: 'All Sounders Operated',
        type: FieldType.checkbox,
        required: true,
      ),
      TemplateField(
        id: 'beacons_operated',
        label: 'All Beacons Operated',
        type: FieldType.checkbox,
      ),
      TemplateField(
        id: 'panel_indication',
        label: 'Correct Panel Indication',
        type: FieldType.checkbox,
        required: true,
      ),
      TemplateField(
        id: 'visual_inspection',
        label: 'Visual Inspection Completed',
        type: FieldType.checkbox,
      ),
      TemplateField(
        id: 'faults_found',
        label: 'Any Faults Found',
        type: FieldType.checkbox,
      ),
      TemplateField(
        id: 'system_reset',
        label: 'System Reset Successfully',
        type: FieldType.checkbox,
        required: true,
      ),
    ],
  );

  /// Panel Commissioning Template
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
        id: 'power_supply_test',
        label: 'Power Supply Test',
        type: FieldType.dropdown,
        options: ['Pass', 'Fail'],
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
        options: ['Pass', 'Fail'],
        required: true,
      ),
      TemplateField(
        id: 'all_devices_tested',
        label: 'All Devices Tested',
        type: FieldType.checkbox,
        required: true,
      ),
      TemplateField(
        id: 'cause_effect_programmed',
        label: 'Cause & Effect Programmed',
        type: FieldType.checkbox,
        required: true,
      ),
      TemplateField(
        id: 'false_alarm_prevention',
        label: 'False Alarm Prevention Configured',
        type: FieldType.checkbox,
      ),
      TemplateField(
        id: 'user_training',
        label: 'User Training Provided',
        type: FieldType.checkbox,
      ),
      TemplateField(
        id: 'documentation_provided',
        label: 'Documentation Provided',
        type: FieldType.multiline,
      ),
    ],
  );

  /// Fault Finding Template
  static final faultFindingTemplate = JobTemplate(
    id: 'fault_finding',
    name: 'Fault Finding & Repair',
    description: 'Investigate and repair system faults',
    fields: [
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
        id: 'affected_zone',
        label: 'Affected Zone/Device',
        type: FieldType.text,
        required: true,
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
        type: FieldType.checkbox,
        required: true,
      ),
      TemplateField(
        id: 'system_tested',
        label: 'System Tested After Repair',
        type: FieldType.checkbox,
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
}
