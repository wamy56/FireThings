import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/logbook_entry.dart';
import '../../services/logbook_service.dart';
import '../../services/user_profile_service.dart';
import '../../utils/icon_map.dart';
import '../../utils/theme.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/premium_toast.dart';

class AddLogbookEntryScreen extends StatefulWidget {
  final String basePath;
  final String siteId;
  final String? visitId;

  const AddLogbookEntryScreen({
    super.key,
    required this.basePath,
    required this.siteId,
    this.visitId,
  });

  @override
  State<AddLogbookEntryScreen> createState() => _AddLogbookEntryScreenState();
}

class _AddLogbookEntryScreenState extends State<AddLogbookEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _zoneRefController = TextEditingController();
  final _causeController = TextEditingController();
  final _actionController = TextEditingController();

  LogbookEntryType _type = LogbookEntryType.other;
  DateTime _occurredAt = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _zoneRefController.dispose();
    _causeController.dispose();
    _actionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final profile = UserProfileService.instance;
      final entryId = LogbookService.instance
          .generateId(widget.basePath, widget.siteId);
      final entry = LogbookEntry(
        id: entryId,
        siteId: widget.siteId,
        type: _type,
        occurredAt: _occurredAt,
        description: _descriptionController.text.trim(),
        zoneOrDeviceReference: _zoneRefController.text.trim().isNotEmpty
            ? _zoneRefController.text.trim()
            : null,
        cause: _causeController.text.trim().isNotEmpty
            ? _causeController.text.trim()
            : null,
        actionTaken: _actionController.text.trim().isNotEmpty
            ? _actionController.text.trim()
            : null,
        loggedByName: profile.resolveEngineerName(),
        loggedByRole: profile.profile?.companyRole?.name,
        visitId: widget.visitId,
        createdAt: DateTime.now(),
      );

      await LogbookService.instance
          .saveEntry(widget.basePath, widget.siteId, entry);

      if (mounted) {
        context.showSuccessToast('Logbook entry saved');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        context.showErrorToast('Failed to save entry');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    if (time == null || !mounted) return;

    setState(() {
      _occurredAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Logbook Entry'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          children: [
            Text(
              'Entry Type',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: LogbookEntryType.values.map((type) {
                final selected = _type == type;
                return ChoiceChip(
                  label: Text(type.displayLabel),
                  selected: selected,
                  onSelected: (_) => setState(() => _type = type),
                  selectedColor: (isDark
                          ? AppTheme.darkPrimaryBlue
                          : AppTheme.primaryBlue)
                      .withValues(alpha: 0.2),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            InkWell(
              onTap: _pickDateTime,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isDark
                        ? AppTheme.darkSurfaceElevated
                        : Colors.grey.shade300,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(AppIcons.calendar, size: 20,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.mediumGrey),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('dd MMM yyyy HH:mm').format(_occurredAt),
                      style: const TextStyle(fontSize: 15),
                    ),
                    const Spacer(),
                    Icon(AppIcons.arrowRight, size: 16,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.mediumGrey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            CustomTextField(
              controller: _descriptionController,
              label: 'Description',
              hint: 'What happened?',
              prefixIcon: Icon(AppIcons.note),
              maxLines: 3,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (v.trim().length < 5) return 'Minimum 5 characters';
                return null;
              },
            ),
            const SizedBox(height: 12),

            CustomTextField(
              controller: _zoneRefController,
              label: 'Zone / Device Reference',
              hint: 'e.g. Zone 3, MCP-012',
              prefixIcon: Icon(AppIcons.location),
            ),
            const SizedBox(height: 12),

            if (_type == LogbookEntryType.falseAlarm ||
                _type == LogbookEntryType.systemFault) ...[
              CustomTextField(
                controller: _causeController,
                label: 'Cause',
                hint: 'What caused this event?',
                prefixIcon: Icon(AppIcons.infoCircle),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
            ],

            CustomTextField(
              controller: _actionController,
              label: 'Action Taken',
              hint: 'What was done in response?',
              prefixIcon: Icon(AppIcons.taskOutline),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}
