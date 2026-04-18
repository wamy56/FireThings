import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../models/quote.dart';
import '../../models/company_site.dart';
import '../../models/company_customer.dart';
import '../../services/quote_service.dart';
import '../../services/company_service.dart';
import '../../services/user_profile_service.dart';
import '../../services/analytics_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/premium_toast.dart';

class WebCreateQuoteScreen extends StatefulWidget {
  final Quote? editQuote;

  const WebCreateQuoteScreen({super.key, this.editQuote});

  @override
  State<WebCreateQuoteScreen> createState() => _WebCreateQuoteScreenState();
}

class _WebCreateQuoteScreenState extends State<WebCreateQuoteScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isEdit = false;

  // Customer
  final _customerNameController = TextEditingController();
  final _customerAddressController = TextEditingController();
  final _customerEmailController = TextEditingController();
  final _customerPhoneController = TextEditingController();

  // Site
  final _siteNameController = TextEditingController();
  String _selectedSiteId = '';

  // Quote details
  String _quoteNumber = '';
  DateTime _validUntil = DateTime.now().add(const Duration(days: 30));
  bool _includeVat = false;
  bool _useCompanyBranding = false;

  // Items
  final List<_LineItem> _items = [_LineItem()];

  // Notes
  final _notesController = TextEditingController();

  // Defect (read-only if editing a defect-linked quote)
  String? _defectId;
  String? _defectDescription;
  String? _defectSeverity;

  // Autocomplete data
  List<CompanySite> _companySites = [];
  List<CompanyCustomer> _companyCustomers = [];
  StreamSubscription? _sitesSubscription;
  StreamSubscription? _customersSubscription;

  @override
  void initState() {
    super.initState();
    _loadSharedData();
    if (widget.editQuote != null) {
      _isEdit = widget.editQuote!.id.isNotEmpty;
      _populateFromQuote(widget.editQuote!);
    } else {
      _generateQuoteNumber();
    }
  }

  void _loadSharedData() {
    final companyId = UserProfileService.instance.companyId;
    if (companyId == null) return;
    _sitesSubscription = CompanyService.instance
        .getSitesStream(companyId)
        .listen((sites) {
      if (mounted) setState(() => _companySites = sites);
    });
    _customersSubscription = CompanyService.instance
        .getCustomersStream(companyId)
        .listen((customers) {
      if (mounted) setState(() => _companyCustomers = customers);
    });
  }

  Future<void> _generateQuoteNumber() async {
    final companyId = UserProfileService.instance.companyId;
    if (companyId == null) return;
    final number = await QuoteService.instance.getNextQuoteNumberFromFirestore(companyId);
    if (mounted) setState(() => _quoteNumber = number);
  }

  void _populateFromQuote(Quote q) {
    _quoteNumber = q.quoteNumber;
    _customerNameController.text = q.customerName;
    _customerAddressController.text = q.customerAddress;
    _customerEmailController.text = q.customerEmail ?? '';
    _customerPhoneController.text = q.customerPhone ?? '';
    _siteNameController.text = q.siteName;
    _selectedSiteId = q.siteId;
    _validUntil = q.validUntil;
    _includeVat = q.includeVat;
    _useCompanyBranding = q.useCompanyBranding;
    _defectId = q.defectId;
    _defectDescription = q.defectDescription;
    _defectSeverity = q.defectSeverity;
    _notesController.text = q.notes ?? '';
    _items.clear();
    for (final item in q.items) {
      _items.add(_LineItem(
        descController: TextEditingController(text: item.description),
        qtyController: TextEditingController(text: '${item.quantity}'),
        priceController: TextEditingController(text: '${item.unitPrice}'),
        category: item.category,
      ));
    }
    if (_items.isEmpty) _items.add(_LineItem());
  }

  @override
  void dispose() {
    _sitesSubscription?.cancel();
    _customersSubscription?.cancel();
    _customerNameController.dispose();
    _customerAddressController.dispose();
    _customerEmailController.dispose();
    _customerPhoneController.dispose();
    _siteNameController.dispose();
    _notesController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _saveQuote() async {
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
      final quoteItems = _items
          .where((i) => i.descController.text.trim().isNotEmpty)
          .map((i) => QuoteItem(
                id: const Uuid().v4(),
                description: i.descController.text.trim(),
                quantity: double.tryParse(i.qtyController.text) ?? 1,
                unitPrice: double.tryParse(i.priceController.text) ?? 0,
                category: i.category,
              ))
          .toList();

      final quote = Quote(
        id: _isEdit ? widget.editQuote!.id : const Uuid().v4(),
        quoteNumber: _quoteNumber,
        engineerId: _isEdit ? widget.editQuote!.engineerId : user.uid,
        engineerName: _isEdit
            ? widget.editQuote!.engineerName
            : (user.displayName ?? user.email?.split('@')[0] ?? ''),
        companyId: companyId,
        customerName: _customerNameController.text.trim(),
        customerAddress: _customerAddressController.text.trim(),
        customerEmail: _nullIfEmpty(_customerEmailController.text),
        customerPhone: _nullIfEmpty(_customerPhoneController.text),
        siteId: _selectedSiteId.isNotEmpty ? _selectedSiteId : const Uuid().v4(),
        siteName: _siteNameController.text.trim(),
        defectId: _defectId,
        defectDescription: _defectDescription,
        defectSeverity: _defectSeverity,
        items: quoteItems,
        notes: _nullIfEmpty(_notesController.text),
        includeVat: _includeVat,
        status: _isEdit ? widget.editQuote!.status : QuoteStatus.draft,
        validUntil: _validUntil,
        createdAt: _isEdit ? widget.editQuote!.createdAt : now,
        lastModifiedAt: now,
        useCompanyBranding: _useCompanyBranding,
      );

      await QuoteService.instance.saveQuoteToFirestore(quote);

      if (!_isEdit) {
        AnalyticsService.instance.logQuoteCreated(
          fromDefect: quote.defectId != null,
          value: quote.total,
        );
      }

      if (mounted) {
        context.showSuccessToast(_isEdit ? 'Quote updated' : 'Quote created');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        context.showErrorToast('Failed to save quote: $e');
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
          if (!_isLoading) _saveQuote();
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
                                      onPressed: _isLoading ? null : _saveQuote,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryBlue,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                            )
                                          : Text(
                                              _isEdit ? 'Update Quote' : 'Create Quote',
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
            _isEdit ? 'Edit Quote' : 'Create New Quote',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (_quoteNumber.isNotEmpty) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _quoteNumber,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryBlue,
                ),
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
            onPressed: _isLoading ? null : _saveQuote,
            child: Text(_isEdit ? 'Update Quote' : 'Create Quote'),
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
            const SizedBox(height: 16),
            CustomTextField(
              controller: _customerPhoneController,
              label: 'Phone',
              prefixIcon: Icon(AppIcons.call),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        const SizedBox(height: 20),
        _sectionCard(
          title: 'Site',
          isDark: isDark,
          children: [
            _buildSiteAutocomplete(),
          ],
        ),
        const SizedBox(height: 20),
        _sectionCard(
          title: 'Quote Details',
          isDark: isDark,
          children: [
            InkWell(
              onTap: _pickValidUntilDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Valid Until',
                  prefixIcon: Icon(AppIcons.calendar),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(DateFormat('dd/MM/yyyy').format(_validUntil)),
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
        if (_defectDescription != null) ...[
          const SizedBox(height: 20),
          _sectionCard(
            title: 'Linked Defect',
            isDark: isDark,
            children: [
              Text(_defectDescription!, style: const TextStyle(fontSize: 14)),
              if (_defectSeverity != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Severity: $_defectSeverity',
                  style: TextStyle(fontSize: 13, color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey),
                ),
              ],
            ],
          ),
        ],
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
                        hint: 'e.g. Smoke detector replacement',
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
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 80,
                            child: DropdownButtonFormField<String?>(
                              initialValue: item.category,
                              decoration: InputDecoration(
                                labelText: 'Type',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                              ),
                              items: const [
                                DropdownMenuItem(value: null, child: Text('-')),
                                DropdownMenuItem(value: 'labour', child: Text('Labour')),
                                DropdownMenuItem(value: 'parts', child: Text('Parts')),
                                DropdownMenuItem(value: 'materials', child: Text('Materials')),
                              ],
                              onChanged: (v) => setState(() => item.category = v),
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
                Text(
                  currencyFmt.format(total),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
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
              hint: 'Additional notes for the quote',
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

  Widget _buildSiteAutocomplete() {
    return Autocomplete<CompanySite>(
      displayStringForOption: (site) => site.name,
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.toLowerCase();
        if (query.isEmpty) return const Iterable.empty();
        return _companySites.where((s) => s.name.toLowerCase().contains(query));
      },
      onSelected: (site) {
        _siteNameController.text = site.name;
        _selectedSiteId = site.id;
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        if (controller.text.isEmpty && _siteNameController.text.isNotEmpty) {
          controller.text = _siteNameController.text;
        }
        controller.addListener(() => _siteNameController.text = controller.text);
        return CustomTextField(
          controller: controller,
          focusNode: focusNode,
          label: 'Site Name',
          hint: 'e.g. Hilton Hotel Manchester',
          prefixIcon: Icon(AppIcons.building),
          validator: (v) => v == null || v.trim().isEmpty ? 'Site is required' : null,
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
                  final site = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    leading: Icon(AppIcons.building, size: 18),
                    title: Text(site.name),
                    subtitle: Text(site.address, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => onSelected(site),
                  );
                },
              ),
            ),
          ),
        );
      },
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
        if (customer.phone != null && customer.phone!.isNotEmpty) {
          _customerPhoneController.text = customer.phone!;
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

  Future<void> _pickValidUntilDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _validUntil,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _validUntil = picked);
  }
}

class _LineItem {
  final TextEditingController descController;
  final TextEditingController qtyController;
  final TextEditingController priceController;
  String? category;

  _LineItem({
    TextEditingController? descController,
    TextEditingController? qtyController,
    TextEditingController? priceController,
    this.category,
  })  : descController = descController ?? TextEditingController(),
        qtyController = qtyController ?? TextEditingController(text: '1'),
        priceController = priceController ?? TextEditingController(text: '0');

  void dispose() {
    descController.dispose();
    qtyController.dispose();
    priceController.dispose();
  }
}
