import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/cause_effect_test.dart';
import '../../services/cause_effect_service.dart';
import '../../utils/icon_map.dart';
import '../../utils/theme.dart';
import '../../widgets/widgets.dart';
import 'cause_effect_test_screen.dart';

class CauseEffectTestListScreen extends StatelessWidget {
  final String basePath;
  final String siteId;
  final String siteName;
  final String visitId;

  const CauseEffectTestListScreen({
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
      appBar: AppBar(title: const Text('Cause & Effect Tests')),
      body: StreamBuilder<List<CauseEffectTest>>(
        stream: CauseEffectService.instance
            .getTestsForVisitStream(basePath, siteId, visitId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final tests = snapshot.data ?? [];
          if (tests.isEmpty) {
            return const EmptyState(
              icon: AppIcons.flash,
              title: 'No Tests',
              message:
                  'No cause-and-effect tests have been run for this visit.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tests.length,
            itemBuilder: (context, index) =>
                _buildTestCard(context, tests[index], isDark),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _newTest(context),
        icon: const Icon(AppIcons.add),
        label: const Text('New Test'),
      ),
    );
  }

  Widget _buildTestCard(
      BuildContext context, CauseEffectTest test, bool isDark) {
    final dateStr = DateFormat('dd MMM yyyy HH:mm').format(test.testedAt);
    final passedCount =
        test.expectedEffects.where((e) => e.passed).length;
    final totalCount = test.expectedEffects.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    test.triggerAssetReference.isNotEmpty
                        ? test.triggerAssetReference
                        : test.triggerDescription,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: test.overallPassed
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    test.overallPassed ? 'Pass' : 'Fail',
                    style: TextStyle(
                      color: test.overallPassed ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$passedCount / $totalCount effects passed',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              '$dateStr · ${test.testedByEngineerName}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _newTest(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CauseEffectTestScreen(
          basePath: basePath,
          siteId: siteId,
          visitId: visitId,
        ),
      ),
    );
  }
}
