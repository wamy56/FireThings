import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../utils/icon_map.dart';
import '../../utils/theme.dart';
import '../../services/quote_service.dart';
import '../../services/quote_pdf_service.dart';
import '../../services/email_service.dart';
import '../../services/auth_service.dart';
import '../../services/database_helper.dart';
import '../../services/analytics_service.dart';
import '../../services/company_service.dart';
import '../../services/user_profile_service.dart';
import '../../widgets/animated_save_button.dart';
import '../../widgets/premium_toast.dart';
import '../../widgets/adaptive_app_bar.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/keyboard_dismiss_wrapper.dart';
import '../common/pdf_preview_screen.dart';

class QuoteScreen extends StatefulWidget {
  final Quote? existingQuote;
  final Defect? fromDefect;
  final String? siteName;
  final String? siteId;
  final String? customerName;
  final String? customerAddress;
  final String? customerEmail;
  final String? customerPhone;

  const QuoteScreen({
    super.key,
    this.existingQuote,
    this.fromDefect,
    this.siteName,
    this.siteId,
    this.customerName,
    this.customerAddress,
    this.customerEmail,
    this.customerPhone,
  });

  @override
  State<QuoteScreen> createState() => _QuoteScreenState();
}

class _QuoteScreenState extends State<QuoteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _quoteService = QuoteService.instance;

  // Form controllers
  final _engineerNameController = TextEditingController();
  final _quoteNumberController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _customerAddressController = TextEditingController();
  final _customerEmailController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _notesController = TextEditingController();

  // Quote data
  DateTime _validUntil = DateTime.now().add(const Duration(days: 30));
  List<_ItemControllers> _itemControllers = [];
  bool _includeVat = false;
  bool _useCompanyBranding = false;
  bool _isLoading = false;
  bool _isSaved = false;
  QuoteStatus _status = QuoteStatus.draft;
  String? _quoteId;
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
      final user = _authService.currentUser;
      List<SavedCustomer> customers = [];
      if (user != null) {
        customers =
            await DatabaseHelper.instance.getSavedCustomersByEngineerId(user.uid);
        final profile = UserProfileService.instance;
        if (profile.hasCompany && profile.companyId != null) {
          final companyCustomers = await CompanyService.instance
              .getCustomersStream(profile.companyId!)
              .first;
          for (final cc in companyCustomers) {
            final alreadyExists = customers.any((c) =>
                c.customerName.toLowerCase() == cc.name.toLowerCase());
            if (!alreadyExists) {
              customers.add(SavedCustomer(
                id: cc.id,
                engineerId: user.uid,
                customerName: cc.name,
                customerAddress: cc.address ?? '',
                email: cc.email,
                createdAt: cc.createdAt,
              ));
            }
          }
        }
      }

      String engineerName = user?.displayName ?? user?.email?.split('@')[0] ?? '';

      if (widget.existingQuote != null) {
        _loadExistingQuote();
      } else if (widget.fromDefect != null) {
        _prefillFromDefect();
        final quoteNumber = await _quoteService.getNextQuoteNumber();
        _quoteNumberController.text = quoteNumber;
      } else {
        final quoteNumber = await _quoteService.getNextQuoteNumber();
        _quoteNumberController.text = quoteNumber;
      }

      setState(() {
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

  void _loadExistingQuote() {
    final quote = widget.existingQuote!;
    _quoteId = quote.id;
    _quoteNumberController.text = quote.quoteNumber;
    _engineerNameController.text = quote.engineerName;
    _customerNameController.text = quote.customerName;
    _customerAddressController.text = quote.customerAddress;
    _customerEmailController.text = quote.customerEmail ?? '';
    _customerPhoneController.text = quote.customerPhone ?? '';
    _validUntil = quote.validUntil;
    _includeVat = quote.includeVat;
    _useCompanyBranding = quote.useCompanyBranding;
    _notesController.text = quote.notes ?? '';
    _isSaved = true;
    _status = quote.status;

    _itemControllers.clear();
    for (final item in quote.items) {
      final controllers = _ItemControllers();
      controllers.description.text = item.description;
      controllers.quantity.text = item.quantity == item.quantity.truncateToDouble()
          ? item.quantity.toInt().toString()
          : item.quantity.toString();
      controllers.unitPrice.text = item.unitPrice.toStringAsFixed(2);
      controllers.category = item.category;
      _itemControllers.add(controllers);
    }
    _itemControllers.add(_ItemControllers());
  }

  void _prefillFromDefect() {
    final defect = widget.fromDefect!;
    _customerNameController.text = widget.customerName ?? '';
    _customerAddressController.text = widget.customerAddress ?? '';
    _customerEmailController.text = widget.customerEmail ?? '';
    _customerPhoneController.text = widget.customerPhone ?? '';

    // Add a suggested line item based on the defect
    final controllers = _ItemControllers();
    final clauseRef = defect.bs5839ClauseReference;
    controllers.description.text = clauseRef != null
        ? 'Repair: ${defect.description} (BS 5839-1:2025 cl. $clauseRef)'
        : 'Repair: ${defect.description}';
    controllers.quantity.text = '1';
    controllers.category = 'labour';
    _itemControllers = [controllers, _ItemControllers()];
  }

  Quote _buildQuote() {
    final user = _authService.currentUser;
    final profile = UserProfileService.instance.profile;
    final items = <QuoteItem>[];

    for (final c in _itemControllers) {
      if (c.description.text.trim().isEmpty) continue;
      items.add(QuoteItem(
        id: const Uuid().v4(),
        description: c.description.text.trim(),
        quantity: double.tryParse(c.quantity.text) ?? 1,
        unitPrice: double.tryParse(c.unitPrice.text) ?? 0,
        category: c.category,
      ));
    }

    return Quote(
      id: _quoteId ?? const Uuid().v4(),
      quoteNumber: _quoteNumberController.text,
      engineerId: user?.uid ?? '',
      engineerName: _engineerNameController.text.trim(),
      companyId: profile?.companyId,
      customerName: _customerNameController.text.trim(),
      customerAddress: _customerAddressController.text.trim(),
      customerEmail: _customerEmailController.text.trim().isNotEmpty
          ? _customerEmailController.text.trim()
          : null,
      customerPhone: _customerPhoneController.text.trim().isNotEmpty
          ? _customerPhoneController.text.trim()
          : null,
      siteId: widget.siteId ?? widget.existingQuote?.siteId ?? '',
      siteName: widget.siteName ?? widget.existingQuote?.siteName ?? '',
      defectId: widget.fromDefect?.id ?? widget.existingQuote?.defectId,
      defectDescription:
          widget.fromDefect?.description ?? widget.existingQuote?.defectDescription,
      defectSeverity:
          widget.fromDefect?.severity ?? widget.existingQuote?.defectSeverity,
      defectClauseReference:
          widget.fromDefect?.bs5839ClauseReference ??
              widget.existingQuote?.defectClauseReference,
      defectTriggeredProhibitedRule:
          widget.fromDefect?.triggeredProhibitedRule ??
              widget.existingQuote?.defectTriggeredProhibitedRule ??
              false,
      items: items,
      notes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
      includeVat: _includeVat,
      status: _status,
      validUntil: _validUntil,
      createdAt: widget.existingQuote?.createdAt ?? DateTime.now(),
      sentAt: widget.existingQuote?.sentAt,
      respondedAt: widget.existingQuote?.respondedAt,
      convertedJobId: widget.existingQuote?.convertedJobId,
      useCompanyBranding: _useCompanyBranding,
    );
  }

  bool _validateForm() {
    if (_customerNameController.text.trim().isEmpty) {
      context.showWarningToast('Please enter a customer name');
      return false;
    }
    if (_customerAddressController.text.trim().isEmpty) {
      context.showWarningToast('Please enter a customer address');
      return false;
    }
    final hasItems = _itemControllers.any((c) => c.description.text.trim().isNotEmpty);
    if (!hasItems) {
      context.showWarningToast('Please add at least one line item');
      return false;
    }
    return true;
  }

  Future<void> _saveQuote() async {
    if (!_validateForm()) return;
    setState(() => _isLoading = true);
    try {
      final quote = _buildQuote();
      if (_isSaved) {
        await _quoteService.updateQuote(quote);
      } else {
        await _quoteService.createQuote(quote);
        _quoteId = quote.id;

        // Link to defect if created from one
        if (widget.fromDefect != null &&
            widget.siteId != null) {
          final profile = UserProfileService.instance.profile;
          final basePath = profile?.companyId != null
              ? 'companies/${profile!.companyId}'
              : 'users/${_authService.currentUser!.uid}';
          await _quoteService.linkQuoteToDefect(
            basePath: basePath,
            siteId: widget.siteId!,
            defectId: widget.fromDefect!.id,
            quoteId: quote.id,
          );
        }
      }

      setState(() => _isSaved = true);
      if (mounted) context.showSuccessToast('Quote saved');
    } catch (e) {
      if (mounted) context.showErrorToast('Error saving quote: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _previewPdf() async {
    if (!_validateForm()) return;
    setState(() => _isLoading = true);
    try {
      final quote = _buildQuote();
      final pdfBytes = await QuotePdfService.generateQuotePdf(quote);
      setState(() => _isLoading = false);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfPreviewScreen(
              pdfBytes: pdfBytes,
              title: 'Quote ${quote.quoteNumber}',
              fileName: 'Quote_${quote.quoteNumber}.pdf',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) context.showErrorToast('Error generating PDF: $e');
    }
  }

  Future<void> _sendQuote() async {
    if (!_validateForm()) return;
    final email = _customerEmailController.text.trim();
    if (email.isEmpty) {
      context.showWarningToast('Please enter a customer email to send');
      return;
    }

    // Save first
    await _saveQuote();

    setState(() => _isLoading = true);
    try {
      final quote = _buildQuote();
      final pdfBytes = await QuotePdfService.generateQuotePdf(quote);

      await EmailService.sendQuote(
        recipientEmail: email,
        recipientName: quote.customerName,
        quoteNumber: quote.quoteNumber,
        total: quote.total,
        validUntil: quote.validUntil,
        pdfBytes: pdfBytes,
        senderName: quote.engineerName,
        senderPhone: quote.customerPhone,
      );

      // Update status to sent
      await _quoteService.updateQuoteStatus(quote.id, QuoteStatus.sent);
      AnalyticsService.instance.logQuoteSent(
        quoteId: quote.id,
        value: quote.total,
      );
      setState(() => _status = QuoteStatus.sent);

      if (mounted) context.showSuccessToast('Quote sent');
    } catch (e) {
      if (mounted) context.showErrorToast('Error sending quote: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _convertToJob() async {
    final quote = _buildQuote();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Convert to Job?'),
        content: const Text('This will create a new dispatched job from this quote.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successGreen, foregroundColor: Colors.white),
            child: const Text('Convert'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final job = await _quoteService.convertQuoteToJob(quote);
      setState(() {
        _status = QuoteStatus.converted;
        _isLoading = false;
      });
      if (mounted) {
        context.showSuccessToast('Job created: ${job.title}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) context.showErrorToast('Error: $e');
    }
  }

  @override
  void dispose() {
    _engineerNameController.dispose();
    _quoteNumberController.dispose();
    _customerNameController.dispose();
    _customerAddressController.dispose();
    _customerEmailController.dispose();
    _customerPhoneController.dispose();
    _notesController.dispose();
    for (final c in _itemControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AdaptiveNavigationBar(
        title: widget.existingQuote != null ? 'Edit Quote' : 'Create Quote',
        actions: [
          if (_status == QuoteStatus.draft)
            IconButton(
              icon: Icon(AppIcons.document),
              tooltip: 'Preview PDF',
              onPressed: _isLoading ? null : _previewPdf,
            ),
        ],
      ),
      body: KeyboardDismissWrapper(
        child: _isLoading && !_isSaved
            ? const Center(child: AdaptiveLoadingIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: EdgeInsets.all(AppTheme.screenPadding),
                  children: [
                    _buildQuoteInfoSection(isDark),
                    SizedBox(height: AppTheme.sectionGap),
                    _buildCustomerSection(isDark),
                    if (widget.fromDefect != null ||
                        widget.existingQuote?.defectId != null) ...[
                      SizedBox(height: AppTheme.sectionGap),
                      _buildDefectCard(isDark),
                    ],
                    SizedBox(height: AppTheme.sectionGap),
                    _buildItemsSection(isDark),
                    SizedBox(height: AppTheme.sectionGap),
                    _buildOptionsSection(isDark),
                    SizedBox(height: AppTheme.sectionGap),
                    _buildNotesSection(isDark),
                    SizedBox(height: AppTheme.sectionGap),
                    _buildActionButtons(isDark),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildQuoteInfoSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quote Details',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _quoteNumberController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Quote Number',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _engineerNameController,
                decoration: const InputDecoration(
                  labelText: 'Engineer Name',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _validUntil,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) setState(() => _validUntil = picked);
          },
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Valid Until',
              border: OutlineInputBorder(),
            ),
            child: Text(DateFormat('dd/MM/yyyy').format(_validUntil)),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Customer',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (_savedCustomers.isNotEmpty)
              TextButton.icon(
                icon: Icon(AppIcons.user, size: 16),
                label: const Text('Select Saved'),
                onPressed: _showCustomerPicker,
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _customerNameController,
          decoration: const InputDecoration(
            labelText: 'Customer Name *',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _customerAddressController,
          decoration: const InputDecoration(
            labelText: 'Address *',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _customerEmailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _customerPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDefectCard(bool isDark) {
    final defect = widget.fromDefect;
    final description = defect?.description ??
        widget.existingQuote?.defectDescription ??
        '';
    final severity = defect?.severity ??
        widget.existingQuote?.defectSeverity ??
        '';

    Color severityColor;
    switch (severity) {
      case 'critical':
        severityColor = AppTheme.errorRed;
        break;
      case 'major':
        severityColor = AppTheme.accentOrange;
        break;
      default:
        severityColor = AppTheme.successGreen;
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppTheme.cardPadding),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceElevated : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(
          color: isDark ? Colors.orange.shade800 : Colors.orange.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIcons.warning, size: 18, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Text(
                'Linked Defect',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: severityColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  severity.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection(bool isDark) {
    final currencyFormat =
        NumberFormat.currency(symbol: '\u00A3', decimalDigits: 2);
    double runningTotal = 0;
    for (final c in _itemControllers) {
      final qty = double.tryParse(c.quantity.text) ?? 0;
      final price = double.tryParse(c.unitPrice.text) ?? 0;
      runningTotal += qty * price;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Line Items',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              'Total: ${currencyFormat.format(runningTotal)}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...List.generate(_itemControllers.length, (index) {
          return _buildItemRow(index, isDark);
        }),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: Icon(AppIcons.addCircle),
          label: const Text('Add Item'),
          onPressed: () {
            setState(() => _itemControllers.add(_ItemControllers()));
          },
        ),
      ],
    );
  }

  Widget _buildItemRow(int index, bool isDark) {
    final c = _itemControllers[index];

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Item ${index + 1}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryBlue,
                ),
              ),
              IconButton(
                icon: Icon(AppIcons.close, size: 20, color: AppTheme.errorRed),
                onPressed: _itemControllers.length > 1
                    ? () {
                        setState(() {
                          _itemControllers[index].dispose();
                          _itemControllers.removeAt(index);
                        });
                      }
                    : null,
                tooltip: 'Remove',
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: c.description,
            decoration: InputDecoration(
              labelText: 'Description',
              border: const OutlineInputBorder(),
              hintText: index == _itemControllers.length - 1
                  ? 'Add new item...'
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 100,
                child: DropdownButtonFormField<String>(
                  initialValue: c.category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  ),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('-')),
                    DropdownMenuItem(
                        value: 'labour', child: Text('Labour')),
                    DropdownMenuItem(value: 'parts', child: Text('Parts')),
                    DropdownMenuItem(
                        value: 'materials', child: Text('Materials')),
                  ],
                  onChanged: (val) => setState(() => c.category = val),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: c.quantity,
                  decoration: const InputDecoration(
                    labelText: 'Qty',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: c.unitPrice,
                  decoration: const InputDecoration(
                    labelText: 'Unit Price',
                    border: OutlineInputBorder(),
                    prefixText: '\u00A3',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsSection(bool isDark) {
    final hasCompany =
        UserProfileService.instance.profile?.companyId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Options',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('Include VAT (20%)'),
          value: _includeVat,
          onChanged: (val) => setState(() => _includeVat = val),
          contentPadding: EdgeInsets.zero,
        ),
        if (hasCompany)
          SwitchListTile(
            title: const Text('Use Company Branding'),
            value: _useCompanyBranding,
            onChanged: (val) => setState(() => _useCompanyBranding = val),
            contentPadding: EdgeInsets.zero,
          ),
      ],
    );
  }

  Widget _buildNotesSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notes',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _notesController,
          decoration: const InputDecoration(
            hintText: 'Additional notes for the customer...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildActionButtons(bool isDark) {
    switch (_status) {
      case QuoteStatus.draft:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedSaveButton(
              label: 'Save Draft',
              onPressed: _saveQuote,
              enabled: !_isLoading,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: Icon(AppIcons.eye),
              label: const Text('Preview PDF'),
              onPressed: _isLoading ? null : _previewPdf,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: Icon(AppIcons.send),
              label: const Text('Send Quote'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
              ),
              onPressed: _isLoading ? null : _sendQuote,
            ),
          ],
        );
      case QuoteStatus.sent:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              icon: Icon(AppIcons.eye),
              label: const Text('Preview PDF'),
              onPressed: _isLoading ? null : _previewPdf,
            ),
          ],
        );
      case QuoteStatus.approved:
        final hasCompany =
            UserProfileService.instance.profile?.companyId != null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              icon: Icon(AppIcons.eye),
              label: const Text('Preview PDF'),
              onPressed: _isLoading ? null : _previewPdf,
            ),
            if (hasCompany) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: Icon(AppIcons.send),
                label: const Text('Convert to Job'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successGreen,
                  foregroundColor: Colors.white,
                ),
                onPressed: _isLoading ? null : _convertToJob,
              ),
            ],
          ],
        );
      case QuoteStatus.declined:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              icon: Icon(AppIcons.edit),
              label: const Text('Edit & Resend'),
              onPressed: () {
                setState(() => _status = QuoteStatus.draft);
              },
            ),
          ],
        );
      case QuoteStatus.converted:
        return const SizedBox.shrink();
    }
  }

  void _showCustomerPicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _savedCustomers.length,
        itemBuilder: (ctx, index) {
          final customer = _savedCustomers[index];
          return ListTile(
            title: Text(customer.customerName),
            subtitle: Text(customer.customerAddress),
            onTap: () {
              _customerNameController.text = customer.customerName;
              _customerAddressController.text = customer.customerAddress;
              _customerEmailController.text = customer.email ?? '';
              Navigator.pop(ctx);
            },
          );
        },
      ),
    );
  }
}

class _ItemControllers {
  final description = TextEditingController();
  final quantity = TextEditingController(text: '1');
  final unitPrice = TextEditingController();
  String? category;

  void dispose() {
    description.dispose();
    quantity.dispose();
    unitPrice.dispose();
  }
}
