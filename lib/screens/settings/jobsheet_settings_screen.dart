import 'package:flutter/material.dart';
import '../../services/jobsheet_settings_service.dart';
import '../../utils/icon_map.dart';
import '../../widgets/premium_toast.dart';
import '../../widgets/animated_save_button.dart';
import '../../widgets/adaptive_app_bar.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/keyboard_dismiss_wrapper.dart';

class JobsheetSettingsScreen extends StatefulWidget {
  const JobsheetSettingsScreen({super.key});

  @override
  State<JobsheetSettingsScreen> createState() => _JobsheetSettingsScreenState();
}

class _JobsheetSettingsScreenState extends State<JobsheetSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;


  late TextEditingController _footerLine1Controller;
  late TextEditingController _footerLine2Controller;

  @override
  void initState() {
    super.initState();
    _footerLine1Controller = TextEditingController();
    _footerLine2Controller = TextEditingController();
    _loadSettings();
  }

  @override
  void dispose() {
    _footerLine1Controller.dispose();
    _footerLine2Controller.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await JobsheetSettingsService.getSettings();
    setState(() {
      _footerLine1Controller.text = settings.footerLine1;
      _footerLine2Controller.text = settings.footerLine2;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      // Load existing settings to preserve header values
      final existing = await JobsheetSettingsService.getSettings();
      final settings = JobsheetHeaderFooter(
        companyName: existing.companyName,
        tagline: existing.tagline,
        address: existing.address,
        phone: existing.phone,
        footerLine1: _footerLine1Controller.text.trim(),
        footerLine2: _footerLine2Controller.text.trim(),
      );

      await JobsheetSettingsService.saveSettings(settings);

      if (!mounted) return;
      context.showSuccessToast('Footer settings saved');
    } catch (e) {
      if (!mounted) return;
      context.showErrorToast('Error saving settings: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdaptiveNavigationBar(title: 'PDF Footer Settings'),
      body: _isLoading
          ? const Center(child: AdaptiveLoadingIndicator())
          : KeyboardDismissWrapper(
              child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Footer',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'These details appear at the bottom of your jobsheet PDFs',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _footerLine1Controller,
                      label: 'Footer Line 1',
                      hint: 'e.g., Company Name | Company Reg: 12345678',
                      icon: AppIcons.document,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _footerLine2Controller,
                      label: 'Footer Line 2',
                      hint: 'e.g., E: email@example.com | W: www.example.com',
                      icon: AppIcons.sms,
                    ),
                    const SizedBox(height: 32),

                    // Save Button
                    AnimatedSaveButton(
                      label: 'Save Settings',
                      onPressed: _saveSettings,
                      width: double.infinity,
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(AppIcons.infoCircle,
                              color: Colors.blue[700], size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Leave fields empty to use default placeholder text in your PDFs.',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.blue[700]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 16,
        ),
      ),
      textInputAction: TextInputAction.done,
    );
  }
}
