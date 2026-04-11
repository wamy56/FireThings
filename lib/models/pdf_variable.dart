/// Dynamic variables that can be inserted into PDF header/footer content blocks.
///
/// Each variable has a display label and a token string (e.g. `{company_name}`)
/// that gets resolved to actual values at PDF generation time.
enum PdfVariable {
  companyName('Company Name', '{company_name}'),
  tagline('Tagline', '{tagline}'),
  address('Address', '{address}'),
  phone('Phone', '{phone}'),
  email('Email', '{email}'),
  website('Website', '{website}'),
  engineerName('Engineer Name', '{engineer_name}'),
  invoiceNumber('Invoice Number', '{invoice_number}'),
  jobReference('Job Reference', '{job_reference}'),
  date('Date', '{date}'),
  siteName('Site Name', '{site_name}'),
  customerName('Customer Name', '{customer_name}'),
  custom('Custom Text', '');

  final String label;
  final String token;
  const PdfVariable(this.label, this.token);

  /// Variables available for all document types.
  static const List<PdfVariable> common = [
    companyName,
    tagline,
    address,
    phone,
    email,
    website,
    engineerName,
    date,
    customerName,
  ];

  /// Variables only available for invoice documents.
  static const List<PdfVariable> invoiceOnly = [
    invoiceNumber,
  ];

  /// Variables only available for jobsheet documents.
  static const List<PdfVariable> jobsheetOnly = [
    jobReference,
    siteName,
  ];
}

/// Resolves `{variable}` tokens in text to their actual values.
class PdfVariableResolver {
  final Map<String, String> context;

  const PdfVariableResolver(this.context);

  /// Replace all known tokens in [template] with values from [context].
  String resolve(String template) {
    var result = template;
    for (final entry in context.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result;
  }

  /// Check if a string contains any variable tokens.
  static bool containsVariables(String text) {
    return RegExp(r'\{[a-z_]+\}').hasMatch(text);
  }
}
