import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/inspection_visit.dart';
import '../../services/inspection_visit_service.dart';
import '../../utils/icon_map.dart';
import '../../utils/theme.dart';
import '../../widgets/widgets.dart';
import 'visit_detail_screen.dart';

class VisitHistoryScreen extends StatelessWidget {
  final String basePath;
  final String siteId;
  final String siteName;

  const VisitHistoryScreen({
    super.key,
    required this.basePath,
    required this.siteId,
    required this.siteName,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Visit History')),
      body: StreamBuilder<List<InspectionVisit>>(
        stream: InspectionVisitService.instance
            .getVisitsStream(basePath, siteId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final visits = snapshot.data ?? [];
          if (visits.isEmpty) {
            return const EmptyState(
              icon: AppIcons.clipboardTick,
              title: 'No Visits',
              message: 'No inspection visits have been recorded for this site.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: visits.length,
            itemBuilder: (context, index) =>
                _buildVisitCard(context, visits[index], isDark),
          );
        },
      ),
    );
  }

  Widget _buildVisitCard(
      BuildContext context, InspectionVisit visit, bool isDark) {
    final dateStr = DateFormat('dd MMM yyyy').format(visit.visitDate);
    final isComplete = visit.completedAt != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => VisitDetailScreen(
                basePath: basePath,
                siteId: siteId,
                siteName: siteName,
                visitId: visit.id,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      visit.visitType.displayLabel,
                      style: TextStyle(
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isComplete)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _declarationColor(visit.declaration)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        visit.declaration.displayLabel,
                        style: TextStyle(
                          color: _declarationColor(visit.declaration),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'In Progress',
                        style: TextStyle(
                          color: Colors.blue,
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
              Text(dateStr,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 15)),
              const SizedBox(height: 4),
              Text(
                'Engineer: ${visit.engineerName} · ${visit.serviceRecordIds.length} tests',
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
