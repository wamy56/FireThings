import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../services/database_helper.dart';
import '../../services/auth_service.dart';
import '../../utils/icon_map.dart';
import '../../utils/animate_helpers.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/premium_toast.dart';
import '../../widgets/adaptive_app_bar.dart';
import '../../widgets/premium_dialog.dart';

class SavedCustomersScreen extends StatefulWidget {
  const SavedCustomersScreen({super.key});

  @override
  State<SavedCustomersScreen> createState() => _SavedCustomersScreenState();
}

class _SavedCustomersScreenState extends State<SavedCustomersScreen> {
  final _dbHelper = DatabaseHelper.instance;
  final _authService = AuthService();

  List<SavedCustomer> _customers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);

    try {
      final user = _authService.currentUser;
      if (user != null) {
        final customers = await _dbHelper.getSavedCustomersByEngineerId(user.uid);
        setState(() {
          _customers = customers;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        context.showErrorToast('Error loading customers: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdaptiveNavigationBar(
        title: 'Saved Customers',
      ),
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: SkeletonList(itemCount: 5, showLeading: true),
            )
          : _customers.isEmpty
              ? _buildEmptyState()
              : _buildCustomerList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCustomerDialog(),
        child: const Icon(AppIcons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(AppIcons.people, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Saved Customers',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add customers here for quick selection when creating invoices',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showCustomerDialog(),
              icon: const Icon(AppIcons.add),
              label: const Text('Add Customer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _customers.length,
      itemBuilder: (context, index) {
        final customer = _customers[index];
        return _buildCustomerCard(customer).animateListItem(index);
      },
    );
  }

  Widget _buildCustomerCard(SavedCustomer customer) {
    return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              child: Text(
                customer.customerName[0].toUpperCase(),
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              customer.customerName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.customerAddress,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (customer.email != null && customer.email!.isNotEmpty)
                  Text(
                    customer.email!,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
              ],
            ),
            isThreeLine: true,
            trailing: IconButton(
              icon: Icon(AppIcons.more),
              onPressed: () => showAdaptiveActionSheet(
                context: context,
                options: [
                  ActionSheetOption(
                    label: 'Edit',
                    icon: AppIcons.edit,
                    onTap: () => _showCustomerDialog(customer: customer),
                  ),
                  ActionSheetOption(
                    label: 'Delete',
                    icon: AppIcons.trash,
                    isDestructive: true,
                    onTap: () => _confirmDelete(customer),
                  ),
                ],
              ),
            ),
          ),
        );
  }

  void _showCustomerDialog({SavedCustomer? customer}) {
    final nameController = TextEditingController(text: customer?.customerName ?? '');
    final addressController = TextEditingController(text: customer?.customerAddress ?? '');
    final emailController = TextEditingController(text: customer?.email ?? '');
    final notesController = TextEditingController(text: customer?.notes ?? '');
    final formKey = GlobalKey<FormState>();

    showPremiumDialog(
      context: context,
      child: Builder(
        builder: (context) => AlertDialog(
        title: Text(customer != null ? 'Edit Customer' : 'Add Customer'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Customer Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(AppIcons.building),
                  ),
                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(AppIcons.location),
                  ),
                  maxLines: 2,
                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(AppIcons.sms),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(AppIcons.note),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final user = _authService.currentUser;
                if (user == null) return;

                final newCustomer = SavedCustomer(
                  id: customer?.id ?? const Uuid().v4(),
                  engineerId: user.uid,
                  customerName: nameController.text,
                  customerAddress: addressController.text,
                  email: emailController.text.isEmpty ? null : emailController.text,
                  notes: notesController.text.isEmpty ? null : notesController.text,
                  createdAt: customer?.createdAt ?? DateTime.now(),
                );

                // Capture navigator before async gap
                final navigator = Navigator.of(context);

                try {
                  if (customer != null) {
                    await _dbHelper.updateSavedCustomer(newCustomer);
                  } else {
                    await _dbHelper.insertSavedCustomer(newCustomer);
                  }

                  if (mounted) {
                    navigator.pop();
                    _loadCustomers();
                    this.context.showSuccessToast(customer != null ? 'Customer updated' : 'Customer added');
                  }
                } catch (e) {
                  if (mounted) {
                    this.context.showErrorToast('Error: $e');
                  }
                }
              }
            },
            child: Text(customer != null ? 'Update' : 'Add'),
          ),
        ],
      )),
    );
  }

  void _confirmDelete(SavedCustomer customer) async {
    final confirm = await showAdaptiveAlertDialog<bool>(
      context: context,
      title: 'Delete Customer',
      message: 'Are you sure you want to delete "${customer.customerName}"?',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      isDestructive: true,
    );

    if (confirm == true) {
      try {
        await _dbHelper.deleteSavedCustomer(customer.id);
        if (mounted) {
          _loadCustomers();
          context.showSuccessToast('Customer deleted');
        }
      } catch (e) {
        if (mounted) {
          context.showErrorToast('Error: $e');
        }
      }
    }
  }
}
