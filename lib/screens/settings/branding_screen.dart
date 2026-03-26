import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/branding_service.dart';
import '../../models/pdf_header_config.dart';
import '../../utils/icon_map.dart';
import '../../widgets/premium_toast.dart';
import '../../widgets/adaptive_app_bar.dart';
import '../../widgets/premium_dialog.dart';
import '../../utils/adaptive_widgets.dart';

class BrandingScreen extends StatefulWidget {
  const BrandingScreen({super.key});

  @override
  State<BrandingScreen> createState() => _BrandingScreenState();
}

class _BrandingScreenState extends State<BrandingScreen> {
  String? _logoPath;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogo();
  }

  Future<void> _loadLogo() async {
    final path = await BrandingService.getLogoPath(PdfDocumentType.jobsheet);
    setState(() {
      _logoPath = path;
      _isLoading = false;
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    ImageSource? source;

    await showAdaptiveActionSheet(
      context: context,
      title: 'Select Image Source',
      options: [
        ActionSheetOption(
          label: 'Camera',
          icon: AppIcons.gallery,
          onTap: () => source = ImageSource.camera,
        ),
        ActionSheetOption(
          label: 'Gallery',
          icon: AppIcons.gallery,
          onTap: () => source = ImageSource.gallery,
        ),
      ],
    );

    if (source == null) return;

    final picked = await picker.pickImage(source: source!, maxWidth: 512, maxHeight: 512);
    if (picked == null) return;

    await BrandingService.saveLogo(picked.path, PdfDocumentType.jobsheet);
    await BrandingService.saveLogo(picked.path, PdfDocumentType.invoice);
    await _loadLogo();

    if (mounted) {
      context.showSuccessToast('Logo saved successfully');
    }
  }

  Future<void> _removeLogo() async {
    final confirm = await showAdaptiveAlertDialog<bool>(
      context: context,
      title: 'Remove Logo',
      message: 'Are you sure you want to remove the company logo?',
      confirmLabel: 'Remove',
      cancelLabel: 'Cancel',
      isDestructive: true,
    );

    if (confirm != true) return;

    await BrandingService.removeLogo(PdfDocumentType.jobsheet);
    await BrandingService.removeLogo(PdfDocumentType.invoice);
    setState(() => _logoPath = null);

    if (mounted) {
      context.showInfoToast('Logo removed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdaptiveNavigationBar(title: 'Company Logo'),
      body: _isLoading
          ? const Center(child: AdaptiveLoadingIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Preview area
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: _logoPath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Image.file(
                            File(_logoPath!),
                            fit: BoxFit.contain,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(AppIcons.image, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text(
                              'No logo uploaded',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap "Upload Logo" to add your company logo',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 24),

                // Upload button
                FilledButton.icon(
                  onPressed: _pickImage,
                  icon: Icon(AppIcons.document),
                  label: Text(_logoPath != null ? 'Change Logo' : 'Upload Logo'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),

                // Remove button
                if (_logoPath != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _removeLogo,
                    icon: Icon(AppIcons.trash),
                    label: const Text('Remove Logo'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                // Helper text
                Text(
                  'This logo will appear in the header of all generated PDFs, including jobsheets and invoices.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
    );
  }
}
