import 'package:flutter/material.dart';

import '../models/bs5839_variation.dart';
import '../services/variation_service.dart';
import '../utils/icon_map.dart';

class ProhibitedVariationsAlert extends StatelessWidget {
  final String basePath;
  final String siteId;
  final VoidCallback? onTap;

  const ProhibitedVariationsAlert({
    super.key,
    required this.basePath,
    required this.siteId,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Bs5839Variation>>(
      stream: VariationService.instance
          .getProhibitedVariationsStream(basePath, siteId),
      builder: (context, snapshot) {
        final prohibited = snapshot.data ?? [];
        if (prohibited.isEmpty) return const SizedBox.shrink();

        final count = prohibited.length;
        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.red.shade900.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: Colors.red.shade400.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(AppIcons.danger, color: Colors.red.shade400, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$count prohibited variation${count == 1 ? '' : 's'} '
                    'require${count == 1 ? 's' : ''} remediation',
                    style: TextStyle(
                      color: Colors.red.shade400,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (onTap != null)
                  Text(
                    'View',
                    style: TextStyle(
                      color: Colors.red.shade400,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
