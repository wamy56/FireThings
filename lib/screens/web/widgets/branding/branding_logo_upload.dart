import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../theme/web_theme.dart';
import '../../../../utils/icon_map.dart';

class BrandingLogoUpload extends StatefulWidget {
  final String? logoFileName;
  final int? logoFileSize;
  final ValueChanged<({String name, int size, Uint8List bytes})> onLogoPicked;
  final VoidCallback onLogoRemoved;

  const BrandingLogoUpload({
    super.key,
    this.logoFileName,
    this.logoFileSize,
    required this.onLogoPicked,
    required this.onLogoRemoved,
  });

  @override
  State<BrandingLogoUpload> createState() => _BrandingLogoUploadState();
}

class _BrandingLogoUploadState extends State<BrandingLogoUpload> {
  bool _hovering = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    if (file.size > 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logo must be under 1 MB')),
      );
      return;
    }

    widget.onLogoPicked((
      name: file.name,
      size: file.size,
      bytes: file.bytes!,
    ));
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  String _formatExt(String name) {
    final ext = name.split('.').last.toUpperCase();
    return ext;
  }

  @override
  Widget build(BuildContext context) {
    return widget.logoFileName != null ? _buildPreview() : _buildDropzone();
  }

  Widget _buildPreview() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: FtColors.bgAlt,
        borderRadius: FtRadii.mdAll,
        border: Border.all(color: FtColors.border, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: FtColors.primaryGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                widget.logoFileName!.substring(0, 1).toUpperCase(),
                style: FtText.outfit(size: 22, weight: FontWeight.w800, color: FtColors.accent),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.logoFileName!,
                  style: FtText.inter(size: 13, weight: FontWeight.w600, color: FtColors.fg1),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  '${_formatExt(widget.logoFileName!)} · ${_formatSize(widget.logoFileSize ?? 0)}',
                  style: FtText.inter(size: 11, color: FtColors.fg2),
                ),
              ],
            ),
          ),
          _actionButton(AppIcons.refresh, 'Replace', onTap: _pickFile),
          const SizedBox(width: 4),
          _actionButton(Icons.delete_outline, 'Remove', danger: true, onTap: widget.onLogoRemoved),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String tooltip, {bool danger = false, VoidCallback? onTap}) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 14, color: danger ? FtColors.danger : FtColors.fg2),
        ),
      ),
    );
  }

  Widget _buildDropzone() {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: _pickFile,
        child: AnimatedContainer(
          duration: FtMotion.fast,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
          decoration: BoxDecoration(
            color: _hovering ? FtColors.accentSoft : FtColors.bgAlt,
            borderRadius: FtRadii.mdAll,
            border: Border.all(
              color: _hovering ? FtColors.accent : FtColors.border,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                AppIcons.gallery,
                size: 24,
                color: _hovering ? FtColors.accent : FtColors.hint,
              ),
              const SizedBox(height: 8),
              Text(
                'Click to upload logo',
                style: FtText.inter(
                  size: 13,
                  weight: FontWeight.w600,
                  color: _hovering ? FtColors.accent : FtColors.fg2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'PNG or JPG · Max 1 MB',
                style: FtText.inter(size: 11, color: FtColors.hint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
