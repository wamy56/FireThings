class DeclarationTemplates {
  DeclarationTemplates._();

  static const String satisfactory =
      'I confirm that the fire detection and fire alarm system installed at the '
      'above premises has been inspected and tested in accordance with the '
      'recommendations of BS 5839-1:2025 for a {category} system. '
      'The system was found to be in satisfactory condition at the time of inspection.';

  static const String satisfactoryWithVariations =
      'I confirm that the fire detection and fire alarm system installed at the '
      'above premises has been inspected and tested in accordance with the '
      'recommendations of BS 5839-1:2025 for a {category} system. '
      'The system was found to be in satisfactory condition at the time of inspection, '
      'subject to the variations from the standard recorded in the Variations Register.';

  static const String unsatisfactory =
      'I confirm that the fire detection and fire alarm system installed at the '
      'above premises has been inspected and tested in accordance with the '
      'recommendations of BS 5839-1:2025 for a {category} system. '
      'The system was found to be UNSATISFACTORY due to the issues set out in this '
      'report. The system does not currently meet the recommendations of the standard '
      'and remedial action is required.';

  static const String notDeclared =
      'This inspection visit has not yet been completed and no declaration '
      'has been made. This report is a draft and should not be relied upon.';
}
