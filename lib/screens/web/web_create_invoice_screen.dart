import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../models/invoice.dart';
import '../../models/company_customer.dart';
import '../../services/firestore_sync_service.dart';
import '../../services/company_service.dart';
import '../../services/user_profile_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/premium_toast.dart';

class WebCreateInvoiceScreen extends StatefulWidget {
  final Invoice? editInvoice;

  const WebCreateInvoiceScreen({super.key, this.editInvoice});

  @override
  State<WebCreateInvoiceScreen> createState() => _WebCreateInvoiceScreenState();
}

class _WebCreateInvoiceScreenState extends State<WebCreateInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isEdit = false;

  // Customer
  final _customerNameController = TextEditingController();
  final _customerAddressController = TextEditingController();
  final _customerEmailController = TextEditingController();

  // Invoice details
  String _invoiceNumber = '';
  DateTime _date = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  bool _includeVat = false;
  bool _useCompanyBranding = false;

  // Items
  final List<_LineItem> _items = [_LineItem()];

  // Notes
  final _notesController = TextEditingController();

  // Autocomplete
  List<CompanyCustomer> _companyCustomers = [];
  StreamSubscription? _customersSubscription;

  @override
  void initState() {
    super.initState();
    _loadSharedData();
    if (widget.editInvoice != null) {
      _isEdit = widget.editInvoice!.id.isNotEmpty;
      _populateFromInvoice(widget.editInvoice!);
    } else {
      _generateInvoiceNumber();
    }
  }

  void _loadSharedData() {
    final companyId = UserProfileService.instance.companyId;
    if (companyId == null) return;
    _customersSubscription = CompanyService.instance
        .getCustomersStream(companyId)
        .listen((customers) {
      if (mounted) setState(() => _companyCustomers = customers);
    });
  }

  Future<void> _generateInvoiceNumber() async {
    final companyId = UserProfileService.instance.companyId;
    if (companyId == null) return;
    final number = await FirestoreSyncService.instance.getNextInvoiceNumberFromFirestore(companyId);
    if (mounted) setState(() => _invoiceNumber = number);
  }

  void _populateFromInvoice(Invoice inv) {
    _invoiceNumber = inv.invoiceNumber;
    _customerNameController.text = inv.customerName;
    _customerAddressController.text = inv.customerAddress;
    _customerEmailController.text = inv.customerEmail ?? '';
    _date = inv.date;
    _dueDate = inv.dueDate;
    _includeVat = inv.includeVat;
    _useCompanyBranding = inv.useCompanyBranding;
    _notesController.text = inv.notes ?? '';
    _items.clear();
    for (final item in inv.items) {
      _items.add(_LineItem(
        descController: TextEditingController(text: item.description),
        qtyController: TextEditingController(text: '${item.quantity}'),
        priceController: TextEditingController(text: '${item.unitPrice}'),
      ));
    }
    if (_items.isEmpty) _items.add(_LineItem());
  }

  @override
  void dispose() {
    _customersSubscription?.cancel();
    _customerNameController.dispose();
    _customerAddressController.dispose();
    _customerEmailController.dispose();
    _notesController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _saveInvoice() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty || _items.every((i) => i.descController.text.trim().isEmpty)) {
      context.showErrorToast('Add at least one line item');
      return;
    }

    final companyId = UserProfileService.instance.companyId;
    final user = FirebaseAuth.instance.currentUser;
    if (companyId == null || user == null) return;

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final invoiceItems = _items
          .where((i) => i.descController.text.trim().isNotEmpty)
          .map((i) => InvoiceItem(
                description: i.descController.text.trim(),
                quantity: double.tryParse(i.qtyController.text) ?? 1,
                unitPrice: double.tryParse(i.priceController.text) ?? 0,
              ))
          .toList();

      final invoice = Invoice(
        id: _isEdit ? widget.editInvoice!.id : const Uuid().v4(),
        invoiceNumber: _invoiceNumber,
        engineerId: _isEdit ? widget.editInvoice!.engineerId : user.uid,
        engineerName: _isEdit
            ? widget.editInvoice!.engineerName
            : (user.displayName ?? user.email?.split('@')[0] ?? ''),
        companyId: companyId,
        customerName: _customerNameController.text.trim(),
        customerAddress: _customerAddressController.text.trim(),
        customerEmail: _nullIfEmpty(_customerEmailController.text),
        date: _date,
        dueDate: _dueDate,
        items: invoiceItems,
        notes: _nullIfEmpty(_notesController.text),
        includeVat: _includeVat,
        status: _isEdit ? widget.editInvoice!.status : InvoiceStatus.draft,
        createdAt: _isEdit ? widget.editInvoice!.createdAt : now,
        lastModifiedAt: now,
        useCompanyBranding: _useCompanyBranding,
      );

      await FirestoreSyncService.instance.saveInvoiceToFirestore(invoice);

      if (mounted) {
        context.showSuccessToast(_isEdit ? 'Invoice updated' : 'Invoice created');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        context.showErrorToast('Failed to save invoice: $e');
      }
    }
  }

  String? _nullIfEmpty(String text) {
    final trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
          if (!_isLoading) _saveInvoice();
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Column(
            children: [
              _buildFormHeader(isDark),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 900),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildLeftColumn(isDark)),
                                const SizedBox(width: 32),
                                Expanded(child: _buildRightColumn(isDark)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 48,
                                    child: OutlinedButton(
                                      onPressed: () => Navigator.of(context).pop(),
                                      style: OutlinedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: const Text('Cancel',
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: SizedBox(
                                    height: 48,
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _saveInvoice,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryBlue,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 20, height: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                            )
                                          : Text(
                                              _isEdit ? 'Update Invoice' : 'Create Invoice',
                                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppTheme.darkDivider : AppTheme.dividerColor,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(AppIcons.arrowLeft),
            tooltip: 'Back',
          ),
          const SizedBox(width: 8),
          Text(
            _isEdit ? 'Edit Invoice' : 'Create New Invoice',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (_invoiceNumber.isNotEmpty) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _invoiceNumber,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryBlue),
              ),
            ),
          ],
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _isLoading ? null : _saveInvoice,
            child: Text(_isEdit ? 'Update Invoice' : 'Create Invoice'),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftColumn(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionCard(
          title: 'Customer',
          isDark: isDark,
          children: [
            _buildCustomerAutocomplete(),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _customerAddressController,
              label: 'Address',
              hint: 'Customer address',
              prefixIcon: Icon(AppIcons.location),
              maxLines: 2,
              validator: (v) => v == null || v.trim().isEmpty ? 'Address is required' : null,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _customerEmailController,
              label: 'Email',
              prefixIcon: Icon(AppIcons.sms),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        const SizedBox(height: 20),
        _sectionCard(
          title: 'Invoice Details',
          isDark: isDark,
          children: [
            InkWell(
              onTap: () => _pickDate(isDate: true),
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Invoice Date',
                  prefixIcon: Icon(AppIcons.calendar),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(DateFormat('dd/MM/yyyy').format(_date)),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => _pickDate(isDate: false),
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Due Date',
                  prefixIcon: Icon(AppIcons.calendar),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(DateFormat('dd/MM/yyyy').format(_dueDate)),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Include VAT (20%)'),
              value: _includeVat,
              onChanged: (v) => setState(() => _includeVat = v),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text('Use Company Branding'),
              value: _useCompanyBranding,
              onChanged: (v) => setState(() => _useCompanyBranding = v),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRightColumn(bool isDark) {
    final currencyFmt = NumberFormat.currency(symbol: '\u00A3', decimalDigits: 2);
    double subtotal = 0;
    for (final item in _items) {
      final qty = double.tryParse(item.qtyController.text) ?? 0;
      final price = double.tryParse(item.priceController.text) ?? 0;
      subtotal += qty * price;
    }
    final vat = _includeVat ? subtotal * 0.20 : 0.0;
    final total = subtotal + vat;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionCard(
          title: 'Line Items',
          isDark: isDark,
          children: [
            ..._items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDark ? AppTheme.darkDivider : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text('Item ${index + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
                              )),
                          const Spacer(),
                          if (_items.length > 1)
                            IconButton(
                              icon: Icon(AppIcons.trash, size: 16, color: AppTheme.errorRed),
                              onPressed: () => setState(() {
                                item.dispose();
                                _items.removeAt(index);
                              }),
                              iconSize: 16,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      CustomTextField(
                        controller: item.descController,
                        label: 'Description',
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              controller: item.qtyController,
                              label: 'Qty',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: CustomTextField(
                              controller: item.priceController,
                              label: 'Unit Price (\u00A3)',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _items.add(_LineItem())),
                icon: Icon(AppIcons.add, size: 16),
                label: const Text('Add Item'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _sectionCard(
          title: 'Totals',
          isDark: isDark,
          children: [
            _totalDisplayRow('Subtotal', currencyFmt.format(subtotal), isDark),
            if (_includeVat) ...[
              const SizedBox(height: 4),
              _totalDisplayRow('VAT (20%)', currencyFmt.format(vat), isDark),
            ],
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(currencyFmt.format(total),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        _sectionCard(
          title: 'Notes',
          isDark: isDark,
          children: [
            CustomTextField(
              controller: _notesController,
              label: 'Notes',
              hint: 'Payment terms, bank details, etc.',
              maxLines: 4,
            ),
          ],
        ),
      ],
    );
  }

  Widget _totalDisplayRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(
          fontSize: 14,
          color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
        )),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildCustomerAutocomplete() {
    return Autocomplete<CompanyCustomer>(
      displayStringForOption: (customer) => customer.name,
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.toLowerCase();
        if (query.isEmpty) return const Iterable.empty();
        return _companyCustomers.where((c) => c.name.toLowerCase().contains(query));
      },
      onSelected: (customer) {
        _customerNameController.text = customer.name;
        if (customer.address != null && customer.address!.isNotEmpty) {
          _customerAddressController.text = customer.address!;
        }
        if (customer.email != null && customer.email!.isNotEmpty) {
          _customerEmailController.text = customer.email!;
        }
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        if (controller.text.isEmpty && _customerNameController.text.isNotEmpty) {
          controller.text = _customerNameController.text;
        }
        controller.addListener(() => _customerNameController.text = controller.text);
        return CustomTextField(
          controller: controller,
          focusNode: focusNode,
          label: 'Customer Name',
          prefixIcon: Icon(AppIcons.user),
          validator: (v) => v == null || v.trim().isEmpty ? 'Customer is required' : null,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 400),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final customer = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    leading: Icon(AppIcons.user, size: 18),
                    title: Text(customer.name),
                    subtitle: customer.phone != null ? Text(customer.phone!) : null,
                    onTap: () => onSelected(customer),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sectionCard({
    required String title,
    required bool isDark,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? AppTheme.darkDivider : Colors.grey.shade300,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate({required bool isDate}) async {
    final initial = isDate ? _date : _dueDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isDate) {
          _date = picked;
        } else {
          _dueDate = picked;
        }
      });
    }
  }
}

class _LineItem {
  final TextEditingController descController;
  final TextEditingController qtyController;
  final TextEditingController priceController;

  _LineItem({
    TextEditingController? descController,
    TextEditingController? qtyController,
    TextEditingController? priceController,
  })  : descController = descController ?? TextEditingController(),
        qtyController = qtyController ?? TextEditingController(text: '1'),
        priceController = priceController ?? TextEditingController(text: '0');

  void dispose() {
    descController.dispose();
    qtyController.dispose();
    priceController.dispose();
  }
}
