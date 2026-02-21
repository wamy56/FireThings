import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../utils/theme.dart';

/// Base shimmer widget for skeleton loading effects
class SkeletonShimmer extends StatelessWidget {
  final Widget child;
  final bool enabled;

  const SkeletonShimmer({super.key, required this.child, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark ? AppTheme.darkSurfaceElevated : AppTheme.lightGrey,
      highlightColor: isDark
          ? AppTheme.darkSurface.withValues(alpha: 0.5)
          : Colors.white.withValues(alpha: 0.8),
      child: child,
    );
  }
}

/// Simple skeleton box placeholder
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 4,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceElevated : AppTheme.lightGrey,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Skeleton circle placeholder (for avatars)
class SkeletonCircle extends StatelessWidget {
  final double size;

  const SkeletonCircle({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceElevated : AppTheme.lightGrey,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Skeleton text line placeholder
class SkeletonLine extends StatelessWidget {
  final double? width;
  final double height;

  const SkeletonLine({super.key, this.width, this.height = 14});

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(width: width, height: height, borderRadius: height / 2);
  }
}

/// Skeleton paragraph with multiple lines
class SkeletonParagraph extends StatelessWidget {
  final int lines;
  final double lineHeight;
  final double spacing;

  const SkeletonParagraph({
    super.key,
    this.lines = 3,
    this.lineHeight = 14,
    this.spacing = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(lines, (index) {
        // Make last line shorter
        final isLast = index == lines - 1;
        return Padding(
          padding: EdgeInsets.only(bottom: index < lines - 1 ? spacing : 0),
          child: SkeletonLine(
            width: isLast ? MediaQuery.of(context).size.width * 0.6 : null,
            height: lineHeight,
          ),
        );
      }),
    );
  }
}

/// Skeleton card - common card loading placeholder
class SkeletonCard extends StatelessWidget {
  final double? height;
  final bool showImage;
  final bool showAvatar;

  const SkeletonCard({
    super.key,
    this.height,
    this.showImage = false,
    this.showAvatar = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SkeletonShimmer(
      child: Container(
        height: height,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showImage) ...[
              const SkeletonBox(height: 120, borderRadius: 8),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                if (showAvatar) ...[
                  const SkeletonCircle(size: 40),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SkeletonLine(width: 120),
                      SizedBox(height: 6),
                      SkeletonLine(width: 80, height: 12),
                    ],
                  ),
                ),
              ],
            ),
            if (!showImage) ...[
              const SizedBox(height: 12),
              const SkeletonParagraph(lines: 2),
            ],
          ],
        ),
      ),
    );
  }
}

/// Skeleton list item
class SkeletonListItem extends StatelessWidget {
  final bool showLeading;
  final bool showTrailing;
  final double? leadingSize;

  const SkeletonListItem({
    super.key,
    this.showLeading = true,
    this.showTrailing = false,
    this.leadingSize,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SkeletonShimmer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            if (showLeading) ...[
              SkeletonCircle(size: leadingSize ?? 48),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonLine(width: 140),
                  SizedBox(height: 6),
                  SkeletonLine(width: 100, height: 12),
                ],
              ),
            ),
            if (showTrailing) const SkeletonBox(width: 60, height: 28),
          ],
        ),
      ),
    );
  }
}

/// Skeleton list - generates multiple skeleton list items
class SkeletonList extends StatelessWidget {
  final int itemCount;
  final double spacing;
  final bool showLeading;
  final bool showTrailing;

  const SkeletonList({
    super.key,
    this.itemCount = 5,
    this.spacing = 8,
    this.showLeading = true,
    this.showTrailing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(itemCount, (index) {
        return Padding(
          padding: EdgeInsets.only(bottom: index < itemCount - 1 ? spacing : 0),
          child: SkeletonListItem(
            showLeading: showLeading,
            showTrailing: showTrailing,
          ),
        );
      }),
    );
  }
}

/// Skeleton grid for image grids
class SkeletonGrid extends StatelessWidget {
  final int itemCount;
  final int crossAxisCount;
  final double spacing;
  final double aspectRatio;

  const SkeletonGrid({
    super.key,
    this.itemCount = 6,
    this.crossAxisCount = 2,
    this.spacing = 8,
    this.aspectRatio = 1,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SkeletonShimmer(
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          childAspectRatio: aspectRatio,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurfaceElevated : AppTheme.lightGrey,
              borderRadius: BorderRadius.circular(12),
            ),
          );
        },
      ),
    );
  }
}

/// Loading state builder that shows skeleton while loading
class SkeletonLoadingBuilder extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final Widget skeleton;

  const SkeletonLoadingBuilder({
    super.key,
    required this.isLoading,
    required this.child,
    required this.skeleton,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppTheme.normalAnimation,
      child: isLoading ? skeleton : child,
    );
  }
}
