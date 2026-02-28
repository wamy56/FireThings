import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../utils/icon_map.dart';
import '../../utils/theme.dart';
import '../../services/database_helper.dart';
import '../../services/invoice_pdf_service.dart';
import '../../services/email_service.dart';
import '../../services/auth_service.dart';
import '../../services/payment_settings_service.dart';
import '../../widgets/animated_save_button.dart';
import '../../widgets/premium_toast.dart';
import '../../widgets/adaptive_app_bar.dart';
import '../../widgets/premium_dialog.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/keyboard_dismiss_wrapper.dart';
import '../common/pdf_preview_screen.dart';

class InvoiceScreen extends StatefulWidget {
  final Invoice? existingInvoice;

  const InvoiceScreen({super.key, this.existingInvoice});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dbHelper = DatabaseHelper.instance;
  final _authService = AuthService();

  // Form controllers
  final _engineerNameController = TextEditingController();
  final _invoiceNumberController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _customerAddressController = TextEditingController();
  final _customerEmailController = TextEditingController();
  final _notesController = TextEditingController();

  // Invoice data
  DateTime _invoiceDate = DateTime.now();
  DateTime _dueDate = DateTime.now();
  List<InvoiceItem> _items = [];
  final List<_ItemControllers> _itemControllers = [];
  bool _includeVat = false;
  bool _isLoading = false;
  bool _isSaved = false;
  InvoiceStatus _status = InvoiceStatus.draft;
  String? _invoiceId;
  PaymentDetails _paymentDetails = PaymentDetails(
    bankName: '',
    accountName: '',
    sortCode: '',
    accountNumber: '',
    paymentTerms: 'Payment is due within 30 days of the invoice date.',
  );
  List<SavedCustomer> _savedCustomers = [];

  @override
  void initState() {
    super.initState();
    _itemControllers.add(_ItemControllers());
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    try {
      // Load payment details
      final details = await PaymentSettingsService.getPaymentDetails();

      // Load saved customers
      final user = _authService.currentUser;
      List<SavedCustomer> customers = [];
      if (user != null) {
        customers = await _dbHelper.getSavedCustomersByEngineerId(user.uid);
      }

      // Load saved engineer name or use user's display name
      String engineerName =
          await PaymentSettingsService.getEngineerName() ?? '';
      if (engineerName.isEmpty) {
        engineerName = user?.displayName ?? user?.email?.split('@')[0] ?? '';
      }

      if (widget.existingInvoice != null) {
        _loadExistingInvoice();
      } else {
        // Load last invoice number or generate new one
        String? lastNumber =
            await PaymentSettingsService.getLastInvoiceNumber();
        if (lastNumber != null) {
          _invoiceNumberController.text =
              PaymentSettingsService.incrementInvoiceNumber(lastNumber);
        } else {
          final newNumber = await _dbHelper.getNextInvoiceNumber();
          _invoiceNumberController.text = newNumber;
        }
      }

      setState(() {
        _paymentDetails = details;
        _savedCustomers = customers;
        if (_engineerNameController.text.isEmpty) {
          _engineerNameController.text = engineerName;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading initial data: $e');
    }
  }

  void _loadExistingInvoice() {
    final invoice = widget.existingInvoice!;
    _invoiceId = invoice.id;
    _invoiceNumberController.text = invoice.invoiceNumber;
    _engineerNameController.text = invoice.engineerName;
    _customerNameController.text = invoice.customerName;
    _customerAddressController.text = invoice.customerAddress;
    _invoiceDate = invoice.date;
    _dueDate = invoice.dueDate;
    _items = List.from(invoice.items);
    _includeVat = invoice.includeVat;
    _notesController.text = invoice.notes ?? '';
    _isSaved = true;
    _status = invoice.status;

    // Populate item controllers from existing items
    _itemControllers.clear();
    for (final item in _items) {
      final controllers = _ItemControllers();
      controllers.description.text = item.description;
      controllers.quantity.text = item.quantity.toString();
      controllers.unitPrice.text = item.unitPrice.toStringAsFixed(2);
      _itemControllers.add(controllers);
    }
    // Add one empty row at the end
    _itemControllers.add(_ItemControllers());
  }

  void _updateDueDate(DateTime newInvoiceDate) {
    setState(() {
      _invoiceDate = newInvoiceDate;
      _dueDate = newInvoiceDate;
    });
  }

  @override
  void dispose() {
    _engineerNameController.dispose();
    _invoiceNumberController.dispose();
    _customerNameController.dispose();
    _customerAddressController.dispose();
    _notesController.dispose();
    _customerEmailController.dispose();
    for (final c in _itemControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdaptiveNavigationBar(
        title: widget.existingInvoice != null
            ? 'Edit Invoice'
            : 'Create Invoice',
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: AnimatedSaveButton(
              outlined: true,
              label: 'Save Draft',
              onPressed: _doSaveInvoice,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: AdaptiveLoadingIndicator())
          : KeyboardDismissWrapper(
              child: Form(
                key: _formKey,
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (widget.existingInvoice?.status ==
                        InvoiceStatus.sent) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _markAsPaid,
                          icon: Icon(AppIcons.tickCircle),
                          label: const Text('Mark as Paid'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildInvoiceHeader(),
                    const SizedBox(height: 20),
                    _buildCustomerSection(),
                    const SizedBox(height: 20),
                    _buildItemsSection(),
                    const SizedBox(height: 20),
                    _buildVatSection(),
                    const SizedBox(height: 12),
                    _buildTotalsSection(),
                    const SizedBox(height: 20),
                    _buildNotesSection(),
                    const SizedBox(height: 24),
                    _buildActionButtons(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInvoiceHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(AppIcons.receipt, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Invoice Details',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Engineer name - editable
            TextFormField(
              controller: _engineerNameController,
              decoration: InputDecoration(
                labelText: 'From (Your Name)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(AppIcons.user),
              ),
              textInputAction: TextInputAction.done,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDateField(
                    'Invoice Date',
                    _invoiceDate,
                    _updateDueDate,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDateField(
                    'Due Date',
                    _dueDate,
                    (date) => setState(() => _dueDate = date),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _invoiceNumberController,
              decoration: InputDecoration(
                labelText: 'Invoice Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(AppIcons.tag),
              ),
              textInputAction: TextInputAction.done,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Required';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField(
    String label,
    DateTime date,
    Function(DateTime) onChanged,
  ) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppTheme.darkTextSecondary : Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final picked = await showAdaptiveDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (picked != null) {
              onChanged(picked);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark ? AppTheme.darkDivider : Colors.grey[300]!,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(dateFormat.format(date)),
                Icon(
                  AppIcons.calendar,
                  size: 18,
                  color: isDark ? AppTheme.darkTextSecondary : Colors.grey[600],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(AppIcons.user, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Customer Details',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (_savedCustomers.isNotEmpty)
                  TextButton.icon(
                    onPressed: _showSelectCustomerDialog,
                    icon: Icon(AppIcons.people, size: 18),
                    label: const Text('Select'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _customerNameController,
              decoration: InputDecoration(
                labelText: 'Customer Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(AppIcons.building),
              ),
              textInputAction: TextInputAction.done,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter customer name';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _customerEmailController,
              decoration: InputDecoration(
                labelText: 'Customer Email (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(AppIcons.sms),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _customerAddressController,
              decoration: InputDecoration(
                labelText: 'Customer Address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(AppIcons.location),
              ),
              maxLines: 2,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter customer address';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            if (_customerNameController.text.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _saveCurrentCustomer,
                  icon: Icon(AppIcons.save, size: 18),
                  label: const Text('Save Customer'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showSelectCustomerDialog() {
    showPremiumDialog(
      context: context,
      child: Builder(
        builder: (context) => AlertDialog(
          title: const Text('Select Customer'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _savedCustomers.length,
              itemBuilder: (context, index) {
                final customer = _savedCustomers[index];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(customer.customerName[0].toUpperCase()),
                  ),
                  title: Text(customer.customerName),
                  subtitle: Text(
                    customer.customerAddress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    setState(() {
                      _customerNameController.text = customer.customerName;
                      _customerAddressController.text =
                          customer.customerAddress;
                      _customerEmailController.text = customer.email ?? '';
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveCurrentCustomer() async {
    if (_customerNameController.text.isEmpty ||
        _customerAddressController.text.isEmpty) {
      context.showWarningToast('Please enter customer name and address first');
      return;
    }

    final user = _authService.currentUser;
    if (user == null) return;

    // Check if customer already exists
    final existing = _savedCustomers.where(
      (c) =>
          c.customerName.toLowerCase() ==
          _customerNameController.text.toLowerCase(),
    );

    if (existing.isNotEmpty) {
      context.showWarningToast('Customer already saved');
      return;
    }

    try {
      final customer = SavedCustomer(
        id: const Uuid().v4(),
        engineerId: user.uid,
        customerName: _customerNameController.text,
        customerAddress: _customerAddressController.text,
        email: _customerEmailController.text.isNotEmpty
            ? _customerEmailController.text
            : null,
        createdAt: DateTime.now(),
      );

      await _dbHelper.insertSavedCustomer(customer);

      setState(() {
        _savedCustomers.add(customer);
      });

      if (mounted) {
        context.showSuccessToast('Customer saved');
      }
    } catch (e) {
      if (mounted) {
        context.showErrorToast('Error saving customer: $e');
      }
    }
  }

  void _addItemRow() {
    setState(() {
      _itemControllers.add(_ItemControllers());
    });
  }

  void _removeItemRow(int index) {
    if (_itemControllers.length <= 1) return;
    setState(() {
      _itemControllers[index].dispose();
      _itemControllers.removeAt(index);
    });
  }

  Widget _buildItemRow(int index) {
    final controllers = _itemControllers[index];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceElevated : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppTheme.darkDivider : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Item ${index + 1}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: controllers.description,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Enter item description...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(AppIcons.close, size: 20, color: Colors.red),
                onPressed: _itemControllers.length > 1
                    ? () => _removeItemRow(index)
                    : null,
                tooltip: 'Remove',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 100,
                child: TextFormField(
                  controller: controllers.quantity,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  textAlign: TextAlign.center,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 120,
                child: TextFormField(
                  controller: controllers.unitPrice,
                  decoration: const InputDecoration(
                    labelText: 'Unit Price',
                    border: OutlineInputBorder(),
                    prefixText: '\u00A3',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Builder(
                  builder: (_) {
                    final qty =
                        int.tryParse(controllers.quantity.text.trim()) ?? 0;
                    final price =
                        double.tryParse(controllers.unitPrice.text.trim()) ??
                        0.0;
                    final lineTotal = qty * price;
                    if (lineTotal <= 0) return const SizedBox.shrink();
                    final formatted = NumberFormat.currency(
                      symbol: '\u00A3',
                      decimalDigits: 2,
                    ).format(lineTotal);
                    return Text(
                      formatted,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                      textAlign: TextAlign.right,
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(AppIcons.clipboard, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Line Items',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (int i = 0; i < _itemControllers.length; i++) _buildItemRow(i),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _addItemRow,
                icon: Icon(AppIcons.add, size: 18),
                label: const Text('+ Add Another Item'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVatSection() {
    return Card(
      child: CheckboxListTile(
        title: const Text('Include VAT (20%)'),
        subtitle: const Text('Add 20% VAT to the invoice total'),
        value: _includeVat,
        onChanged: (value) {
          setState(() {
            _includeVat = value ?? false;
          });
        },
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  double _calculateSubtotalFromControllers() {
    double subtotal = 0.0;
    for (final controllers in _itemControllers) {
      final quantityText = controllers.quantity.text.trim();
      final unitPriceText = controllers.unitPrice.text.trim();
      final quantity = int.tryParse(quantityText) ?? 0;
      final unitPrice = double.tryParse(unitPriceText) ?? 0.0;
      subtotal += quantity * unitPrice;
    }
    return subtotal;
  }

  bool _hasValidItems() {
    for (final controllers in _itemControllers) {
      final description = controllers.description.text.trim();
      final unitPriceText = controllers.unitPrice.text.trim();
      final unitPrice = double.tryParse(unitPriceText) ?? 0.0;
      if (description.isNotEmpty && unitPrice > 0) {
        return true;
      }
    }
    return false;
  }

  bool _validateForAction() {
    if (!_formKey.currentState!.validate()) return false;
    if (!_hasValidItems()) {
      context.showWarningToast(
        'Please add at least one item with description and price',
      );
      return false;
    }
    return true;
  }

  Widget _buildTotalsSection() {
    final currencyFormat = NumberFormat.currency(
      symbol: '\u00A3',
      decimalDigits: 2,
    );
    final subtotal = _calculateSubtotalFromControllers();
    final tax = _includeVat ? subtotal * 0.20 : 0.0;
    final total = subtotal + tax;

    return Card(
      color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTotalRow('Subtotal', currencyFormat.format(subtotal)),
            if (_includeVat) ...[
              const SizedBox(height: 8),
              _buildTotalRow('VAT (20%)', currencyFormat.format(tax)),
            ],
            const Divider(height: 24),
            _buildTotalRow(
              'Total',
              currencyFormat.format(total),
              isBold: true,
              isLarge: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow(
    String label,
    String value, {
    bool isBold = false,
    bool isLarge = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isLarge ? 18 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isLarge ? 24 : 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: isBold ? Theme.of(context).primaryColor : null,
          ),
        ),
      ],
    );
  }

  Widget _buildNotesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(AppIcons.note, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Notes (Optional)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                hintText: 'Add any additional notes for this invoice...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _saveInvoice,
                icon: Icon(AppIcons.save),
                label: Text(_isSaved ? 'Update' : 'Save Draft'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _previewPDF,
                icon: Icon(AppIcons.document),
                label: const Text('Preview PDF'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _sendViaEmail,
            icon: Icon(AppIcons.sms),
            label: const Text('Send via Email'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _markAsPaid() async {
    await _dbHelper.updateInvoice(
      widget.existingInvoice!.copyWith(status: InvoiceStatus.paid),
    );
    if (mounted) {
      context.showSuccessToast('Invoice marked as paid');
      Navigator.pop(context);
    }
  }

  void _collectItemsFromControllers() {
    _items.clear();
    for (final controllers in _itemControllers) {
      final description = controllers.description.text.trim();
      final quantityText = controllers.quantity.text.trim();
      final unitPriceText = controllers.unitPrice.text.trim();

      // Skip empty rows
      if (description.isEmpty && unitPriceText.isEmpty) continue;

      final quantity = int.tryParse(quantityText) ?? 1;
      final unitPrice = double.tryParse(unitPriceText) ?? 0.0;

      if (description.isNotEmpty && unitPrice > 0) {
        _items.add(
          InvoiceItem(
            description: description,
            quantity: quantity,
            unitPrice: unitPrice,
          ),
        );
      }
    }
  }

  Invoice _buildInvoice() {
    _collectItemsFromControllers();
    final user = _authService.currentUser;
    return Invoice(
      id: _invoiceId ?? const Uuid().v4(),
      invoiceNumber: _invoiceNumberController.text,
      engineerId: user?.uid ?? '',
      engineerName: _engineerNameController.text,
      customerName: _customerNameController.text,
      customerAddress: _customerAddressController.text,
      date: _invoiceDate,
      dueDate: _dueDate,
      items: _items,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      includeVat: _includeVat,
      status: _status,
      createdAt: DateTime.now(),
    );
  }

  Future<void> _doSaveInvoice() async {
    final invoice = _buildInvoice();

    if (_isSaved) {
      await _dbHelper.updateInvoice(invoice);
    } else {
      await _dbHelper.insertInvoice(invoice);
      _invoiceId = invoice.id;
    }

    // Save the invoice number and engineer name for next time
    await PaymentSettingsService.saveLastInvoiceNumber(invoice.invoiceNumber);
    await PaymentSettingsService.saveEngineerName(invoice.engineerName);

    if (!mounted) return;
    setState(() => _isSaved = true);
    context.showSuccessToast('Invoice saved successfully');
  }

  Future<void> _saveInvoice() async {
    setState(() => _isLoading = true);
    try {
      await _doSaveInvoice();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _previewPDF() async {
    setState(() => _isLoading = true);

    try {
      final invoice = _buildInvoice();
      final pdfBytes = await InvoicePDFService.generateInvoicePDF(
        invoice,
        _paymentDetails,
      );

      setState(() => _isLoading = false);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfPreviewScreen(
              pdfBytes: pdfBytes,
              title: 'Invoice ${invoice.invoiceNumber}',
              fileName: 'Invoice_${invoice.invoiceNumber}.pdf',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        context.showErrorToast('Error generating PDF: $e');
      }
    }
  }

  void _sendViaEmail() {
    if (!_validateForAction()) return;

    final email = _customerEmailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      context.showErrorToast('Please enter a customer email address first');
      return;
    }

    _sendEmail(email);
  }

  Future<void> _sendEmail(String email) async {
    setState(() => _isLoading = true);

    try {
      final invoice = _buildInvoice();
      final pdfBytes = await InvoicePDFService.generateInvoicePDF(
        invoice,
        _paymentDetails,
      );

      await EmailService.sendInvoice(
        recipientEmail: email,
        invoiceNumber: invoice.invoiceNumber,
        customerName: invoice.customerName,
        pdfBytes: pdfBytes,
        senderName: invoice.engineerName,
      );

      // Save the invoice number and engineer name for next time
      await PaymentSettingsService.saveLastInvoiceNumber(invoice.invoiceNumber);
      await PaymentSettingsService.saveEngineerName(invoice.engineerName);

      // Update invoice status to sent
      if (!_isSaved) {
        await _dbHelper.insertInvoice(invoice);
        _invoiceId = invoice.id;
        _isSaved = true;
      }
      final updatedInvoice = invoice.copyWith(status: InvoiceStatus.sent);
      await _dbHelper.updateInvoice(updatedInvoice);
      setState(() => _status = InvoiceStatus.sent);

      setState(() => _isLoading = false);

      if (mounted) {
        context.showSuccessToast('Email app opened with invoice attached');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        context.showErrorToast('Error: $e');
      }
    }
  }
}

class _ItemControllers {
  final TextEditingController description;
  final TextEditingController quantity;
  final TextEditingController unitPrice;

  _ItemControllers()
    : description = TextEditingController(),
      quantity = TextEditingController(text: '1'),
      unitPrice = TextEditingController();

  void dispose() {
    description.dispose();
    quantity.dispose();
    unitPrice.dispose();
  }
}
