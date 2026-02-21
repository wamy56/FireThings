import '../models/pdf_form_template.dart';

/// Pre-defined PDF form templates bundled with the app
class PdfFormTemplates {
  /// Get all bundled PDF form templates
  static List<PdfFormTemplate> getBundledTemplates() {
    return [iqModificationCertificate, iqMinorWorksCertificate];
  }

  /// Check if a template type name corresponds to a PDF certificate template
  static bool isPdfCertificateTemplate(String templateType) {
    return getBundledTemplates().any((t) => t.name == templateType);
  }

  /// Get a bundled PDF template by its name, or null if not found
  static PdfFormTemplate? getByName(String name) {
    final templates = getBundledTemplates();
    for (final t in templates) {
      if (t.name == name) return t;
    }
    return null;
  }

  /// IQ Modification Certificate template
  static PdfFormTemplate get iqModificationCertificate {
    return PdfFormTemplate(
      id: 'iq_modification_certificate',
      name: 'IQ Modification Certificate',
      description:
          'Certificate for fire alarm system modifications per BS 5839-1:2025',
      category: 'Certificates',
      pdfPath: 'assets/images/PDF files/IQ Modification Certificate.pdf',
      isBundled: true,
      pageCount: 1,
      createdAt: DateTime(2025, 1, 1),
      fields: _iqModificationCertificateFields,
    );
  }

  /// Field definitions for IQ Modification Certificate
  /// Positions are percentages of page dimensions (A4: 595 x 842 points)
  static List<FormFieldDefinition> get _iqModificationCertificateFields {
    return [
      // ==================== Header Section ====================
      // Customer Name - Perfect
      FormFieldDefinition(
        id: 'customer_name',
        label: 'Customer Name',
        type: FormFieldDefinitionType.text,
        x: 19,
        y: 14.2,
        width: 38,
        height: 2.5,
        required: true,
        fontSize: 9,
      ),
      // Date - perfect
      FormFieldDefinition(
        id: 'date',
        label: 'Date',
        type: FormFieldDefinitionType.datePicker,
        x: 64,
        y: 14.5,
        width: 29.5,
        height: 2.5,
        required: true,
        fontSize: 9,
      ),
      // Site Address - perfect
      FormFieldDefinition(
        id: 'site_address',
        label: 'Site Address',
        type: FormFieldDefinitionType.multilineText,
        x: 6,
        y: 18.5,
        width: 51,
        height: 6,
        required: true,
        fontSize: 9,
      ),
      // Job No - perfect
      FormFieldDefinition(
        id: 'job_no',
        label: 'Job No',
        type: FormFieldDefinitionType.text,
        x: 68.2,
        y: 17,
        width: 25.8,
        height: 2.5,
        required: true,
        fontSize: 9,
      ),
      // Installer(s) - perfect
      FormFieldDefinition(
        id: 'installers',
        label: 'Installer(s)',
        type: FormFieldDefinitionType.text,
        x: 68.2,
        y: 20,
        width: 25.8,
        height: 2.5,
        required: false,
        fontSize: 9,
      ),
      // System Category - perfect
      FormFieldDefinition(
        id: 'system_category',
        label: 'System Category',
        type: FormFieldDefinitionType.text,
        x: 73,
        y: 22.5,
        width: 21,
        height: 2.5,
        required: false,
        fontSize: 9,
      ),

      // ==================== Work Details ====================
      // Extent of Installation work - perfect
      FormFieldDefinition(
        id: 'extent_of_work',
        label: 'Extent of Installation Work',
        type: FormFieldDefinitionType.multilineText,
        x: 6.5,
        y: 26.5,
        width: 87.2,
        height: 8,
        required: true,
        fontSize: 9,
      ),
      // Variations from BS 5839-1:2025 - perfect
      FormFieldDefinition(
        id: 'variations_from_standard',
        label: 'Variations from BS 5839-1:2025',
        type: FormFieldDefinitionType.multilineText,
        x: 6.5,
        y: 36.5,
        width: 87.2,
        height: 6.5,
        required: false,
        fontSize: 9,
      ),

      // ==================== Compliance Checkboxes ====================

      // Checkbox 1: System tested -- perfect
      FormFieldDefinition(
        id: 'system_tested',
        label: 'System tested in accordance with 46.4.2',
        type: FormFieldDefinitionType.checkbox,
        x: 6.5,
        y: 43.2,
        width: 2,
        height: 2,
        required: false,
        fontSize: 9,
      ),
      // Checkbox 2: Drawings updated -- perfect
      FormFieldDefinition(
        id: 'drawings_updated',
        label: 'As-fitted drawings updated',
        type: FormFieldDefinitionType.checkbox,
        x: 6.5,
        y: 45.5,
        width: 2,
        height: 2,
        required: false,
        fontSize: 9,
      ),
      // Checkbox 3: No false alarm potential - - perfect
      FormFieldDefinition(
        id: 'no_false_alarm_potential',
        label: 'No false alarm potential identified',
        type: FormFieldDefinitionType.checkbox,
        x: 6.5,
        y: 47.7,
        width: 2,
        height: 2,
        required: false,
        fontSize: 9,
      ),
      // Checkbox 4: Third party installation - perfect
      FormFieldDefinition(
        id: 'third_party_installation',
        label: 'Installation by third party',
        type: FormFieldDefinitionType.checkbox,
        x: 6.5,
        y: 51.5,
        width: 2,
        height: 2,
        required: false,
        fontSize: 9,
      ),
      // Third party installer name field - perfect
      FormFieldDefinition(
        id: 'third_party_installer_name',
        label: 'Third Party Installer Name',
        type: FormFieldDefinitionType.text,
        x: 67.5,
        y: 51.5,
        width: 26,
        height: 2.5,
        required: false,
        fontSize: 9,
      ),
      // Checkbox 5: Subsequent visit required - perfect
      FormFieldDefinition(
        id: 'subsequent_visit_required',
        label: 'Subsequent visit required',
        type: FormFieldDefinitionType.checkbox,
        x: 6.5,
        y: 56,
        width: 2,
        height: 2,
        required: false,
        fontSize: 9,
      ),
      // Subsequent visit details field - perfect
      FormFieldDefinition(
        id: 'subsequent_visit_details',
        label: 'Work to be completed',
        type: FormFieldDefinitionType.text,
        x: 9.5,
        y: 57.5,
        width: 84,
        height: 8,
        required: false,
        fontSize: 9,
      ),

      // ==================== Engineer Certification (Blue section) ====================
      // Name in BLOCK letters perfect
      FormFieldDefinition(
        id: 'engineer_name',
        label: 'Engineer Name (BLOCK LETTERS)',
        type: FormFieldDefinitionType.text,
        x: 24,
        y: 70.8,
        width: 37,
        height: 2.5,
        required: true,
        fontSize: 9,
      ),
      // Position -- perfect
      FormFieldDefinition(
        id: 'engineer_position',
        label: 'Position',
        type: FormFieldDefinitionType.text,
        x: 69.5,
        y: 70.8,
        width: 22.5,
        height: 2.5,
        required: true,
        fontSize: 9,
      ),
      // Engineer Signature -- perfect
      FormFieldDefinition(
        id: 'engineer_signature',
        label: 'Engineer Signature',
        type: FormFieldDefinitionType.signature,
        x: 15,
        y: 73.5,
        width: 46,
        height: 4,
        required: true,
        fontSize: 9,
      ),
      // Engineer Date -- perfect
      FormFieldDefinition(
        id: 'engineer_date',
        label: 'Date',
        type: FormFieldDefinitionType.datePicker,
        x: 67.2,
        y: 73.7,
        width: 25,
        height: 2.5,
        required: true,
        fontSize: 9,
      ),

      // ==================== Customer Certification ====================
      // Customer Signature -- perfect
      FormFieldDefinition(
        id: 'customer_signature',
        label: 'Customer Signature',
        type: FormFieldDefinitionType.signature,
        x: 14.2,
        y: 84.5,
        width: 20.3,
        height: 3.7,
        required: true,
        fontSize: 9,
      ),
      // Customer Name -- perfect
      FormFieldDefinition(
        id: 'customer_cert_name',
        label: 'Customer Name',
        type: FormFieldDefinitionType.text,
        x: 40,
        y: 85.6,
        width: 19,
        height: 2.5,
        required: true,
        fontSize: 9,
      ),
      // Customer Position -- perfect
      FormFieldDefinition(
        id: 'customer_position',
        label: 'Position',
        type: FormFieldDefinitionType.text,
        x: 65,
        y: 85.5,
        width: 12,
        height: 2.5,
        required: false,
        fontSize: 9,
      ),
      // Customer Date -- perfect
      FormFieldDefinition(
        id: 'customer_date',
        label: 'Date',
        type: FormFieldDefinitionType.datePicker,
        x: 81,
        y: 85.5,
        width: 12,
        height: 2.5,
        required: true,
        fontSize: 9,
      ),
    ];
  }

  /// IQ Minor Works & Call Out Certificate template
  static PdfFormTemplate get iqMinorWorksCertificate {
    return PdfFormTemplate(
      id: 'iq_minor_works_certificate',
      name: 'IQ Minor Works & Call Out Certificate',
      description: 'Certificate for minor works and call out visits',
      category: 'Certificates',
      pdfPath:
          'assets/images/PDF files/IQ Minor Works & Call Out Certificate.pdf',
      isBundled: true,
      pageCount: 1,
      createdAt: DateTime(2025, 1, 1),
      fields: _iqMinorWorksCertificateFields,
    );
  }

  /// Field definitions for IQ Minor Works & Call Out Certificate
  static List<FormFieldDefinition> get _iqMinorWorksCertificateFields {
    return [
      // ==================== Header Section ====================
      FormFieldDefinition(
        id: 'customer_name',
        label: 'Customer Name',
        type: FormFieldDefinitionType.text,
        x: 6.5,
        y: 10.7,
        width: 42,
        height: 2,
        required: true,
        fontSize: 9,
      ),
      FormFieldDefinition(
        id: 'date',
        label: 'Date',
        type: FormFieldDefinitionType.datePicker,
        x: 55.5,
        y: 10.7,
        width: 6,
        height: 1.75,
        required: true,
        fontSize: 9,
      ),
      FormFieldDefinition(
        id: 'job_number',
        label: 'Job Number',
        type: FormFieldDefinitionType.text,
        x: 82.5,
        y: 10.2,
        width: 15,
        height: 2,
        required: true,
        fontSize: 9,
      ),
      FormFieldDefinition(
        id: 'site_address',
        label: 'Site Address',
        type: FormFieldDefinitionType.multilineText,
        x: 6.5,
        y: 14,
        width: 42.5,
        height: 6,
        required: true,
        fontSize: 9,
      ),
      FormFieldDefinition(
        id: 'callout_arrival_time',
        label: 'Call Out Arrival Time',
        type: FormFieldDefinitionType.text,
        x: 65,
        y: 14.7,
        width: 6,
        height: 2,
        required: false,
        fontSize: 9,
      ),
      FormFieldDefinition(
        id: 'callout_departure_time',
        label: 'Call Out Departure Time',
        type: FormFieldDefinitionType.text,
        x: 89.2,
        y: 14.7,
        width: 6,
        height: 2,
        required: false,
        fontSize: 9,
      ),

      // ==================== Visit Type Checkboxes ====================
      FormFieldDefinition(
        id: 'visit_type_remedial',
        label: 'Remedial Works',
        type: FormFieldDefinitionType.checkbox,
        x: 20.7,
        y: 20.5,
        width: 2,
        height: 2,
        required: false,
        fontSize: 9,
      ),
      FormFieldDefinition(
        id: 'visit_type_callout',
        label: 'Call Out',
        type: FormFieldDefinitionType.checkbox,
        x: 40,
        y: 20.7,
        width: 2,
        height: 2,
        required: false,
        fontSize: 9,
      ),

      // ==================== System Type Checkboxes ====================
      FormFieldDefinition(
        id: 'system_type_fire_alarm',
        label: 'Fire Alarm',
        type: FormFieldDefinitionType.checkbox,
        x: 20.7,
        y: 23.3,
        width: 2,
        height: 2,
        required: false,
        fontSize: 9,
      ),
      FormFieldDefinition(
        id: 'system_type_emergency_lighting',
        label: 'Emergency Lighting',
        type: FormFieldDefinitionType.checkbox,
        x: 33,
        y: 23.5,
        width: 2,
        height: 2,
        required: false,
        fontSize: 9,
      ),
      FormFieldDefinition(
        id: 'system_type_aov',
        label: 'AOV/Smoke Vent',
        type: FormFieldDefinitionType.checkbox,
        x: 50,
        y: 23.5,
        width: 2,
        height: 2,
        required: false,
        fontSize: 9,
      ),
      FormFieldDefinition(
        id: 'system_type_other',
        label: 'Other',
        type: FormFieldDefinitionType.checkbox,
        x: 66,
        y: 23.3,
        width: 2,
        height: 2,
        required: false,
        fontSize: 9,
      ),
      FormFieldDefinition(
        id: 'system_type_other_text',
        label: 'Other System Type',
        type: FormFieldDefinitionType.text,
        x: 66,
        y: 26,
        width: 27.5,
        height: 2.5,
        required: false,
        fontSize: 9,
      ),

      // ==================== Work Details ====================
      FormFieldDefinition(
        id: 'description_of_work',
        label: 'Description of Work Completed',
        type: FormFieldDefinitionType.multilineText,
        x: 6.5,
        y: 32,
        width: 87.5,
        height: 32,
        required: true,
        fontSize: 9,
      ),
      FormFieldDefinition(
        id: 'parts_used',
        label: 'Parts Used on Call Out',
        type: FormFieldDefinitionType.multilineText,
        x: 6.5,
        y: 66.5,
        width: 87.5,
        height: 12,
        required: false,
        fontSize: 9,
      ),

      // ==================== IQ Fire Representative ====================
      FormFieldDefinition(
        id: 'iq_rep_name',
        label: 'IQ Rep Print Name',
        type: FormFieldDefinitionType.text,
        x: 24.75,
        y: 82.2,
        width: 27.5,
        height: 2,
        required: true,
        fontSize: 9,
      ),
      FormFieldDefinition(
        id: 'iq_rep_signature',
        label: 'IQ Rep Signature',
        type: FormFieldDefinitionType.signature,
        x: 24.75,
        y: 85.2,
        width: 28,
        height: 4,
        required: true,
        fontSize: 9,
      ),

      // ==================== Client Representative ====================
      FormFieldDefinition(
        id: 'client_rep_name',
        label: 'Client Rep Print Name',
        type: FormFieldDefinitionType.text,
        x: 63.7,
        y: 82.2,
        width: 29,
        height: 2,
        required: true,
        fontSize: 9,
      ),
      FormFieldDefinition(
        id: 'client_rep_signature',
        label: 'Client Rep Signature',
        type: FormFieldDefinitionType.signature,
        x: 63.7,
        y: 84.2,
        width: 29,
        height: 4.5,
        required: false,
        fontSize: 9,
      ),
      FormFieldDefinition(
        id: 'client_not_available',
        label: 'Client Not Available',
        type: FormFieldDefinitionType.checkbox,
        x: 63.9,
        y: 89.4,
        width: 2,
        height: 2,
        required: false,
        fontSize: 9,
      ),
    ];
  }
}
