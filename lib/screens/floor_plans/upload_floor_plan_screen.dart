import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';
import '../../models/floor_plan.dart';
import '../../services/floor_plan_service.dart';
import '../../services/analytics_service.dart';
import '../../services/auth_service.dart';
import '../../utils/image_utils.dart';
import '../../utils/image_compress_stub.dart'
    if (dart.library.html) '../../utils/image_compress_web.dart' as web_compress;
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
  Uint8List? _fileBytes;
  String? _fileName;
  String _sourceType = '';
  bool _isPdf = false;
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
        _fileBytes = bytes;
        _fileName = image.name;
        _isPdf = false;
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
        _fileBytes = bytes;
        _fileName = image.name;
        _isPdf = false;
        _sourceType = 'gallery';
      });
    }
  }

  Future<void> _pickFromFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'pdf'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes != null) {
        final ext = file.extension?.toLowerCase() ?? '';
        setState(() {
          _fileBytes = bytes;
          _fileName = file.name;
          _isPdf = ext == 'pdf';
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
                'Choose File Source',
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
              title: const Text('Upload File'),
              subtitle: const Text('Images or PDF documents'),
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
    // Use Flutter's own codec to get dimensions — this respects EXIF rotation
    // and matches exactly what Image.memory() / CachedNetworkImage will render,
    // ensuring stored dimensions always match the displayed image.
    try {
      final codec = await ui.instantiateImageCodec(bytes)
          .timeout(const Duration(seconds: 10));
      final frame = await codec.getNextFrame();
      final size = Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
      frame.image.dispose();
      codec.dispose();
      return size;
    } catch (e) {
      // Fallback: use the image package (slower but more reliable on web)
      debugPrint('_getImageSize codec failed ($e), using image package fallback');
      try {
        final decoded = img.decodeImage(bytes);
        if (decoded != null) {
          return Size(decoded.width.toDouble(), decoded.height.toDouble());
        }
      } catch (_) {}
      // Last resort default — pins still work since they use percentages
      return const Size(1024, 768);
    }
  }

  Future<void> _save() async {
    if (_fileBytes == null) {
      context.showWarningToast('Please select a file first');
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

      // If PDF, rasterize first page to PNG
      Uint8List uploadBytes = _fileBytes!;
      String ext = 'jpg';
      String contentType = 'image/jpeg';

      if (_isPdf) {
        try {
          final pages = Printing.raster(_fileBytes!, dpi: 200);
          final firstPage = await pages.first;
          final pngImage = await firstPage.toPng();
          uploadBytes = pngImage;
          ext = 'png';
          contentType = 'image/png';
        } catch (e) {
          if (mounted) {
            context.showErrorToast(
              kIsWeb
                  ? 'PDF conversion failed — please convert to JPEG and re-upload'
                  : 'PDF conversion failed: ${e.toString()}',
            );
          }
          return;
        }
      }

      // Compress image to max 2048px JPEG @ 80% for consistent storage size.
      // Web uses browser-native Canvas API (fast); mobile uses image pkg in isolate.
      print('[FloorPlan] Starting compression (${uploadBytes.length} bytes)...');
      if (kIsWeb) {
        uploadBytes = await web_compress.compressImageBytesWeb(
          uploadBytes,
          maxWidth: 2048,
          quality: 0.80,
        );
      } else {
        uploadBytes = await compute(
          (Uint8List b) => compressImageBytes(b, maxWidth: 2048, quality: 80),
          uploadBytes,
        );
      }
      ext = 'jpg';
      contentType = 'image/jpeg';
      print('[FloorPlan] Compression done (${uploadBytes.length} bytes). Uploading...');

      // Upload image
      final imageUrl = await FloorPlanService.instance.uploadFloorPlanImage(
        widget.basePath,
        widget.siteId,
        planId,
        uploadBytes,
        contentType: contentType,
        extension: ext,
      );
      print('[FloorPlan] Upload done. Getting dimensions...');

      // Get image dimensions from the upload bytes (always an image at this point)
      final size = await _getImageSize(uploadBytes);
      print('[FloorPlan] Dimensions: ${size.width}x${size.height}. Creating doc...');

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
        fileExtension: ext,
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 750),
          child: KeyboardDismissWrapper(
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
                child: _fileBytes != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_isPdf)
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(AppIcons.document,
                                    size: 48, color: Colors.red),
                                const SizedBox(height: 8),
                                const Text(
                                  'PDF Selected',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (_fileName != null) ...[
                                  const SizedBox(height: 4),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24),
                                    child: Text(
                                      _fileName!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            )
                          else
                            Image.memory(_fileBytes!, fit: BoxFit.contain),
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
                            'Tap to select an image or PDF',
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

            if (_isPdf && _fileBytes != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(AppIcons.infoCircle,
                        size: 18, color: AppTheme.primaryBlue),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'PDF will be converted to an image for pin placement',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_isSaving) ...[
              const SizedBox(height: 24),
              Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(_isPdf ? 'Converting PDF & uploading...' : 'Uploading...'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
        ),
      ),
    );
  }
}
