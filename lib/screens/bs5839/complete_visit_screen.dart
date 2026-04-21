import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';

import '../../models/bs5839_variation.dart';
import '../../models/inspection_visit.dart';
import '../../services/bs5839_compliance_service.dart';
import '../../services/inspection_visit_service.dart';
import '../../services/variation_service.dart';
import '../../utils/adaptive_widgets.dart';
import '../../utils/icon_map.dart';
import '../../utils/theme.dart';
import '../../widgets/widgets.dart';

class CompleteVisitScreen extends StatefulWidget {
  final String basePath;
  final String siteId;
  final String siteName;
  final String visitId;

  const CompleteVisitScreen({
    super.key,
    required this.basePath,
    required this.siteId,
    required this.siteName,
    required this.visitId,
  });

  @override
  State<CompleteVisitScreen> createState() => _CompleteVisitScreenState();
}

enum _ResponsiblePersonOption { signNow, emailLater, declined }

class _CompleteVisitScreenState extends State<CompleteVisitScreen> {
  final _visitService = InspectionVisitService.instance;
  final _complianceService = Bs5839ComplianceService.instance;

  final _responsiblePersonNameController = TextEditingController();

  late final SignatureController _engineerSignController;
  late final SignatureController _responsiblePersonSignController;

  bool _isLoading = true;
  bool _isSubmitting = false;

  InspectionVisit? _visit;
  InspectionDeclaration _calculatedDeclaration =
      InspectionDeclaration.notDeclared;
  String _declarationReason = '';
  List<Bs5839Variation> _activeVariations = [];
  _ResponsiblePersonOption _rpOption = _ResponsiblePersonOption.signNow;

  @override
  void initState() {
    super.initState();
    _engineerSignController = SignatureController(
      penStrokeWidth: 2,
      penColor: Colors.black,
    );
    _responsiblePersonSignController = SignatureController(
      penStrokeWidth: 2,
      penColor: Colors.black,
    );
    _loadData();
  }

  @override
  void dispose() {
    _responsiblePersonNameController.dispose();
    _engineerSignController.dispose();
    _responsiblePersonSignController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      _visit = await _visitService.getVisit(
          widget.basePath, widget.siteId, widget.visitId);

      _calculatedDeclaration = await _complianceService.calculateDeclaration(
        basePath: widget.basePath,
        siteId: widget.siteId,
        visitId: widget.visitId,
      );

      _declarationReason = _buildDeclarationReason();

      final variations = await VariationService.instance
          .getVariationsStream(widget.basePath, widget.siteId)
          .first;
      _activeVariations = variations
          .where((v) => v.status == VariationStatus.active)
          .toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _buildDeclarationReason() {
    switch (_calculatedDeclaration) {
      case InspectionDeclaration.unsatisfactory:
        return 'Prohibited variations or critical failures exist.';
      case InspectionDeclaration.satisfactoryWithVariations:
        return 'Active permissible variations, incomplete MCP rotation, or checklist items pending.';
      case InspectionDeclaration.satisfactory:
        return 'All checks passed with no active variations.';
      case InspectionDeclaration.notDeclared:
        return 'Insufficient data to calculate declaration.';
    }
  }

  Future<void> _submit() async {
    if (_visit == null) return;

    setState(() => _isSubmitting = true);
    try {
      String? engineerSig;
      if (_engineerSignController.isNotEmpty) {
        final bytes = await _engineerSignController.toPngBytes();
        if (bytes != null) {
          engineerSig = base64Encode(bytes);
        }
      }

      String? rpSig;
      String? rpName;
      if (_rpOption == _ResponsiblePersonOption.signNow &&
          _responsiblePersonSignController.isNotEmpty) {
        final bytes = await _responsiblePersonSignController.toPngBytes();
        if (bytes != null) {
          rpSig = base64Encode(bytes);
        }
        rpName = _responsiblePersonNameController.text.trim().isNotEmpty
            ? _responsiblePersonNameController.text.trim()
            : null;
      } else if (_rpOption == _ResponsiblePersonOption.declined) {
        rpName = 'Declined to sign';
      } else if (_rpOption == _ResponsiblePersonOption.emailLater) {
        rpName = 'Pending email signature';
      }

      final nextServiceWindow =
          _complianceService.calculateNextServiceWindow(DateTime.now());

      await _visitService.completeVisit(
        basePath: widget.basePath,
        siteId: widget.siteId,
        visitId: widget.visitId,
        declaration: _calculatedDeclaration,
        declarationNotes: _declarationReason,
        engineerSignatureBase64: engineerSig,
        responsiblePersonSignatureBase64: rpSig,
        responsiblePersonSignedName: rpName,
        nextServiceDueDate: nextServiceWindow.end,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Visit completed successfully')),
        );
        Navigator.of(context)
          ..pop()
          ..pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error completing visit: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Complete Visit')),
      body: _isLoading
          ? const Center(child: AdaptiveLoadingIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppTheme.screenPadding),
              children: [
                _buildDeclarationCard(isDark),
                const SizedBox(height: AppTheme.sectionGap),
                if (_activeVariations.isNotEmpty) ...[
                  _buildVariationsSection(isDark),
                  const SizedBox(height: AppTheme.sectionGap),
                ],
                _buildVisitSummary(isDark),
                const SizedBox(height: AppTheme.sectionGap),
                _buildEngineerSignature(isDark),
                const SizedBox(height: AppTheme.sectionGap),
                _buildResponsiblePersonSignature(isDark),
                const SizedBox(height: 32),
                AnimatedSaveButton(
                  onPressed: _submit,
                  enabled: !_isSubmitting,
                  label: 'Complete & Generate Report',
                  backgroundColor: AppTheme.primaryBlue,
                ),
                const SizedBox(height: 16),
              ],
            ),
    );
  }

  Widget _buildDeclarationCard(bool isDark) {
    final color = _declarationColor(_calculatedDeclaration);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text('Calculated Declaration',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey)),
          const SizedBox(height: 8),
          Text(
            _calculatedDeclaration.displayLabel,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _declarationReason,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildVariationsSection(bool isDark) {
    final prohibited =
        _activeVariations.where((v) => v.isProhibited).length;
    final permissible = _activeVariations.length - prohibited;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Active Variations',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (prohibited > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.shade900.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(AppIcons.danger,
                    size: 16, color: Colors.red.shade400),
                const SizedBox(width: 8),
                Text(
                  '$prohibited prohibited',
                  style: TextStyle(
                      color: Colors.red.shade400,
                      fontWeight: FontWeight.w500,
                      fontSize: 13),
                ),
              ],
            ),
          ),
        if (permissible > 0)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(AppIcons.warning,
                    size: 16, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  '$permissible permissible',
                  style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                      fontSize: 13),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildVisitSummary(bool isDark) {
    if (_visit == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Visit Summary',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _summaryRow('Type', _visit!.visitType.displayLabel),
        _summaryRow('Started',
            DateFormat('dd MMM yyyy HH:mm').format(_visit!.visitDate)),
        _summaryRow('Assets Tested', '${_visit!.serviceRecordIds.length}'),
        _summaryRow('MCPs Tested', '${_visit!.mcpIdsTestedThisVisit.length}'),
        _summaryRow(
            'Battery Tests', '${_visit!.batteryTestReadings.length}'),
        _summaryRow(
            'Logbook', _visit!.logbookReviewed ? 'Reviewed' : 'Not reviewed'),
        _summaryRow('Zone Plan',
            _visit!.zonePlanVerified ? 'Verified' : 'Not verified'),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey)),
          ),
          Expanded(
            flex: 3,
            child: Text(value, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildEngineerSignature(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Engineer Signature',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        _buildSignaturePad(_engineerSignController, isDark),
      ],
    );
  }

  Widget _buildResponsiblePersonSignature(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Responsible Person',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Sign Now'),
              selected: _rpOption == _ResponsiblePersonOption.signNow,
              onSelected: (v) {
                if (v) {
                  setState(
                      () => _rpOption = _ResponsiblePersonOption.signNow);
                }
              },
            ),
            ChoiceChip(
              label: const Text('Email Later'),
              selected: _rpOption == _ResponsiblePersonOption.emailLater,
              onSelected: (v) {
                if (v) {
                  setState(
                      () => _rpOption = _ResponsiblePersonOption.emailLater);
                }
              },
            ),
            ChoiceChip(
              label: const Text('Declined'),
              selected: _rpOption == _ResponsiblePersonOption.declined,
              onSelected: (v) {
                if (v) {
                  setState(
                      () => _rpOption = _ResponsiblePersonOption.declined);
                }
              },
            ),
          ],
        ),
        if (_rpOption == _ResponsiblePersonOption.signNow) ...[
          const SizedBox(height: 12),
          CustomTextField(
            controller: _responsiblePersonNameController,
            label: 'Printed Name',
          ),
          const SizedBox(height: 12),
          _buildSignaturePad(_responsiblePersonSignController, isDark),
        ],
        if (_rpOption == _ResponsiblePersonOption.emailLater) ...[
          const SizedBox(height: 12),
          Text(
            'A signature request will be sent after report generation.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey),
          ),
        ],
        if (_rpOption == _ResponsiblePersonOption.declined) ...[
          const SizedBox(height: 12),
          Text(
            'The report will note that the responsible person declined to sign.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.orange),
          ),
        ],
      ],
    );
  }

  Widget _buildSignaturePad(SignatureController controller, bool isDark) {
    return Column(
      children: [
        Container(
          height: 150,
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white24 : Colors.grey.shade300,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Signature(
              controller: controller,
              backgroundColor: isDark
                  ? Colors.grey.shade900
                  : Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => controller.clear(),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Clear'),
          ),
        ),
      ],
    );
  }

  Color _declarationColor(InspectionDeclaration declaration) {
    switch (declaration) {
      case InspectionDeclaration.satisfactory:
        return Colors.green;
      case InspectionDeclaration.satisfactoryWithVariations:
        return Colors.orange;
      case InspectionDeclaration.unsatisfactory:
        return Colors.red;
      case InspectionDeclaration.notDeclared:
        return Colors.grey;
    }
  }
}
