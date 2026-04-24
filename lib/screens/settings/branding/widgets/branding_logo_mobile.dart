import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../utils/icon_map.dart';
import '../../../../utils/theme.dart';

class BrandingLogoMobile extends StatefulWidget {
  final String? logoUrl;
  final bool uploading;
  final ValueChanged<({String name, Uint8List bytes})> onPicked;
  final VoidCallback onRemoved;

  const BrandingLogoMobile({
    super.key,
    this.logoUrl,
    this.uploading = false,
    required this.onPicked,
    required this.onRemoved,
  });

  @override
  State<BrandingLogoMobile> createState() => _BrandingLogoMobileState();
}

class _BrandingLogoMobileState extends State<BrandingLogoMobile> {
  final _picker = ImagePicker();

  Future<void> _pickImage() async {
    if (kIsWeb) {
      await _pickFromFiles();
      return;
    }

    final source = await showModalBottomSheet<_PickSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(AppIcons.camera),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(ctx, _PickSource.camera),
            ),
            ListTile(
              leading: Icon(AppIcons.gallery),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, _PickSource.gallery),
            ),
            ListTile(
              leading: Icon(AppIcons.document),
              title: const Text('Choose File'),
              onTap: () => Navigator.pop(ctx, _PickSource.file),
            ),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    switch (source) {
      case _PickSource.camera:
        await _pickFromCamera();
      case _PickSource.gallery:
        await _pickFromGallery();
      case _PickSource.file:
        await _pickFromFiles();
    }
  }

  Future<void> _pickFromCamera() async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 90,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    _validateAndEmit(image.name, bytes);
  }

  Future<void> _pickFromGallery() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 90,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    _validateAndEmit(image.name, bytes);
  }

  Future<void> _pickFromFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'svg'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    _validateAndEmit(file.name, file.bytes!);
  }

  void _validateAndEmit(String name, Uint8List bytes) {
    if (bytes.length > 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logo must be under 1 MB')),
      );
      return;
    }
    final ext = name.split('.').last.toLowerCase();
    if (!{'png', 'jpg', 'jpeg', 'svg'}.contains(ext)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logo must be PNG, JPG or SVG')),
      );
      return;
    }
    widget.onPicked((name: name, bytes: bytes));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasLogo = widget.logoUrl != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Logo',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite,
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
            boxShadow: isDark ? null : AppTheme.cardShadow,
          ),
          child: widget.uploading
              ? _buildUploading()
              : hasLogo
                  ? _buildPreview(isDark)
                  : _buildEmpty(isDark),
        ),
      ],
    );
  }

  Widget _buildEmpty(bool isDark) {
    return InkWell(
      onTap: _pickImage,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              AppIcons.gallery,
              size: 28,
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Add your logo',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'PNG, JPG or SVG up to 1 MB',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(bool isDark) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              widget.logoUrl!,
              fit: BoxFit.contain,
              errorBuilder: (_, e, st) => Icon(
                AppIcons.gallery,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            'Logo uploaded',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
        IconButton(
          onPressed: _pickImage,
          icon: Icon(AppIcons.edit),
          tooltip: 'Replace',
          iconSize: 20,
        ),
        IconButton(
          onPressed: widget.onRemoved,
          icon: Icon(AppIcons.trash, color: AppTheme.errorRed),
          tooltip: 'Remove',
          iconSize: 20,
        ),
      ],
    );
  }

  Widget _buildUploading() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

enum _PickSource { camera, gallery, file }
