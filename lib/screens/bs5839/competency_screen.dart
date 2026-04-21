import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/engineer_competency.dart';
import '../../services/competency_service.dart';
import '../../services/remote_config_service.dart';
import '../../services/user_profile_service.dart';
import '../../utils/adaptive_widgets.dart';
import '../../utils/icon_map.dart';
import '../../utils/theme.dart';
import '../../widgets/widgets.dart';

class CompetencyScreen extends StatefulWidget {
  const CompetencyScreen({super.key});

  @override
  State<CompetencyScreen> createState() => _CompetencyScreenState();
}

class _CompetencyScreenState extends State<CompetencyScreen>
    with SingleTickerProviderStateMixin {
  final _service = CompetencyService.instance;
  final _rc = RemoteConfigService.instance;

  late final TabController _tabController;

  String _basePath = '';
  String _memberId = '';
  bool _isLoading = true;
  EngineerCompetency? _competency;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ups = UserProfileService.instance;
    final companyId = ups.companyId;
    _basePath =
        companyId != null ? 'companies/$companyId' : 'users/${user.uid}';
    _memberId = user.uid;

    _competency = await _service.ensureCompetencyExists(
      _basePath,
      _memberId,
      user.displayName ?? 'Unknown',
    );

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Competency Record'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Qualifications'),
            Tab(text: 'CPD Records'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: AdaptiveLoadingIndicator())
          : Column(
              children: [
                _buildSummaryCard(isDark),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildQualificationsTab(isDark),
                      _buildCpdTab(isDark),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryCard(bool isDark) {
    if (_competency == null) return const SizedBox.shrink();

    final minHours = _rc.bs5839MinCpdHoursPerYear;
    final hours = _competency!.totalCpdHoursLast12Months;
    final meetsCpd = hours >= minHours;

    final expiring = _service.getExpiringQualifications(_competency!);
    final expired = _service.getExpiredQualifications(_competency!);

    final hasIssues = !meetsCpd || expired.isNotEmpty;
    final hasWarnings = expiring.isNotEmpty && expired.isEmpty;

    Color statusColor;
    String statusLabel;
    if (hasIssues) {
      statusColor = Colors.red;
      statusLabel = 'Action Required';
    } else if (hasWarnings) {
      statusColor = Colors.orange;
      statusLabel = 'Attention Needed';
    } else {
      statusColor = Colors.green;
      statusLabel = 'Up to Date';
    }

    return Container(
      margin: const EdgeInsets.all(AppTheme.screenPadding),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              hasIssues
                  ? AppIcons.danger
                  : (hasWarnings ? AppIcons.warning : AppIcons.tickCircle),
              color: statusColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${hours.toStringAsFixed(1)} CPD hours (last 12 months)',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey, fontSize: 12),
                ),
                if (!meetsCpd)
                  Text(
                    'Minimum ${minHours.toStringAsFixed(0)} hours required',
                    style: TextStyle(
                        color: Colors.red.shade400, fontSize: 12),
                  ),
                if (expired.isNotEmpty)
                  Text(
                    '${expired.length} expired qualification${expired.length == 1 ? '' : 's'}',
                    style: TextStyle(
                        color: Colors.red.shade400, fontSize: 12),
                  ),
                if (expiring.isNotEmpty && expired.isEmpty)
                  Text(
                    '${expiring.length} expiring within 30 days',
                    style: const TextStyle(
                        color: Colors.orange, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Qualifications Tab ────────────────────────────────────────────

  Widget _buildQualificationsTab(bool isDark) {
    final quals = _competency?.qualifications ?? [];

    if (quals.isEmpty) {
      return Column(
        children: [
          const Expanded(
            child: EmptyState(
              icon: AppIcons.medal,
              title: 'No Qualifications',
              message: 'Add your fire safety qualifications and certifications.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppTheme.screenPadding),
            child: AnimatedSaveButton(
              label: 'Add Qualification',
              onPressed: () async => _showQualificationDialog(),
              backgroundColor: AppTheme.primaryBlue,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
            itemCount: quals.length,
            itemBuilder: (context, index) =>
                _buildQualificationCard(quals[index], isDark),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          child: AnimatedSaveButton(
            label: 'Add Qualification',
            onPressed: () async => _showQualificationDialog(),
            backgroundColor: AppTheme.primaryBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildQualificationCard(Qualification qual, bool isDark) {
    final now = DateTime.now();
    final isExpired =
        qual.expiryDate != null && qual.expiryDate!.isBefore(now);
    final isExpiring = qual.expiryDate != null &&
        !isExpired &&
        qual.expiryDate!
            .isBefore(now.add(const Duration(days: 90)));

    Color borderColor;
    if (isExpired) {
      borderColor = Colors.red.withValues(alpha: 0.4);
    } else if (isExpiring) {
      borderColor = Colors.orange.withValues(alpha: 0.4);
    } else {
      borderColor = isDark ? Colors.white12 : Colors.grey.shade200;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  qual.type == QualificationType.other
                      ? (qual.customTypeName ?? 'Other')
                      : qual.type.displayLabel,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  qual.issuingBody,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Issued: ${DateFormat('dd MMM yyyy').format(qual.issuedDate)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    if (qual.expiryDate != null) ...[
                      const SizedBox(width: 12),
                      Text(
                        'Expires: ${DateFormat('dd MMM yyyy').format(qual.expiryDate!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isExpired
                              ? Colors.red
                              : (isExpiring ? Colors.orange : Colors.grey),
                          fontWeight: (isExpired || isExpiring)
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ],
                ),
                if (qual.certificateNumber != null &&
                    qual.certificateNumber!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Cert: ${qual.certificateNumber}',
                      style:
                          const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
          if (isExpired)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Expired',
                style: TextStyle(
                    color: Colors.red,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            )
          else if (isExpiring)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Expiring',
                style: TextStyle(
                    color: Colors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: Icon(AppIcons.more,
                size: 18,
                color: isDark ? Colors.white54 : Colors.black45),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
            onSelected: (v) {
              if (v == 'edit') {
                _showQualificationDialog(existing: qual);
              } else if (v == 'delete') {
                _deleteQualification(qual);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showQualificationDialog({Qualification? existing}) async {
    final result = await showDialog<Qualification>(
      context: context,
      builder: (_) => _QualificationDialog(existing: existing),
    );
    if (result == null) return;

    if (existing != null) {
      await _service.updateQualification(_basePath, _memberId, result);
    } else {
      await _service.addQualification(_basePath, _memberId, result);
    }
    await _refresh();
  }

  Future<void> _deleteQualification(Qualification qual) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Qualification?'),
        content: Text('Remove ${qual.type.displayLabel}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;

    await _service.removeQualification(_basePath, _memberId, qual.id);
    await _refresh();
  }

  // ─── CPD Tab ───────────────────────────────────────────────────────

  Widget _buildCpdTab(bool isDark) {
    final records = _competency?.cpdRecords ?? [];
    final sorted = List<CpdRecord>.from(records)
      ..sort((a, b) => b.date.compareTo(a.date));

    if (sorted.isEmpty) {
      return Column(
        children: [
          const Expanded(
            child: EmptyState(
              icon: AppIcons.book,
              title: 'No CPD Records',
              message:
                  'Track your continuing professional development hours here.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppTheme.screenPadding),
            child: AnimatedSaveButton(
              label: 'Add CPD Record',
              onPressed: () async => _showCpdDialog(),
              backgroundColor: AppTheme.primaryBlue,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
            itemCount: sorted.length,
            itemBuilder: (context, index) =>
                _buildCpdCard(sorted[index], isDark),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          child: AnimatedSaveButton(
            label: 'Add CPD Record',
            onPressed: () async => _showCpdDialog(),
            backgroundColor: AppTheme.primaryBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildCpdCard(CpdRecord record, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '${record.hours.toStringAsFixed(record.hours == record.hours.roundToDouble() ? 0 : 1)}h',
                style: TextStyle(
                  color: AppTheme.primaryBlue,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.topic,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('dd MMM yyyy').format(record.date) +
                      (record.provider != null && record.provider!.isNotEmpty
                          ? ' · ${record.provider}'
                          : ''),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey, fontSize: 12),
                ),
                if (record.notes != null && record.notes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      record.notes!,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(AppIcons.more,
                size: 18,
                color: isDark ? Colors.white54 : Colors.black45),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
            onSelected: (v) {
              if (v == 'edit') {
                _showCpdDialog(existing: record);
              } else if (v == 'delete') {
                _deleteCpdRecord(record);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showCpdDialog({CpdRecord? existing}) async {
    final result = await showDialog<CpdRecord>(
      context: context,
      builder: (_) => _CpdDialog(existing: existing),
    );
    if (result == null) return;

    if (existing != null) {
      await _service.updateCpdRecord(_basePath, _memberId, result);
    } else {
      await _service.addCpdRecord(_basePath, _memberId, result);
    }
    await _refresh();
  }

  Future<void> _deleteCpdRecord(CpdRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete CPD Record?'),
        content: Text('Remove "${record.topic}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;

    await _service.removeCpdRecord(_basePath, _memberId, record.id);
    await _refresh();
  }

  Future<void> _refresh() async {
    _competency = await _service.getCompetency(_basePath, _memberId);
    if (mounted) setState(() {});
  }
}

// ─── Qualification Dialog ──────────────────────────────────────────────

class _QualificationDialog extends StatefulWidget {
  final Qualification? existing;

  const _QualificationDialog({this.existing});

  @override
  State<_QualificationDialog> createState() => _QualificationDialogState();
}

class _QualificationDialogState extends State<_QualificationDialog> {
  static const _uuid = Uuid();

  late QualificationType _type;
  late final TextEditingController _customNameController;
  late final TextEditingController _issuingBodyController;
  late final TextEditingController _certNumberController;
  DateTime _issuedDate = DateTime.now();
  DateTime? _expiryDate;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? QualificationType.fiaUnit1;
    _customNameController =
        TextEditingController(text: e?.customTypeName ?? '');
    _issuingBodyController =
        TextEditingController(text: e?.issuingBody ?? '');
    _certNumberController =
        TextEditingController(text: e?.certificateNumber ?? '');
    if (e != null) {
      _issuedDate = e.issuedDate;
      _expiryDate = e.expiryDate;
    }
  }

  @override
  void dispose() {
    _customNameController.dispose();
    _issuingBodyController.dispose();
    _certNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          widget.existing != null ? 'Edit Qualification' : 'Add Qualification'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<QualificationType>(
              initialValue: _type,
              decoration: InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: QualificationType.values
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t.displayLabel,
                            style: const TextStyle(fontSize: 14)),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _type = v);
              },
            ),
            if (_type == QualificationType.other) ...[
              const SizedBox(height: 12),
              CustomTextField(
                controller: _customNameController,
                label: 'Custom Name',
                hint: 'e.g. NVQ Level 3',
              ),
            ],
            const SizedBox(height: 12),
            CustomTextField(
              controller: _issuingBodyController,
              label: 'Issuing Body',
              hint: 'e.g. FIA, ECA, BAFE',
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _certNumberController,
              label: 'Certificate Number',
              hint: 'Optional',
            ),
            const SizedBox(height: 12),
            _buildDateTile('Issued Date', _issuedDate, (d) {
              setState(() => _issuedDate = d);
            }),
            const SizedBox(height: 8),
            _buildDateTile(
              'Expiry Date',
              _expiryDate,
              (d) => setState(() => _expiryDate = d),
              allowClear: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            if (_issuingBodyController.text.trim().isEmpty) return;
            final qual = Qualification(
              id: widget.existing?.id ?? _uuid.v4(),
              type: _type,
              customTypeName: _type == QualificationType.other
                  ? _customNameController.text.trim()
                  : null,
              issuingBody: _issuingBodyController.text.trim(),
              issuedDate: _issuedDate,
              expiryDate: _expiryDate,
              certificateNumber: _certNumberController.text.trim().isNotEmpty
                  ? _certNumberController.text.trim()
                  : null,
              evidenceFileUrl: widget.existing?.evidenceFileUrl,
            );
            Navigator.pop(context, qual);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildDateTile(
      String label, DateTime? date, ValueChanged<DateTime> onPicked,
      {bool allowClear = false}) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2040),
        );
        if (picked != null) onPicked(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                date != null
                    ? '$label: ${DateFormat('dd MMM yyyy').format(date)}'
                    : '$label: Not set',
                style: TextStyle(
                  fontSize: 14,
                  color: date != null ? null : Colors.grey,
                ),
              ),
            ),
            if (allowClear && date != null)
              GestureDetector(
                onTap: () => onPicked(DateTime(1970)),
                child: const Icon(Icons.close, size: 16, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── CPD Dialog ────────────────────────────────────────────────────────

class _CpdDialog extends StatefulWidget {
  final CpdRecord? existing;

  const _CpdDialog({this.existing});

  @override
  State<_CpdDialog> createState() => _CpdDialogState();
}

class _CpdDialogState extends State<_CpdDialog> {
  static const _uuid = Uuid();

  late final TextEditingController _topicController;
  late final TextEditingController _hoursController;
  late final TextEditingController _providerController;
  late final TextEditingController _notesController;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _topicController = TextEditingController(text: e?.topic ?? '');
    _hoursController =
        TextEditingController(text: e != null ? e.hours.toString() : '');
    _providerController =
        TextEditingController(text: e?.provider ?? '');
    _notesController = TextEditingController(text: e?.notes ?? '');
    if (e != null) _date = e.date;
  }

  @override
  void dispose() {
    _topicController.dispose();
    _hoursController.dispose();
    _providerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title:
          Text(widget.existing != null ? 'Edit CPD Record' : 'Add CPD Record'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomTextField(
              controller: _topicController,
              label: 'Topic',
              hint: 'e.g. BS 5839-1:2025 Updates',
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _hoursController,
              label: 'Hours',
              hint: 'e.g. 4',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Text(
                      'Date: ${DateFormat('dd MMM yyyy').format(_date)}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const Spacer(),
                    const Icon(AppIcons.calendar, size: 16, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _providerController,
              label: 'Provider',
              hint: 'Optional',
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _notesController,
              label: 'Notes',
              hint: 'Optional',
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            final topic = _topicController.text.trim();
            final hours = double.tryParse(_hoursController.text.trim());
            if (topic.isEmpty || hours == null || hours <= 0) return;

            final record = CpdRecord(
              id: widget.existing?.id ?? _uuid.v4(),
              date: _date,
              topic: topic,
              hours: hours,
              provider: _providerController.text.trim().isNotEmpty
                  ? _providerController.text.trim()
                  : null,
              notes: _notesController.text.trim().isNotEmpty
                  ? _notesController.text.trim()
                  : null,
              evidenceFileUrl: widget.existing?.evidenceFileUrl,
            );
            Navigator.pop(context, record);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
