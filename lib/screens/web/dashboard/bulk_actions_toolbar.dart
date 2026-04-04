import 'package:flutter/material.dart';
import '../../../models/dispatched_job.dart';
import '../../../models/company_member.dart';
import '../../../services/dispatch_service.dart';
import '../../../utils/theme.dart';
import '../../../utils/icon_map.dart';
import 'job_helpers.dart';

class BulkActionsToolbar extends StatelessWidget {
  final Set<String> selectedJobIds;
  final List<String> pageJobIds;
  final List<CompanyMember> members;
  final String companyId;
  final VoidCallback onClearSelection;
  final VoidCallback onSelectionChanged;

  const BulkActionsToolbar({
    super.key,
    required this.selectedJobIds,
    required this.pageJobIds,
    required this.members,
    required this.companyId,
    required this.onClearSelection,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allPageSelected = pageJobIds.every((id) => selectedJobIds.contains(id));

    return AnimatedContainer(
      duration: AppTheme.fastAnimation,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha: isDark ? 0.2 : 0.08),
        border: Border(
          left: BorderSide(color: AppTheme.primaryBlue, width: 3),
          bottom: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: allPageSelected,
            onChanged: (v) {
              if (v == true) {
                selectedJobIds.addAll(pageJobIds);
              } else {
                selectedJobIds.removeAll(pageJobIds);
              }
              onSelectionChanged();
            },
          ),
          Text(
            '${selectedJobIds.length} selected',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(width: 16),
          _ActionButton(
            icon: AppIcons.userAdd,
            label: 'Assign',
            onPressed: () => _showBulkAssignDialog(context),
          ),
          const SizedBox(width: 8),
          _ActionButton(
            icon: AppIcons.refresh,
            label: 'Status',
            onPressed: () => _showBulkStatusDialog(context),
          ),
          const SizedBox(width: 8),
          _ActionButton(
            icon: AppIcons.warning,
            label: 'Priority',
            onPressed: () => _showBulkPriorityDialog(context),
          ),
          const SizedBox(width: 8),
          _ActionButton(
            icon: AppIcons.calendar,
            label: 'Set Date',
            onPressed: () => _showBulkDatePicker(context),
          ),
          const SizedBox(width: 8),
          _ActionButton(
            icon: AppIcons.trash,
            label: 'Delete',
            color: Colors.red,
            onPressed: () => _showBulkDeleteDialog(context),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(AppIcons.close, size: 18),
            onPressed: onClearSelection,
            tooltip: 'Deselect all',
          ),
        ],
      ),
    );
  }

  void _showBulkAssignDialog(BuildContext context) {
    String? selectedUid;
    String? selectedName;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Assign ${selectedJobIds.length} Jobs'),
          content: DropdownButtonFormField<String?>(
            decoration: InputDecoration(
              labelText: 'Engineer',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: members
                .map((m) => DropdownMenuItem(
                      value: m.uid,
                      child: Text(m.displayName),
                    ))
                .toList(),
            onChanged: (v) {
              final member = members.where((m) => m.uid == v).firstOrNull;
              setDialogState(() {
                selectedUid = v;
                selectedName = member?.displayName;
              });
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedUid == null
                  ? null
                  : () async {
                      for (final jobId in selectedJobIds) {
                        await DispatchService.instance.assignJob(
                          companyId: companyId,
                          jobId: jobId,
                          engineerUid: selectedUid!,
                          engineerName: selectedName!,
                        );
                      }
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      onClearSelection();
                    },
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBulkStatusDialog(BuildContext context) {
    DispatchedJobStatus? selected;
    final statuses = DispatchedJobStatus.values
        .where((s) => s != DispatchedJobStatus.declined)
        .toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Change Status — ${selectedJobIds.length} Jobs'),
          content: DropdownButtonFormField<DispatchedJobStatus>(
            decoration: InputDecoration(
              labelText: 'New Status',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: statuses
                .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(jobStatusLabel(s)),
                    ))
                .toList(),
            onChanged: (v) => setDialogState(() => selected = v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selected == null
                  ? null
                  : () async {
                      await DispatchService.instance.bulkUpdateStatus(
                        companyId: companyId,
                        jobIds: selectedJobIds,
                        newStatus: selected!,
                      );
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      onClearSelection();
                    },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBulkPriorityDialog(BuildContext context) {
    JobPriority selected = JobPriority.normal;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Change Priority — ${selectedJobIds.length} Jobs'),
          content: SegmentedButton<JobPriority>(
            segments: const [
              ButtonSegment(value: JobPriority.normal, label: Text('Normal')),
              ButtonSegment(value: JobPriority.urgent, label: Text('Urgent')),
              ButtonSegment(value: JobPriority.emergency, label: Text('Emergency')),
            ],
            selected: {selected},
            onSelectionChanged: (v) => setDialogState(() => selected = v.first),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await DispatchService.instance.bulkUpdatePriority(
                  companyId: companyId,
                  jobIds: selectedJobIds,
                  newPriority: selected,
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
                onClearSelection();
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBulkDatePicker(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      await DispatchService.instance.bulkUpdateDate(
        companyId: companyId,
        jobIds: selectedJobIds,
        newDate: picked,
      );
      onClearSelection();
    }
  }

  void _showBulkDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Jobs'),
        content: Text(
          'Permanently delete ${selectedJobIds.length} jobs? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await DispatchService.instance.bulkDelete(
                companyId: companyId,
                jobIds: selectedJobIds,
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
              onClearSelection();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(color: color)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        textStyle: const TextStyle(fontSize: 13),
        side: color != null ? BorderSide(color: color!) : null,
      ),
    );
  }
}
