import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/asset.dart';
import '../models/permission.dart';
import '../services/asset_service.dart';
import '../services/user_profile_service.dart';
import '../utils/icon_map.dart';
import '../utils/theme.dart';
import 'full_screen_image_viewer.dart';

/// A horizontal gallery for displaying and managing asset photos.
/// Handles permissions, upload, delete, and full-screen viewing.
class AssetPhotoGallery extends StatefulWidget {
  final String basePath;
  final String siteId;
  final Asset asset;
  final VoidCallback? onPhotosChanged;

  const AssetPhotoGallery({
    super.key,
    required this.basePath,
    required this.siteId,
    required this.asset,
    this.onPhotosChanged,
  });

  @override
  State<AssetPhotoGallery> createState() => _AssetPhotoGalleryState();
}

class _AssetPhotoGalleryState extends State<AssetPhotoGallery> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  String? _deletingUrl;

  bool get _canAddPhotos {
    final profile = UserProfileService.instance;
    if (!profile.hasCompany) return true;
    return profile.hasPermission(AppPermission.assetsAddPhotos);
  }

  bool get _canDeletePhotos {
    final profile = UserProfileService.instance;
    if (!profile.hasCompany) return true;
    return profile.hasPermission(AppPermission.assetsDeletePhotos);
  }

  bool get _hasReachedLimit =>
      widget.asset.photoUrls.length >= AssetService.maxPhotos;

  Future<void> _showImageSourceDialog() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(AppIcons.camera),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(AppIcons.gallery),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source != null) {
      await _pickAndUploadImage(source);
    }
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80,
      );

      if (image == null) return;

      setState(() => _isUploading = true);

      final bytes = await image.readAsBytes();
      final url = await AssetService.instance.uploadAssetPhoto(
        basePath: widget.basePath,
        siteId: widget.siteId,
        assetId: widget.asset.id,
        bytes: bytes,
      );

      if (url != null) {
        widget.onPhotosChanged?.call();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo added'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to upload photo'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error picking/uploading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _deletePhoto(String photoUrl) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('Are you sure you want to delete this photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _deletingUrl = photoUrl);

    final success = await AssetService.instance.deleteAssetPhoto(
      basePath: widget.basePath,
      siteId: widget.siteId,
      assetId: widget.asset.id,
      photoUrl: photoUrl,
    );

    if (mounted) {
      setState(() => _deletingUrl = null);
      if (success) {
        widget.onPhotosChanged?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo deleted'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete photo'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _viewFullScreen(int index) {
    FullScreenImageViewer.show(
      context,
      imageUrls: widget.asset.photoUrls,
      initialIndex: index,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final photos = widget.asset.photoUrls;
    final showAddButton = _canAddPhotos && !_hasReachedLimit;

    // Empty state
    if (photos.isEmpty && !showAddButton) {
      return const SizedBox.shrink();
    }

    if (photos.isEmpty && showAddButton) {
      return _buildEmptyState(isDark);
    }

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length + (showAddButton ? 1 : 0),
        itemBuilder: (context, index) {
          // Add button at the end
          if (index == photos.length) {
            return _buildAddButton(isDark);
          }
          return _buildPhotoThumbnail(photos[index], index, isDark);
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return GestureDetector(
      onTap: _isUploading ? null : _showImageSourceDialog,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          border: Border.all(
            color: isDark ? Colors.white24 : Colors.black12,
            style: BorderStyle.solid,
          ),
        ),
        child: Center(
          child: _isUploading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      AppIcons.camera,
                      size: 32,
                      color: isDark ? Colors.white54 : Colors.black38,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add photo',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildAddButton(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: GestureDetector(
        onTap: _isUploading ? null : _showImageSourceDialog,
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primaryBlue.withValues(alpha: 0.5),
              width: 2,
              style: BorderStyle.solid,
            ),
          ),
          child: _isUploading
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      AppIcons.addCircle,
                      size: 28,
                      color: AppTheme.primaryBlue,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add',
                      style: TextStyle(
                        color: AppTheme.primaryBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildPhotoThumbnail(String url, int index, bool isDark) {
    final isDeleting = _deletingUrl == url;

    return Padding(
      padding: EdgeInsets.only(right: index < widget.asset.photoUrls.length - 1 ? 8 : 0),
      child: GestureDetector(
        onTap: isDeleting ? null : () => _viewFullScreen(index),
        child: Stack(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 100,
                height: 100,
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: isDark ? Colors.white12 : Colors.black12,
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: isDark ? Colors.white12 : Colors.black12,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ),
              ),
            ),

            // Loading overlay when deleting
            if (isDeleting)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),

            // Delete button
            if (_canDeletePhotos && !isDeleting)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => _deletePhoto(url),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
