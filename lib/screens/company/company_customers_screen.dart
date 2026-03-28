import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../../models/company_customer.dart';
import '../../services/company_service.dart';
import '../../services/user_profile_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/keyboard_dismiss_wrapper.dart';
import '../../widgets/premium_toast.dart';
import '../../widgets/premium_dialog.dart';

class CompanyCustomersScreen extends StatefulWidget {
  final String companyId;

  const CompanyCustomersScreen({super.key, required this.companyId});

  @override
  State<CompanyCustomersScreen> createState() => _CompanyCustomersScreenState();
}

class _CompanyCustomersScreenState extends State<CompanyCustomersScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  bool get _canEdit => UserProfileService.instance.isDispatcherOrAdmin;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Shared Customers')),
      floatingActionButton: _canEdit && MediaQuery.of(context).viewInsets.bottom == 0
          ? FloatingActionButton.extended(
              onPressed: () => _showCustomerDialog(),
              icon: Icon(AppIcons.add),
              label: const Text('Add Customer'),
            )
          : null,
      body: KeyboardDismissWrapper(child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 750),
          child: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search customers...',
                prefixIcon: const Icon(AppIcons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(AppIcons.close),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // Stream content
          Expanded(
            child: StreamBuilder<List<CompanyCustomer>>(
              stream: CompanyService.instance.getCustomersStream(widget.companyId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: AdaptiveLoadingIndicator());
                }

                final customers = snapshot.data ?? [];
                final filtered = _searchQuery.isEmpty
                    ? customers
                    : customers.where((c) {
                        final q = _searchQuery.toLowerCase();
                        return c.name.toLowerCase().contains(q) ||
                            (c.address?.toLowerCase().contains(q) ?? false) ||
                            (c.email?.toLowerCase().contains(q) ?? false) ||
                            (c.phone?.toLowerCase().contains(q) ?? false);
                      }).toList();

                // Count label
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Text(
                            '${filtered.length} customer${filtered.length == 1 ? '' : 's'}',
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _searchQuery.isNotEmpty
                                        ? AppIcons.searchOff
                                        : AppIcons.user,
                                    size: 64,
                                    color: isDark
                                        ? AppTheme.darkTextSecondary
                                        : AppTheme.mediumGrey,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'No Results Found'
                                        : 'No shared customers yet',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: isDark
                                          ? AppTheme.darkTextSecondary
                                          : AppTheme.mediumGrey,
                                    ),
                                  ),
                                  if (_searchQuery.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Try a different search term',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isDark
                                            ? AppTheme.darkTextSecondary
                                            : AppTheme.textHint,
                                      ),
                                    ),
                                  ] else if (_canEdit) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Tap + to add a customer',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isDark
                                            ? AppTheme.darkTextSecondary
                                            : AppTheme.textHint,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(AppTheme.screenPadding),
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final customer = filtered[index];
                                return _buildCustomerCard(customer, isDark);
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
          ),
        )),
    );
  }

  Widget _buildCustomerCard(CompanyCustomer customer, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.cardPadding),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: isDark ? null : AppTheme.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            AppIcons.user,
            size: 20,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (customer.address != null &&
                    customer.address!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    customer.address!,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.mediumGrey,
                    ),
                  ),
                ],
                if (customer.email != null && customer.email!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    customer.email!,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.mediumGrey,
                    ),
                  ),
                ],
                if (customer.phone != null && customer.phone!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    customer.phone!,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.mediumGrey,
                    ),
                  ),
                ],
                if (customer.notes != null && customer.notes!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    customer.notes!,
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textHint,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_canEdit)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _showCustomerDialog(customer: customer);
                } else if (value == 'delete') {
                  _confirmDelete(customer);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(AppIcons.edit, size: 18),
                      const SizedBox(width: 8),
                      const Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 8),
                      const Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _showCustomerDialog({CompanyCustomer? customer}) async {
    final nameController = TextEditingController(text: customer?.name ?? '');
    final addressController = TextEditingController(
      text: customer?.address ?? '',
    );
    final emailController = TextEditingController(text: customer?.email ?? '');
    final phoneController = TextEditingController(text: customer?.phone ?? '');
    final notesController = TextEditingController(text: customer?.notes ?? '');
    final isEdit = customer != null;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Edit Customer' : 'Add Customer'),
        content: SizedBox(
          width: 500,
          child: KeyboardDismissWrapper(
          child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                controller: nameController,
                label: 'Customer Name',
                prefixIcon: Icon(AppIcons.user),
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: addressController,
                label: 'Address (optional)',
                prefixIcon: Icon(AppIcons.location),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: emailController,
                label: 'Email (optional)',
                prefixIcon: Icon(AppIcons.sms),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: phoneController,
                label: 'Phone (optional)',
                prefixIcon: Icon(AppIcons.call),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: notesController,
                label: 'Notes (optional)',
                prefixIcon: Icon(AppIcons.note),
                maxLines: 2,
              ),
            ],
          ),
        ),
        ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(isEdit ? 'Save' : 'Add'),
          ),
        ],
      ),
    );

    if (result != true) return;

    final name = nameController.text.trim();
    if (name.isEmpty) {
      if (mounted) context.showErrorToast('Customer name is required');
      return;
    }

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final now = DateTime.now();
      final address = addressController.text.trim();
      final email = emailController.text.trim();
      final phone = phoneController.text.trim();
      final notes = notesController.text.trim();

      if (isEdit) {
        final updated = customer.copyWith(
          name: name,
          address: address.isEmpty ? null : address,
          email: email.isEmpty ? null : email,
          phone: phone.isEmpty ? null : phone,
          notes: notes.isEmpty ? null : notes,
          updatedAt: now,
        );
        await CompanyService.instance.updateCustomer(widget.companyId, updated);
        if (mounted) context.showSuccessToast('Customer updated');
      } else {
        final newCustomer = CompanyCustomer(
          id: const Uuid().v4(),
          name: name,
          address: address.isEmpty ? null : address,
          email: email.isEmpty ? null : email,
          phone: phone.isEmpty ? null : phone,
          notes: notes.isEmpty ? null : notes,
          createdBy: uid,
          createdAt: now,
        );
        await CompanyService.instance.createCustomer(
          widget.companyId,
          newCustomer,
        );
        if (mounted) context.showSuccessToast('Customer added');
      }
    } catch (e) {
      if (mounted) context.showErrorToast('Failed to save customer');
    }
  }

  Future<void> _confirmDelete(CompanyCustomer customer) async {
    final confirm = await showAdaptiveAlertDialog<bool>(
      context: context,
      title: 'Delete Customer',
      message:
          'Are you sure you want to delete "${customer.name}"? This cannot be undone.',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      isDestructive: true,
    );

    if (confirm != true) return;

    try {
      await CompanyService.instance.deleteCustomer(
        widget.companyId,
        customer.id,
      );
      if (mounted) context.showWarningToast('Customer deleted');
    } catch (e) {
      if (mounted) context.showErrorToast('Failed to delete customer');
    }
  }
}
