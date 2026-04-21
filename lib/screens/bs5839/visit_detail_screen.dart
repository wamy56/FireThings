import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/inspection_visit.dart';
import '../../services/inspection_visit_service.dart';
import '../../utils/adaptive_widgets.dart';
import '../../utils/icon_map.dart';
import '../../utils/theme.dart';
import 'inspection_visit_dashboard_screen.dart';

class VisitDetailScreen extends StatelessWidget {
  final String basePath;
  final String siteId;
  final String siteName;
  final String visitId;

  const VisitDetailScreen({
    super.key,
    required this.basePath,
    required this.siteId,
    required this.siteName,
    required this.visitId,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Visit Detail')),
      body: StreamBuilder<InspectionVisit?>(
        stream: InspectionVisitService.instance
            .getVisitStream(basePath, siteId, visitId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: AdaptiveLoadingIndicator());
          }

          final visit = snapshot.data;
          if (visit == null) {
            return const Center(child: Text('Visit not found'));
          }

          if (visit.completedAt == null) {
            return _buildInProgressView(context, visit, isDark);
          }

          return _buildCompletedView(context, visit, isDark);
        },
      ),
    );
  }

  Widget _buildInProgressView(
      BuildContext context, InspectionVisit visit, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(AppIcons.clipboardTick, size: 48, color: Colors.blue),
          const SizedBox(height: 16),
          const Text('Visit In Progress',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => InspectionVisitDashboardScreen(
                    basePath: basePath,
                    siteId: siteId,
                    siteName: siteName,
                    visitId: visitId,
                  ),
                ),
              );
            },
            child: const Text('Continue Visit'),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedView(
      BuildContext context, InspectionVisit visit, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      children: [
        _buildDeclarationHeader(context, visit, isDark),
        const SizedBox(height: AppTheme.sectionGap),
        _buildSection(context, 'Visit Information', [
          _row(context, 'Type', visit.visitType.displayLabel),
          _row(context, 'Date',
              DateFormat('dd MMM yyyy').format(visit.visitDate)),
          _row(context, 'Completed',
              DateFormat('dd MMM yyyy HH:mm').format(visit.completedAt!)),
          _row(context, 'Engineer', visit.engineerName),
        ]),
        const SizedBox(height: 20),
        _buildSection(context, 'Test Summary', [
          _row(context, 'Assets Tested',
              '${visit.serviceRecordIds.length}'),
          _row(context, 'MCPs Tested',
              '${visit.mcpIdsTestedThisVisit.length}'),
          _row(context, 'Battery Load Tests',
              '${visit.batteryTestReadings.length}'),
          _row(context, 'All Detectors Tested',
              visit.allDetectorsTestedThisVisit ? 'Yes' : 'No'),
        ]),
        const SizedBox(height: 20),
        _buildSection(context, 'Compliance Checks', [
          _row(context, 'Logbook Reviewed',
              visit.logbookReviewed ? 'Yes' : 'No'),
          _row(context, 'Zone Plan Verified',
              visit.zonePlanVerified ? 'Yes' : 'No'),
          _row(context, 'Cause & Effect',
              visit.causeAndEffectMatrixProvided ? 'Provided' : 'N/A'),
          _row(context, 'Cyber Security',
              visit.cyberSecurityChecksCompleted ? 'Completed' : 'N/A'),
          _row(context, 'ARC Signalling',
              visit.arcSignallingTested ? 'Tested' : 'N/A'),
          if (visit.arcTransmissionTimeMeasuredSeconds != null)
            _row(context, 'ARC Time',
                '${visit.arcTransmissionTimeMeasuredSeconds}s'),
          _row(context, 'Earth Fault Test',
              visit.earthFaultTestPassed ? 'Passed' : 'Not tested'),
          if (visit.earthFaultReadingKOhms != null)
            _row(context, 'Earth Fault Reading',
                '${visit.earthFaultReadingKOhms} kΩ'),
        ]),
        if (visit.engineerSignatureBase64 != null) ...[
          const SizedBox(height: 20),
          _buildSignatureSection(
              context, 'Engineer Signature', visit.engineerSignatureBase64!, isDark),
        ],
        if (visit.responsiblePersonSignatureBase64 != null) ...[
          const SizedBox(height: 20),
          _buildSignatureSection(context, 'Responsible Person',
              visit.responsiblePersonSignatureBase64!, isDark,
              name: visit.responsiblePersonSignedName),
        ],
        if (visit.nextServiceDueDate != null) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(AppIcons.calendar,
                    size: 18, color: AppTheme.primaryBlue),
                const SizedBox(width: 10),
                Text(
                  'Next service due by ${DateFormat('dd MMM yyyy').format(visit.nextServiceDueDate!)}',
                  style: TextStyle(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDeclarationHeader(
      BuildContext context, InspectionVisit visit, bool isDark) {
    final color = _declarationColor(visit.declaration);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            visit.declaration.displayLabel,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          if (visit.declarationNotes != null &&
              visit.declarationNotes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              visit.declarationNotes!,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection(
      BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value) {
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

  Widget _buildSignatureSection(
    BuildContext context,
    String title,
    String base64Sig,
    bool isDark, {
    String? name,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        if (name != null) ...[
          const SizedBox(height: 4),
          Text(name,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey)),
        ],
        const SizedBox(height: 8),
        Container(
          height: 100,
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white24 : Colors.grey.shade300,
            ),
          ),
          child: Image.memory(
            base64Decode(base64Sig),
            fit: BoxFit.contain,
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
