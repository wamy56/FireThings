import 'package:flutter/material.dart';

class DeclineJobDialog extends StatefulWidget {
  const DeclineJobDialog({super.key});

  @override
  State<DeclineJobDialog> createState() => _DeclineJobDialogState();
}

class _DeclineJobDialogState extends State<DeclineJobDialog> {
  String? _selectedReason;
  final _customReasonController = TextEditingController();

  static const _quickReasons = [
    'Not available on this date',
    'Too far from current location',
    'Already have a job at this time',
    'Need more information',
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
      title: const Text('Decline Job'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select a reason:'),
            const SizedBox(height: 12),
            RadioGroup<String>(
              groupValue: _selectedReason ?? '',
              onChanged: (value) {
                setState(() => _selectedReason = value);
              },
              child: Column(
                children: _quickReasons.map((reason) {
                  return RadioListTile<String>(
                    value: reason,
                    title: Text(reason, style: const TextStyle(fontSize: 14)),
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
                decoration: const InputDecoration(
                  hintText: 'Enter reason...',
                  border: OutlineInputBorder(),
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
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _selectedReason == null
              ? null
              : () {
                  final reason = _selectedReason == 'Other'
                      ? _customReasonController.text.trim().isEmpty
                          ? 'Other'
                          : _customReasonController.text.trim()
                      : _selectedReason!;
                  Navigator.of(context).pop(reason);
                },
          child: const Text(
            'Decline',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
  }
}
