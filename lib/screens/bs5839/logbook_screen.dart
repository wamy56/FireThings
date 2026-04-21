import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/logbook_entry.dart';
import '../../services/logbook_service.dart';
import '../../services/user_profile_service.dart';
import '../../models/permission.dart';
import '../../utils/icon_map.dart';
import '../../utils/theme.dart';
import '../../widgets/widgets.dart';
import 'add_logbook_entry_screen.dart';

class LogbookScreen extends StatefulWidget {
  final String basePath;
  final String siteId;
  final String siteName;
  final String? visitId;

  const LogbookScreen({
    super.key,
    required this.basePath,
    required this.siteId,
    required this.siteName,
    this.visitId,
  });

  @override
  State<LogbookScreen> createState() => _LogbookScreenState();
}

class _LogbookScreenState extends State<LogbookScreen> {
  LogbookEntryType? _typeFilter;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Logbook — ${widget.siteName}'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addEntry,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          _buildFilterChips(isDark),
          Expanded(
            child: StreamBuilder<List<LogbookEntry>>(
              stream: LogbookService.instance
                  .getEntriesStream(widget.basePath, widget.siteId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var entries = snapshot.data ?? [];
                if (_typeFilter != null) {
                  entries = entries
                      .where((e) => e.type == _typeFilter)
                      .toList();
                }

                if (entries.isEmpty) {
                  return EmptyState(
                    icon: AppIcons.book,
                    title: 'No Logbook Entries',
                    message: _typeFilter != null
                        ? 'No entries of this type.'
                        : 'No logbook entries have been recorded for this site.',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: entries.length,
                  itemBuilder: (context, index) =>
                      _buildEntryCard(context, entries[index], isDark),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('All'),
              selected: _typeFilter == null,
              onSelected: (_) => setState(() => _typeFilter = null),
              selectedColor: (isDark
                      ? AppTheme.darkPrimaryBlue
                      : AppTheme.primaryBlue)
                  .withValues(alpha: 0.2),
            ),
          ),
          for (final type in LogbookEntryType.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(type.displayLabel),
                selected: _typeFilter == type,
                onSelected: (_) => setState(
                    () => _typeFilter = _typeFilter == type ? null : type),
                selectedColor: (isDark
                        ? AppTheme.darkPrimaryBlue
                        : AppTheme.primaryBlue)
                    .withValues(alpha: 0.2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(
      BuildContext context, LogbookEntry entry, bool isDark) {
    final dateStr =
        DateFormat('dd MMM yyyy HH:mm').format(entry.occurredAt);
    final typeColor = _colorForType(entry.type);
    final canDelete =
        UserProfileService.instance.hasPermission(AppPermission.companyEdit);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius)),
      color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
      elevation: isDark ? 0 : 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    entry.type.displayLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: typeColor,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
                  ),
                ),
                if (canDelete) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _confirmDelete(entry),
                    child: Icon(AppIcons.trash, size: 16,
                        color: AppTheme.errorRed.withValues(alpha: 0.6)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              entry.description,
              style: const TextStyle(fontSize: 14),
            ),
            if (entry.zoneOrDeviceReference != null) ...[
              const SizedBox(height: 4),
              Text(
                'Zone/Device: ${entry.zoneOrDeviceReference}',
                style: TextStyle(
                  fontSize: 12,
                  color:
                      isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
                ),
              ),
            ],
            if (entry.cause != null) ...[
              const SizedBox(height: 4),
              Text(
                'Cause: ${entry.cause}',
                style: TextStyle(
                  fontSize: 12,
                  color:
                      isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
                ),
              ),
            ],
            if (entry.actionTaken != null) ...[
              const SizedBox(height: 4),
              Text(
                'Action: ${entry.actionTaken}',
                style: TextStyle(
                  fontSize: 12,
                  color:
                      isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
                ),
              ),
            ],
            if (entry.loggedByName != null) ...[
              const SizedBox(height: 6),
              Text(
                'Logged by: ${entry.loggedByName}${entry.loggedByRole != null ? ' (${entry.loggedByRole})' : ''}',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color:
                      isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _addEntry() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddLogbookEntryScreen(
          basePath: widget.basePath,
          siteId: widget.siteId,
          visitId: widget.visitId,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(LogbookEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text(
            'Are you sure you want to delete this logbook entry? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await LogbookService.instance
            .deleteEntry(widget.basePath, widget.siteId, entry.id);
      } catch (e) {
        if (mounted) {
          context.showErrorToast('Failed to delete entry');
        }
      }
    }
  }

  Color _colorForType(LogbookEntryType type) {
    switch (type) {
      case LogbookEntryType.falseAlarm:
        return AppTheme.accentOrange;
      case LogbookEntryType.realAlarm:
        return AppTheme.errorRed;
      case LogbookEntryType.systemFault:
        return AppTheme.errorRed;
      case LogbookEntryType.disablement:
        return Colors.deepPurple;
      case LogbookEntryType.reinstatement:
        return AppTheme.successGreen;
      case LogbookEntryType.serviceVisit:
        return AppTheme.primaryBlue;
      case LogbookEntryType.modification:
        return Colors.teal;
      case LogbookEntryType.testOfSystem:
        return AppTheme.primaryBlue;
      case LogbookEntryType.other:
        return AppTheme.mediumGrey;
    }
  }
}
