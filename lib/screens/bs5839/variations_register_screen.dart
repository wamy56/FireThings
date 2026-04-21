import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/bs5839_variation.dart';
import '../../services/variation_service.dart';
import '../../utils/icon_map.dart';
import '../../utils/theme.dart';
import '../../widgets/widgets.dart';
import 'add_edit_variation_screen.dart';

class VariationsRegisterScreen extends StatefulWidget {
  final String basePath;
  final String siteId;
  final String siteName;

  const VariationsRegisterScreen({
    super.key,
    required this.basePath,
    required this.siteId,
    required this.siteName,
  });

  @override
  State<VariationsRegisterScreen> createState() =>
      _VariationsRegisterScreenState();
}

class _VariationsRegisterScreenState extends State<VariationsRegisterScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _service = VariationService.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Variations Register'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: StreamBuilder<List<Bs5839Variation>>(
        stream: _service.getVariationsStream(
            widget.basePath, widget.siteId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final all = snapshot.data ?? [];
          final active = all
              .where((v) => v.status == VariationStatus.active)
              .toList();
          final history = all
              .where((v) => v.status != VariationStatus.active)
              .toList();

          final prohibitedCount =
              active.where((v) => v.isProhibited).length;

          return TabBarView(
            controller: _tabController,
            children: [
              _buildTab(active, prohibitedCount, isDark, isEmpty: active.isEmpty),
              _buildTab(history, 0, isDark, isEmpty: history.isEmpty),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addVariation,
        icon: const Icon(AppIcons.add),
        label: const Text('Add Variation'),
      ),
    );
  }

  Widget _buildTab(
    List<Bs5839Variation> variations,
    int prohibitedCount,
    bool isDark, {
    required bool isEmpty,
  }) {
    if (isEmpty) {
      return const EmptyState(
        icon: AppIcons.clipboardTick,
        title: 'No Variations',
        message: 'No variations have been logged for this site.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: variations.length + (prohibitedCount > 0 ? 1 : 0),
      itemBuilder: (context, index) {
        if (prohibitedCount > 0 && index == 0) {
          return _buildProhibitedBanner(prohibitedCount, isDark);
        }
        final adjustedIndex =
            prohibitedCount > 0 ? index - 1 : index;
        return _buildVariationCard(variations[adjustedIndex], isDark);
      },
    );
  }

  Widget _buildProhibitedBanner(int count, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade900.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade400.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(AppIcons.danger, color: Colors.red.shade400, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$count prohibited variation${count == 1 ? '' : 's'} '
              'require${count == 1 ? 's' : ''} remediation — '
              'site cannot be declared satisfactory',
              style: TextStyle(
                color: Colors.red.shade400,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVariationCard(Bs5839Variation variation, bool isDark) {
    final statusColor = _statusColor(variation);
    final dateStr = DateFormat('dd MMM yyyy').format(variation.loggedAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: InkWell(
        onTap: () => _openVariation(variation),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white10 : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      variation.clauseReference,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      variation.isProhibited && variation.status == VariationStatus.active
                          ? 'Prohibited'
                          : variation.status.displayLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(AppIcons.arrowRight,
                      size: 16,
                      color: isDark ? Colors.white38 : Colors.black26),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                variation.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                'Logged $dateStr${variation.loggedByEngineerName != null ? ' by ${variation.loggedByEngineerName}' : ''}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(Bs5839Variation variation) {
    if (variation.isProhibited && variation.status == VariationStatus.active) {
      return Colors.red;
    }
    switch (variation.status) {
      case VariationStatus.active:
        return Colors.green;
      case VariationStatus.rectified:
        return Colors.grey;
      case VariationStatus.supersededByModification:
        return Colors.grey;
    }
  }

  void _addVariation() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddEditVariationScreen(
          basePath: widget.basePath,
          siteId: widget.siteId,
        ),
      ),
    );
  }

  void _openVariation(Bs5839Variation variation) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddEditVariationScreen(
          basePath: widget.basePath,
          siteId: widget.siteId,
          variation: variation,
        ),
      ),
    );
  }
}
