import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../../models/floor_plan.dart';
import '../../services/floor_plan_service.dart';
import '../../services/analytics_service.dart';
import '../../services/auth_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../widgets/widgets.dart';

class UploadFloorPlanScreen extends StatefulWidget {
  final String siteId;
  final String basePath;

  const UploadFloorPlanScreen({
    super.key,
    required this.siteId,
    required this.basePath,
  });

  @override
  State<UploadFloorPlanScreen> createState() => _UploadFloorPlanScreenState();
}

class _UploadFloorPlanScreenState extends State<UploadFloorPlanScreen> {
  final _nameController = TextEditingController();
  final _authService = AuthService();
  Uint8List? _imageBytes;
  String _sourceType = '';
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickFromCamera() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 80,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _sourceType = 'camera';
      });
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 80,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _sourceType = 'gallery';
      });
    }
  }

  Future<void> _pickFromFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final bytes = result.files.first.bytes;
      if (bytes != null) {
        setState(() {
          _imageBytes = bytes;
          _sourceType = 'file';
        });
      }
    }
  }

  void _showSourcePicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Choose Image Source',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            if (!kIsWeb)
              ListTile(
                leading: const Icon(AppIcons.camera),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFromCamera();
                },
              ),
            ListTile(
              leading: const Icon(AppIcons.gallery),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(AppIcons.folder),
              title: const Text('Upload Image File'),
              onTap: () {
                Navigator.pop(ctx);
                _pickFromFiles();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<Size> _getImageSize(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final size = Size(image.width.toDouble(), image.height.toDouble());
    image.dispose();
    return size;
  }

  Future<void> _save() async {
    if (_imageBytes == null) {
      context.showWarningToast('Please select an image first');
      return;
    }

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      context.showWarningToast('Please enter a name');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception('Not signed in');

      final planId = const Uuid().v4();
      final now = DateTime.now();

      // Upload image
      final imageUrl = await FloorPlanService.instance.uploadFloorPlanImage(
        widget.basePath,
        widget.siteId,
        planId,
        _imageBytes!,
      );

      // Get image dimensions
      final size = await _getImageSize(_imageBytes!);

      // Create Firestore document
      final plan = FloorPlan(
        id: planId,
        siteId: widget.siteId,
        name: name,
        sortOrder: 0,
        imageUrl: imageUrl,
        imageWidth: size.width,
        imageHeight: size.height,
        createdBy: user.uid,
        createdAt: now,
        updatedAt: now,
      );

      await FloorPlanService.instance
          .createFloorPlan(widget.basePath, widget.siteId, plan);

      AnalyticsService.instance.logFloorPlanUploaded(
        siteId: widget.siteId,
        sourceType: _sourceType,
      );

      if (mounted) {
        context.showSuccessToast('Floor plan uploaded');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        context.showErrorToast('Upload failed: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Floor Plan'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: KeyboardDismissWrapper(
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          children: [
            // Image preview / picker
            GestureDetector(
              onTap: _isSaving ? null : _showSourcePicker,
              child: Container(
                height: 250,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkSurfaceElevated
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  border: Border.all(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: _imageBytes != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(_imageBytes!, fit: BoxFit.contain),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: _showSourcePicker,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(AppIcons.refresh,
                                    color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            AppIcons.image,
                            size: 48,
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.textSecondary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tap to select an image',
                            style: TextStyle(
                              fontSize: 15,
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Camera, gallery, or file',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.textHint,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 24),

            // Name field
            CustomTextField(
              controller: _nameController,
              label: 'Floor Plan Name (e.g. Ground Floor)',
              prefixIcon: const Icon(AppIcons.layer),
            ),

            if (_isSaving) ...[
              const SizedBox(height: 24),
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Uploading...'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
