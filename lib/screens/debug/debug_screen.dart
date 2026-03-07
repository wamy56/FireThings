import 'package:flutter/material.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../../utils/adaptive_widgets.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/database_helper.dart';
import '../../utils/icon_map.dart';
import '../../widgets/widgets.dart';
import 'pdf_calibration_screen.dart';
import 'minor_works_calibration_screen.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  final _authService = AuthService();
  final _dbHelper = DatabaseHelper.instance;

  int _jobsheetsCount = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final count = await _dbHelper.getJobsheetsCount();
    setState(() => _jobsheetsCount = count);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdaptiveNavigationBar(title: 'Debug Tools'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Database Stats',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text('Total Jobsheets: $_jobsheetsCount'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          CustomButton(
            text: 'Create 5 Test Jobsheets',
            icon: AppIcons.add,
            onPressed: _createTestData,
            isLoading: _isLoading,
            isFullWidth: true,
          ),
          const SizedBox(height: 12),

          CustomButton(
            text: 'Create Complete Job (signatures)',
            icon: AppIcons.tickCircle,
            onPressed: _createCompleteJobsheet,
            isLoading: _isLoading,
            isFullWidth: true,
            backgroundColor: Colors.green,
          ),
          const SizedBox(height: 12),

          CustomOutlinedButton(
            text: 'Delete All Jobsheets',
            icon: AppIcons.trash,
            onPressed: _deleteAllData,
            isFullWidth: true,
            borderColor: Colors.red,
            foregroundColor: Colors.red,
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          const Text(
            'PDF Tools',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          CustomButton(
            text: 'PDF Calibration Tool',
            icon: AppIcons.slider,
            onPressed: () {
              Navigator.push(
                context,
                adaptivePageRoute(
                  builder: (context) => const PdfCalibrationScreen(),
                ),
              );
            },
            isFullWidth: true,
            backgroundColor: Colors.purple,
          ),
          const SizedBox(height: 12),
          CustomButton(
            text: 'Minor Works Calibration Tool',
            icon: AppIcons.slider,
            onPressed: () {
              Navigator.push(
                context,
                adaptivePageRoute(
                  builder: (context) => const MinorWorksCalibrationScreen(),
                ),
              );
            },
            isFullWidth: true,
            backgroundColor: Colors.orange,
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          const Text(
            'Invoice Tools',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          CustomButton(
            text: 'Create Test Sent Invoice',
            icon: AppIcons.receipt,
            onPressed: _createTestSentInvoice,
            isLoading: _isLoading,
            isFullWidth: true,
            backgroundColor: Colors.teal,
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          const Text(
            'Crashlytics',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          CustomButton(
            text: 'Test Crash',
            icon: AppIcons.warning,
            onPressed: () => FirebaseCrashlytics.instance.crash(),
            isFullWidth: true,
            backgroundColor: Colors.red,
          ),
        ],
      ),
    );
  }

  Future<void> _createTestData() async {
    setState(() => _isLoading = true);

    try {
      final user = _authService.currentUser!;

      for (int i = 1; i <= 5; i++) {
        await _dbHelper.insertJobsheet(
          Jobsheet(
            id: const Uuid().v4(),
            engineerId: user.uid,
            engineerName: user.displayName ?? user.email!,
            date: DateTime.now().subtract(Duration(days: i)),
            customerName: 'Test Customer $i',
            siteAddress: '$i Test Street, London, SW1A ${i}AA',
            jobNumber: 'JOB-TEST-${DateTime.now().millisecondsSinceEpoch}-$i',
            systemCategory: 'L${(i % 3) + 1}',
            templateType: i % 2 == 0
                ? 'Battery Replacement'
                : 'Detector Replacement',
            formData: {
              'test_field_1': 'Test value $i',
              'test_field_2': i.toString(),
            },
            notes: 'Test jobsheet $i - created for testing',
            defects: [],
            createdAt: DateTime.now(),
          ),
        );
      }

      await _loadStats();

      if (!mounted) return;
      context.showSuccessToast('5 test jobsheets created!');
    } catch (e) {
      if (!mounted) return;
      context.showErrorToast('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createCompleteJobsheet() async {
    setState(() => _isLoading = true);

    try {
      final user = _authService.currentUser!;

      // Create a jobsheet with dummy signatures
      final dummySignature =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

      await _dbHelper.insertJobsheet(
        Jobsheet(
          id: const Uuid().v4(),
          engineerId: user.uid,
          engineerName: user.displayName ?? user.email!,
          date: DateTime.now(),
          customerName: 'Complete Test Customer',
          siteAddress: '456 Complete Street, London, EC1A 1BB',
          jobNumber: 'JOB-COMPLETE-${DateTime.now().millisecondsSinceEpoch}',
          systemCategory: 'L2',
          templateType: 'Battery Replacement',
          formData: {
            'panel_make': 'Honeywell XLS',
            'battery_type': '12V 17Ah',
            'voltage_after': '13.8',
            'load_test': true,
          },
          notes: 'Complete test jobsheet with signatures',
          defects: [],
          engineerSignature: dummySignature,
          customerSignature: dummySignature,
          customerSignatureName: 'Test Customer',
          createdAt: DateTime.now(),
        ),
      );

      await _loadStats();

      if (!mounted) return;
      context.showSuccessToast('Complete jobsheet created!');
    } catch (e) {
      if (!mounted) return;
      context.showErrorToast('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createTestSentInvoice() async {
    setState(() => _isLoading = true);

    try {
      final user = _authService.currentUser!;
      final now = DateTime.now();

      await _dbHelper.insertInvoice(
        Invoice(
          id: const Uuid().v4(),
          invoiceNumber: 'INV-TEST-${now.millisecondsSinceEpoch}',
          engineerId: user.uid,
          engineerName: user.displayName ?? user.email!,
          customerName: 'Test Customer Ltd',
          customerAddress: '123 Test Street, London, SW1A 1AA',
          date: now,
          dueDate: now.add(const Duration(days: 30)),
          items: [
            InvoiceItem(
              description: 'Fire alarm service call',
              quantity: 1,
              unitPrice: 150.00,
            ),
            InvoiceItem(
              description: 'Replacement smoke detector',
              quantity: 2,
              unitPrice: 45.00,
            ),
          ],
          notes: 'Test invoice created from debug screen',
          status: InvoiceStatus.sent,
          createdAt: now,
        ),
      );

      if (!mounted) return;
      context.showSuccessToast('Test sent invoice created!');
    } catch (e) {
      if (!mounted) return;
      context.showErrorToast('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAllData() async {
    final confirm = await showAdaptiveAlertDialog<bool>(
      context: context,
      title: 'Delete All Data',
      message: 'Are you sure you want to delete ALL jobsheets? This cannot be undone.',
      confirmLabel: 'Delete All',
      cancelLabel: 'Cancel',
      isDestructive: true,
    );

    if (confirm == true) {
      await _dbHelper.deleteAllJobsheets();
      await _loadStats();

      if (!mounted) return;
      context.showWarningToast('All data deleted');
    }
  }
}
