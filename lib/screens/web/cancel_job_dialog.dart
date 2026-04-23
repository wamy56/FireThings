import 'package:flutter/material.dart';
import '../../theme/web_theme.dart';

class CancelJobDialog extends StatefulWidget {
  const CancelJobDialog({super.key});

  @override
  State<CancelJobDialog> createState() => _CancelJobDialogState();
}

class _CancelJobDialogState extends State<CancelJobDialog> {
  String? _selectedReason;
  final _customReasonController = TextEditingController();

  static const _reasons = [
    'Customer cancelled',
    'Scheduling conflict',
    'Job no longer needed',
    'Duplicate job',
    'Other',
  ];

  @override
  void dispose() {
    _customReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: FtRadii.lgAll),
      title: const Text('Cancel Job'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select a reason for cancellation:', style: FtText.bodySoft),
            const SizedBox(height: 12),
            RadioGroup<String>(
              groupValue: _selectedReason ?? '',
              onChanged: (value) {
                setState(() => _selectedReason = value);
              },
              child: Column(
                children: _reasons.map((reason) {
                  return RadioListTile<String>(
                    value: reason,
                    title: Text(reason, style: FtText.inter(size: 14, weight: FontWeight.w500, color: FtColors.fg1)),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  );
                }).toList(),
              ),
            ),
            if (_selectedReason == 'Other') ...[
              const SizedBox(height: 8),
              TextField(
                controller: _customReasonController,
                decoration: InputDecoration(
                  hintText: 'Enter reason...',
                  border: OutlineInputBorder(borderRadius: FtRadii.mdAll),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: FtRadii.mdAll,
                    borderSide: BorderSide(color: FtColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: FtRadii.mdAll,
                    borderSide: BorderSide(color: FtColors.primary),
                  ),
                ),
                maxLines: 2,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: FtColors.fg2),
          child: const Text('Back'),
        ),
        TextButton(
          onPressed: _selectedReason == null
              ? null
              : () {
                  final reason = _selectedReason == 'Other'
                      ? _customReasonController.text.trim().isEmpty
                          ? 'Cancelled by dispatcher'
                          : _customReasonController.text.trim()
                      : _selectedReason!;
                  Navigator.of(context).pop(reason);
                },
          style: TextButton.styleFrom(foregroundColor: FtColors.danger),
          child: const Text('Cancel Job'),
        ),
      ],
    );
  }
}
