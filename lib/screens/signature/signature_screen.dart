import 'package:flutter/material.dart';
import '../../utils/adaptive_widgets.dart';
import 'package:signature/signature.dart';
import 'dart:typed_data';
import 'dart:convert';
import '../../models/models.dart';
import '../../services/database_helper.dart';
import '../../utils/icon_map.dart';
import '../../widgets/widgets.dart';
import '../../services/analytics_service.dart';
import '../history/job_detail_screen.dart';

class SignatureScreen extends StatefulWidget {
  final Jobsheet jobsheet;

  const SignatureScreen({super.key, required this.jobsheet});

  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen> {
  final _dbHelper = DatabaseHelper.instance;
  final _customerNameController = TextEditingController();

  late final SignatureController _engineerSignController;
  late final SignatureController _customerSignController;

  String? _engineerSignature;
  String? _customerSignature;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _engineerSignController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );

    _customerSignController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
  }

  @override
  void dispose() {
    _engineerSignController.dispose();
    _customerSignController.dispose();
    _customerNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdaptiveNavigationBar(title: 'Signatures'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Engineer Signature Section
            Text(
              'Engineer Signature',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: Signature(
                controller: _engineerSignController,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _engineerSignController.clear(),
                  icon: Icon(AppIcons.close),
                  label: const Text('Clear'),
                ),
                const Spacer(),
                if (_engineerSignature != null)
                  Icon(AppIcons.tickCircle, color: Colors.green),
              ],
            ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 32),

            // Customer Signature Section
            Text(
              'Customer Signature',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _customerNameController,
              label: 'Customer Name (Printed) *',
              hint: 'Enter customer name',
              prefixIcon: Icon(AppIcons.user),
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: Signature(
                controller: _customerSignController,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _customerSignController.clear(),
                  icon: Icon(AppIcons.close),
                  label: const Text('Clear'),
                ),
                const Spacer(),
                if (_customerSignature != null)
                  Icon(AppIcons.tickCircle, color: Colors.green),
              ],
            ),

            const SizedBox(height: 32),

            // Complete Button
            CustomButton(
              text: 'Complete Jobsheet',
              icon: AppIcons.tickCircle,
              onPressed: _completeJobsheet,
              isLoading: _isLoading,
              isFullWidth: true,
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _completeJobsheet() async {
    // Validate customer name
    if (_customerNameController.text.trim().isEmpty) {
      showValidationBanner(context: context, message: 'Please enter customer name');
      return;
    }

    // Validate signatures
    if (_engineerSignController.isEmpty) {
      showValidationBanner(context: context, message: 'Please provide engineer signature');
      return;
    }

    if (_customerSignController.isEmpty) {
      showValidationBanner(context: context, message: 'Please provide customer signature');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Convert signatures to PNG bytes
      final Uint8List? engineerBytes = await _engineerSignController
          .toPngBytes();
      final Uint8List? customerBytes = await _customerSignController
          .toPngBytes();

      if (engineerBytes == null || customerBytes == null) {
        throw Exception('Failed to capture signatures');
      }

      // Convert to base64
      final engineerBase64 = base64Encode(engineerBytes);
      final customerBase64 = base64Encode(customerBytes);

      // Update jobsheet with signatures and set status to completed
      final updatedJobsheet = widget.jobsheet.copyWith(
        engineerSignature: engineerBase64,
        customerSignature: customerBase64,
        customerSignatureName: _customerNameController.text.trim(),
        status: JobsheetStatus.completed,
      );

      // Update in database
      await _dbHelper.updateJobsheet(updatedJobsheet);
      AnalyticsService.instance.logJobsheetCompleted();

      if (mounted) {
        // Navigate to job details screen for overview
        // Pop all screens back to first, then push job details
        Navigator.of(context).popUntil((route) => route.isFirst);
        Navigator.of(context).push(
          adaptivePageRoute(
            builder: (_) => JobDetailScreen(
              jobsheet: updatedJobsheet,
              showSuccessBanner: true,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        context.showErrorToast('Error completing jobsheet: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
