import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/floor_plan.dart';
import '../../services/floor_plan_service.dart';
import '../../services/user_profile_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/widgets.dart';
import 'upload_floor_plan_screen.dart';
import 'interactive_floor_plan_screen.dart';

class FloorPlanListScreen extends StatelessWidget {
  final String siteId;
  final String siteName;
  final String basePath;

  const FloorPlanListScreen({
    super.key,
    required this.siteId,
    required this.siteName,
    required this.basePath,
  });

  bool get _canDelete {
    final profile = UserProfileService.instance;
    return !profile.hasCompany || profile.isDispatcherOrAdmin;
  }

  void _navigateToUpload(BuildContext context) {
    if (kIsWeb) {
      context.go('/sites/$siteId/floor-plans/upload');
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UploadFloorPlanScreen(
            siteId: siteId,
            basePath: basePath,
          ),
        ),
      );
    }
  }

  void _navigateToView(BuildContext context, FloorPlan plan) {
    if (kIsWeb) {
      context.go('/sites/$siteId/floor-plans/${plan.id}', extra: plan);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => InteractiveFloorPlanScreen(
            basePath: basePath,
            siteId: siteId,
            floorPlan: plan,
          ),
        ),
      );
    }
  }

  Future<void> _renamePlan(
      BuildContext context, FloorPlan plan) async {
    final controller = TextEditingController(text: plan.name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Floor Plan'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Name',
            prefixIcon: Icon(AppIcons.edit),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (result != null && result.isNotEmpty && result != plan.name) {
      try {
        await FloorPlanService.instance.updateFloorPlan(
          basePath,
          siteId,
          plan.copyWith(name: result),
        );
        if (context.mounted) context.showSuccessToast('Renamed');
      } catch (_) {
        if (context.mounted) context.showErrorToast('Failed to rename');
      }
    }
  }

  Future<void> _deletePlan(BuildContext context, FloorPlan plan) async {
    final confirmed = await showAdaptiveAlertDialog<bool>(
      context: context,
      title: 'Delete Floor Plan',
      message:
          'Delete "${plan.name}"? This will remove the image but won\'t delete any assets.',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      isDestructive: true,
    );

    if (confirmed == true && context.mounted) {
      try {
        await FloorPlanService.instance
            .deleteFloorPlan(basePath, siteId, plan.id, extension: plan.fileExtension);
        if (context.mounted) context.showSuccessToast('Floor plan deleted');
      } catch (_) {
        if (context.mounted) context.showErrorToast('Failed to delete');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text('$siteName — Floor Plans')),
      floatingActionButton: MediaQuery.of(context).viewInsets.bottom > 0
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _navigateToUpload(context),
              icon: const Icon(AppIcons.add),
              label: const Text('Add Floor Plan'),
            ),
      body: StreamBuilder<List<FloorPlan>>(
        stream: FloorPlanService.instance
            .getFloorPlansStream(basePath, siteId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: AdaptiveLoadingIndicator());
          }

          final plans = snapshot.data ?? [];

          if (plans.isEmpty) {
            return EmptyState(
              icon: AppIcons.map,
              title: 'No Floor Plans',
              message:
                  'Upload floor plan images to pin assets to their locations',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: plans.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final plan = plans[index];
              return _FloorPlanCard(
                plan: plan,
                isDark: isDark,
                onTap: () => _navigateToView(context, plan),
                onRename: () => _renamePlan(context, plan),
                onDelete: _canDelete ? () => _deletePlan(context, plan) : null,
              );
            },
          );
        },
      ),
    );
  }
}

class _FloorPlanCard extends StatelessWidget {
  final FloorPlan plan;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback? onDelete;

  const _FloorPlanCard({
    required this.plan,
    required this.isDark,
    required this.onTap,
    required this.onRename,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          boxShadow: isDark ? null : AppTheme.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thumbnail
            SizedBox(
              height: 160,
              child: kIsWeb
                  ? Image.network(
                      plan.imageUrl,
                      fit: BoxFit.cover,
                      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                      errorBuilder: (_, _, _) => Container(
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                        child: Icon(AppIcons.image,
                            size: 40,
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.textSecondary),
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: plan.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                        child: const Center(child: AdaptiveLoadingIndicator()),
                      ),
                      errorWidget: (_, _, _) => Container(
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                        child: Icon(AppIcons.image,
                            size: 40,
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.textSecondary),
                      ),
                    ),
            ),
            // Info row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(AppIcons.map,
                      size: 18,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      plan.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(AppIcons.more,
                        size: 20,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textSecondary),
                    onSelected: (value) {
                      if (value == 'rename') onRename();
                      if (value == 'delete') onDelete?.call();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'rename',
                        child: Row(
                          children: [
                            Icon(AppIcons.edit, size: 18),
                            const SizedBox(width: 8),
                            const Text('Rename'),
                          ],
                        ),
                      ),
                      if (onDelete != null)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline,
                                  size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete',
                                  style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
