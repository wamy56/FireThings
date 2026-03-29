import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../services/database_helper.dart';
import '../../services/analytics_service.dart';
import '../../services/auth_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/animate_helpers.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/widgets.dart';

class SavedCustomersScreen extends StatefulWidget {
  const SavedCustomersScreen({super.key});

  @override
  State<SavedCustomersScreen> createState() => _SavedCustomersScreenState();
}

class _SavedCustomersScreenState extends State<SavedCustomersScreen> {
  final _dbHelper = DatabaseHelper.instance;
  final _authService = AuthService();
  final _searchController = TextEditingController();

  List<SavedCustomer> _allCustomers = [];
  List<SavedCustomer> _filteredCustomers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);

    try {
      final user = _authService.currentUser;
      if (user != null) {
        final customers = await _dbHelper.getSavedCustomersByEngineerId(user.uid);
        setState(() {
          _allCustomers = customers;
          _filterCustomers(_searchQuery);
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

  void _filterCustomers(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredCustomers = _allCustomers;
      } else {
        final q = query.toLowerCase();
        _filteredCustomers = _allCustomers.where((c) {
          return c.customerName.toLowerCase().contains(q) ||
              c.customerAddress.toLowerCase().contains(q) ||
              (c.email?.toLowerCase().contains(q) ?? false);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdaptiveNavigationBar(
        title: 'Saved Customers',
      ),
      body: KeyboardDismissWrapper(child: Column(
        children: [
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
                          _filterCustomers('');
                        },
                      )
                    : null,
              ),
              onChanged: _filterCustomers,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '${_filteredCustomers.length} customer${_filteredCustomers.length == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const LoadingIndicator()
                : _filteredCustomers.isEmpty
                    ? EmptyState(
                        icon: _searchQuery.isNotEmpty ? AppIcons.searchOff : AppIcons.people,
                        title: _searchQuery.isNotEmpty ? 'No Results Found' : 'No Saved Customers',
                        message: _searchQuery.isNotEmpty
                            ? 'Try a different search term'
                            : 'Add customers here for quick selection when creating invoices',
                      )
                    : AdaptiveRefreshIndicator(
                        onRefresh: _loadCustomers,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredCustomers.length,
                          itemBuilder: (context, index) {
                            final customer = _filteredCustomers[index];
                            return _buildCustomerCard(customer).animateListItem(index);
                          },
                        ),
                      ),
          ),
        ],
      )),
      floatingActionButton: MediaQuery.of(context).viewInsets.bottom > 0
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showCustomerDialog(),
              icon: const Icon(AppIcons.add),
              label: const Text('Add Customer'),
            ),
    );
  }

  Widget _buildCustomerCard(SavedCustomer customer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
          child: Icon(AppIcons.building, color: AppTheme.primaryBlue),
        ),
        title: Text(
          customer.customerName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              customer.customerAddress,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            if (customer.email != null && customer.email!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                customer.email!,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
            if (customer.notes != null && customer.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                customer.notes!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _ActionButton(
                  label: 'Edit',
                  onPressed: () => _showCustomerDialog(customer: customer),
                ),
                _ActionButton(
                  label: 'Delete',
                  onPressed: () => _confirmDelete(customer),
                  isDestructive: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomerDialog({SavedCustomer? customer}) {
    final nameController = TextEditingController(text: customer?.customerName ?? '');
    final addressController = TextEditingController(text: customer?.customerAddress ?? '');
    final emailController = TextEditingController(text: customer?.email ?? '');
    final notesController = TextEditingController(text: customer?.notes ?? '');

    showPremiumDialog(
      context: context,
      child: Builder(
        builder: (context) => AlertDialog(
        title: Text(customer != null ? 'Edit Customer' : 'Add Customer'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                controller: nameController,
                label: 'Customer Name *',
                hint: 'e.g., ABC Fire Ltd',
                prefixIcon: const Icon(AppIcons.building),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: addressController,
                label: 'Address *',
                hint: 'Full address',
                maxLines: 2,
                prefixIcon: const Icon(AppIcons.location),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: emailController,
                label: 'Email',
                hint: 'Optional',
                prefixIcon: const Icon(AppIcons.sms),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: notesController,
                label: 'Notes',
                hint: 'Optional notes',
                maxLines: 2,
                prefixIcon: const Icon(AppIcons.note),
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
              if (nameController.text.trim().isEmpty ||
                  addressController.text.trim().isEmpty) {
                showValidationBanner(context: context, message: 'Customer name and address are required');
                return;
              }

              final user = _authService.currentUser;
              if (user == null) return;

              final newCustomer = SavedCustomer(
                id: customer?.id ?? const Uuid().v4(),
                engineerId: user.uid,
                customerName: nameController.text.trim(),
                customerAddress: addressController.text.trim(),
                email: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                createdAt: customer?.createdAt ?? DateTime.now(),
              );

              final navigator = Navigator.of(context);

              try {
                if (customer != null) {
                  await _dbHelper.updateSavedCustomer(newCustomer);
                } else {
                  await _dbHelper.insertSavedCustomer(newCustomer);
                  AnalyticsService.instance.logCustomerSaved('settings');
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

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isDestructive;

  const _ActionButton({
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.red : AppTheme.primaryBlue;
    return SizedBox(
      height: 30,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label),
      ),
    );
  }
}
