import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../utils/theme.dart';
import '../utils/icon_map.dart';
import '../utils/adaptive_widgets.dart';

class SelectionAppBar extends StatelessWidget implements PreferredSizeWidget {
  final int selectedCount;
  final bool isAllSelected;
  final VoidCallback onClose;
  final ValueChanged<bool> onSelectAll;
  final VoidCallback onDelete;

  const SelectionAppBar({
    super.key,
    required this.selectedCount,
    required this.isAllSelected,
    required this.onClose,
    required this.onSelectAll,
    required this.onDelete,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isApple) {
      return _buildCupertinoBar(context);
    }
    return _buildMaterialBar(context);
  }

  Widget _buildCupertinoBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.darkBackground : AppTheme.backgroundGrey;

    return CupertinoNavigationBar(
      leading: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onClose,
        child: Icon(
          CupertinoIcons.xmark,
          color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
        ),
      ),
      middle: Text(
        '$selectedCount selected',
        style: TextStyle(
          color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => onSelectAll(!isAllSelected),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isAllSelected
                      ? CupertinoIcons.checkmark_square_fill
                      : CupertinoIcons.square,
                  size: 22,
                  color: isAllSelected
                      ? AppTheme.primaryBlue
                      : (isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                ),
                const SizedBox(width: 4),
                Text(
                  'All',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: selectedCount > 0 ? onDelete : null,
            child: Icon(
              CupertinoIcons.trash,
              color: selectedCount > 0
                  ? AppTheme.errorRed
                  : (isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey),
            ),
          ),
        ],
      ),
      backgroundColor: bgColor,
      border: Border(
        bottom: BorderSide(
          color: isDark ? AppTheme.darkDivider : AppTheme.dividerColor,
          width: 0.5,
        ),
      ),
    );
  }

  Widget _buildMaterialBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: onClose,
      ),
      title: Text('$selectedCount selected'),
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.backgroundGrey,
      elevation: 0,
      actions: [
        GestureDetector(
          onTap: () => onSelectAll(!isAllSelected),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isAllSelected
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  size: 22,
                  color: isAllSelected
                      ? AppTheme.primaryBlue
                      : (isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                ),
                const SizedBox(width: 4),
                Text(
                  'All',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          icon: Icon(AppIcons.trash),
          color: selectedCount > 0 ? AppTheme.errorRed : null,
          onPressed: selectedCount > 0 ? onDelete : null,
        ),
      ],
    );
  }
}
