import 'package:flutter/material.dart';
import '../../widgets/responsive_scaffold.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headingStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.bold,
    );
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(height: 1.6);

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: ResponsiveListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Last updated: 7 March 2026',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'FireThings ("we", "us", or "our") is committed to protecting your privacy. This policy explains what data we collect, why we collect it, where it is stored, how long we keep it, and what rights you have over your data.',
            style: bodyStyle,
          ),
          const SizedBox(height: 24),
          Text('1. Data We Collect', style: headingStyle),
          const SizedBox(height: 8),
          Text(
            '• Account information — email address and display name used for sign-in via Firebase Authentication.\n'
            '• Job data — customer names, site addresses, job details, defect notes, and signatures you enter into jobsheets.\n'
            '• Invoice data — customer details, line items, amounts, and bank payment details.\n'
            '• Saved customers and sites — names, addresses, and notes you save for quick access when creating jobsheets and invoices.\n'
            '• Location data — GPS coordinates captured when using the timestamp camera. Location is only accessed while the camera is actively in use, not in the background.\n'
            '• Photos and videos — media you capture with the timestamp camera, stored on your device and optionally saved to your device gallery.\n'
            '• Usage analytics — anonymous usage events (such as screens visited, features used, and actions taken) collected via Firebase Analytics to help us understand how the app is used.\n'
            '• Crash reports — automatic error and crash reports collected via Firebase Crashlytics to help us identify and fix bugs.\n'
            '• Device information — device model, operating system version, and app version, collected alongside crash reports and analytics.',
            style: bodyStyle,
          ),
          const SizedBox(height: 24),
          Text('2. Why We Collect It', style: headingStyle),
          const SizedBox(height: 8),
          Text(
            '• App functionality — to create, store, edit, and export your jobsheets, invoices, PDF certificates, and custom templates.\n'
            '• Cloud backup and sync — to back up your data securely and keep it in sync across your devices. Your local SQLite database is the primary data store; Firestore provides a cloud backup that syncs automatically.\n'
            '• Crash monitoring — to identify and fix errors that affect your experience, using Firebase Crashlytics.\n'
            '• Usage analytics — to understand which features are used so we can prioritise improvements and make the app better for fire alarm engineers.',
            style: bodyStyle,
          ),
          const SizedBox(height: 24),
          Text('3. Where Your Data Is Stored', style: headingStyle),
          const SizedBox(height: 8),
          Text(
            'Your data is stored in two places:\n\n'
            '• Locally on your device — in an SQLite database. The app is designed to work fully offline. All data is available on your device regardless of internet connectivity.\n'
            '• In the cloud (if sync is enabled) — a backup copy is stored in Google Cloud Firestore. Firestore data is hosted in Google Cloud data centres and protected by Google\'s infrastructure security, including encryption at rest and encryption in transit (TLS/HTTPS).\n\n'
            'Firebase Analytics and Crashlytics data is processed by Google on servers located in the United States and other countries where Google operates, in accordance with Google\'s privacy policies.',
            style: bodyStyle,
          ),
          const SizedBox(height: 24),
          Text('4. How Long We Keep It', style: headingStyle),
          const SizedBox(height: 8),
          Text(
            'Your data is retained for as long as your account is active and you continue to use the app. If you delete your account through Settings, all data — both local (SQLite, SharedPreferences, branding assets) and cloud (all Firestore documents and subcollections) — is permanently and irreversibly deleted.\n\n'
            'Crash reports and analytics data are retained by Google in accordance with their standard retention policies (typically 90 days for Crashlytics, 14 months for Analytics).',
            style: bodyStyle,
          ),
          const SizedBox(height: 24),
          Text('5. Who Can Access Your Data', style: headingStyle),
          const SizedBox(height: 8),
          Text(
            'Only you. Your Firestore data is stored under your unique user account and protected by security rules that prevent any other user from reading or writing it. Each user\'s data is completely isolated.\n\n'
            'We do not sell, share, rent, or provide your data to third parties for marketing, advertising, or any other commercial purpose.\n\n'
            'We do not use your data for tracking across other companies\' apps or websites.\n\n'
            'We do not access, analyse, or review your individual jobsheets, invoices, or financial data.',
            style: bodyStyle,
          ),
          const SizedBox(height: 24),
          Text('6. Your Rights', style: headingStyle),
          const SizedBox(height: 8),
          Text(
            'Under UK GDPR and the Data Protection Act 2018, you have the following rights:\n\n'
            '• Access — all your data is visible within the app at any time. You can view your jobsheets, invoices, saved customers, saved sites, and templates directly.\n'
            '• Export — you can export jobsheets and invoices as PDF documents and share them from within the app.\n'
            '• Correction — you can edit your data at any time within the app, including your display name, email address, and all job and invoice records.\n'
            '• Deletion — you can delete individual records from within the app, or delete your entire account and all associated data (both local and cloud) from Settings. Account deletion is permanent and cannot be reversed.\n'
            '• Portability — you can export your data as PDFs. If you require your data in another format, contact us.\n'
            '• Objection — if you wish to object to any data processing, contact us using the details in Section 9.',
            style: bodyStyle,
          ),
          const SizedBox(height: 24),
          Text('7. Third-Party Services', style: headingStyle),
          const SizedBox(height: 8),
          Text(
            'We use the following third-party services provided by Google, each governed by their own privacy policies:\n\n'
            '• Firebase Authentication — account sign-in and management. Processes your email address and authentication credentials.\n'
            '• Cloud Firestore — cloud data backup and synchronisation. Stores an encrypted backup of your app data.\n'
            '• Firebase Crashlytics — crash and error reporting. Collects crash logs, stack traces, and device information to help us fix bugs.\n'
            '• Firebase Analytics — anonymous usage analytics. Collects interaction events and screen views to help us understand feature usage.\n'
            '• Firebase Remote Config — server-side feature configuration. Does not collect personal data; it delivers configuration values to the app.\n\n'
            'All Firebase services are subject to the Google Cloud Privacy Notice and the Firebase Terms of Service.\n\n'
            'We have a Data Processing Agreement (DPA) in place with Google covering the processing of data through Firebase services.',
            style: bodyStyle,
          ),
          const SizedBox(height: 24),
          Text('8. Children', style: headingStyle),
          const SizedBox(height: 8),
          Text(
            'FireThings is a professional tool designed for fire alarm engineers. It is not intended for use by children under the age of 13. We do not knowingly collect personal data from children. If you believe a child has provided us with personal data, please contact us and we will delete it.',
            style: bodyStyle,
          ),
          const SizedBox(height: 24),
          Text('9. Contact', style: headingStyle),
          const SizedBox(height: 8),
          Text(
            'If you have any questions about this privacy policy, your data, or wish to exercise any of your rights, contact us at cscott93@hotmail.co.uk.\n\n'
            'We aim to respond to all enquiries within 30 days.',
            style: bodyStyle,
          ),
          const SizedBox(height: 24),
          Text('10. Changes to This Policy', style: headingStyle),
          const SizedBox(height: 8),
          Text(
            'We may update this privacy policy from time to time to reflect changes in the app, our practices, or legal requirements. Any changes will be reflected in the "Last updated" date at the top of this document and within the in-app privacy policy screen. Continued use of the app after changes constitutes acceptance of the updated policy.',
            style: bodyStyle,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
