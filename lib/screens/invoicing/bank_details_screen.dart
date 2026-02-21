import 'package:flutter/material.dart';
import '../../services/payment_settings_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../widgets/premium_toast.dart';
import '../../widgets/animated_save_button.dart';
import '../../widgets/adaptive_app_bar.dart';
import '../../utils/adaptive_widgets.dart';

class BankDetailsScreen extends StatefulWidget {
  const BankDetailsScreen({super.key});

  @override
  State<BankDetailsScreen> createState() => _BankDetailsScreenState();
}

class _BankDetailsScreenState extends State<BankDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bankNameController = TextEditingController();
  final _accountNameController = TextEditingController();
  final _sortCodeController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _paymentTermsController = TextEditingController();

  bool _isLoading = true;


  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _accountNameController.dispose();
    _sortCodeController.dispose();
    _accountNumberController.dispose();
    _paymentTermsController.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    final details = await PaymentSettingsService.getPaymentDetails();
    setState(() {
      _bankNameController.text = details.bankName;
      _accountNameController.text = details.accountName;
      _sortCodeController.text = details.sortCode;
      _accountNumberController.text = details.accountNumber;
      _paymentTermsController.text = details.paymentTerms;
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await PaymentSettingsService.savePaymentDetails(
        PaymentDetails(
          bankName: _bankNameController.text.trim(),
          accountName: _accountNameController.text.trim(),
          sortCode: _sortCodeController.text.trim(),
          accountNumber: _accountNumberController.text.trim(),
          paymentTerms: _paymentTermsController.text.trim(),
        ),
      );

      if (mounted) {
        context.showSuccessToast('Bank details saved');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        context.showErrorToast('Error saving: $e');
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AdaptiveNavigationBar(
        title: 'Bank Details',
      ),
      body: _isLoading
          ? const Center(child: AdaptiveLoadingIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.screenPadding),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: (isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            AppIcons.infoCircle,
                            color: isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'These details will appear on your invoices for customer payments.',
                              style: TextStyle(
                                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _bankNameController,
                      decoration: const InputDecoration(
                        labelText: 'Bank Name',
                        prefixIcon: Icon(AppIcons.bank),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _accountNameController,
                      decoration: const InputDecoration(
                        labelText: 'Account Name',
                        prefixIcon: Icon(AppIcons.user),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _sortCodeController,
                      decoration: const InputDecoration(
                        labelText: 'Sort Code',
                        hintText: 'XX-XX-XX',
                        prefixIcon: Icon(AppIcons.tag),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _accountNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Account Number',
                        prefixIcon: Icon(AppIcons.tag),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _paymentTermsController,
                      decoration: const InputDecoration(
                        labelText: 'Payment Terms',
                        prefixIcon: Icon(AppIcons.clock),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 32),
                    AnimatedSaveButton(
                      label: 'Save Details',
                      onPressed: _save,
                      width: double.infinity,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
