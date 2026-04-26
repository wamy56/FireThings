import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/company_customer.dart';
import '../../models/permission.dart';
import '../../services/company_service.dart';
import '../../services/user_profile_service.dart';
import '../../theme/web_theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/premium_toast.dart';

class WebCustomerDetailPanel extends StatefulWidget {
  final String customerId;
  final VoidCallback onClose;
  final bool animateIn;

  const WebCustomerDetailPanel({
    super.key,
    required this.customerId,
    required this.onClose,
    this.animateIn = true,
  });

  @override
  State<WebCustomerDetailPanel> createState() => _WebCustomerDetailPanelState();
}

class _WebCustomerDetailPanelState extends State<WebCustomerDetailPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;

  String? get _companyId => UserProfileService.instance.companyId;
  bool get _canEdit => UserProfileService.instance.hasPermission(AppPermission.customersEdit);
  bool get _canDelete => UserProfileService.instance.hasPermission(AppPermission.customersDelete);

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: FtMotion.slow,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: FtMotion.standardCurve,
    ));
    if (widget.animateIn) {
      _slideController.forward();
    } else {
      _slideController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _closePanel() async {
    _slideController.reverse();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final companyId = _companyId;
    if (companyId == null) {
      return const Center(child: Text('No company found'));
    }

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        decoration: const BoxDecoration(
          color: FtColors.bg,
          boxShadow: FtShadows.lg,
          border: Border(left: BorderSide(color: FtColors.border, width: 1.5)),
        ),
        child: StreamBuilder<List<CompanyCustomer>>(
          stream: CompanyService.instance.getCustomersStream(companyId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: AdaptiveLoadingIndicator());
            }

            final customers = snapshot.data ?? [];
            final customer = customers.cast<CompanyCustomer?>().firstWhere(
              (c) => c!.id == widget.customerId,
              orElse: () => null,
            );

            if (customer == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(AppIcons.warning, size: 32, color: FtColors.hint),
                    const SizedBox(height: 8),
                    Text('Customer not found', style: FtText.bodySoft),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _closePanel,
                      style: TextButton.styleFrom(foregroundColor: FtColors.fg2),
                      child: Text('Close', style: FtText.button),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                _buildPanelHeader(customer),
                Expanded(
                  child: ListView(
                    padding: FtSpacing.cardBody,
                    children: [
                      _buildSection('Customer Details', [
                        _detailRow('Name', customer.name),
                        if (customer.address != null && customer.address!.isNotEmpty)
                          _detailRow('Address', customer.address!),
                        if (customer.email != null && customer.email!.isNotEmpty)
                          _detailRow('Email', customer.email!),
                        if (customer.phone != null && customer.phone!.isNotEmpty)
                          _detailRow('Phone', customer.phone!),
                        if (customer.notes != null && customer.notes!.isNotEmpty)
                          _detailRow('Notes', customer.notes!),
                      ]),
                      const SizedBox(height: 16),
                      _buildSection('Activity', [
                        _detailRow('Created', DateFormat('dd MMM yyyy, HH:mm').format(customer.createdAt)),
                        if (customer.updatedAt != null)
                          _detailRow('Updated', DateFormat('dd MMM yyyy, HH:mm').format(customer.updatedAt!)),
                      ]),
                      const SizedBox(height: 24),
                      _buildActionButtons(customer),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPanelHeader(CompanyCustomer customer) {
    return Container(
      padding: FtSpacing.cardHeader,
      decoration: const BoxDecoration(
        color: FtColors.bgAlt,
        border: Border(
          bottom: BorderSide(color: FtColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _avatarColor(customer.name),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              _initials(customer.name),
              style: FtText.inter(size: 13, weight: FontWeight.w700, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.name, style: FtText.cardTitle),
                if (customer.address != null && customer.address!.isNotEmpty)
                  Text(customer.address!, style: FtText.helper, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            onPressed: _closePanel,
            icon: Icon(AppIcons.close, color: FtColors.fg2),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(CompanyCustomer customer) {
    final btnStyle = OutlinedButton.styleFrom(
      foregroundColor: FtColors.fg1,
      side: const BorderSide(color: FtColors.border, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: FtRadii.mdAll),
      textStyle: FtText.button,
    );

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (_canEdit)
          OutlinedButton.icon(
            onPressed: () => _editCustomer(customer),
            icon: Icon(AppIcons.edit, size: 16),
            label: const Text('Edit'),
            style: btnStyle,
          ),
        if (_canDelete)
          OutlinedButton.icon(
            onPressed: () => _deleteCustomer(customer),
            icon: Icon(AppIcons.trash, size: 16),
            label: const Text('Delete'),
            style: btnStyle.copyWith(
              foregroundColor: const WidgetStatePropertyAll(FtColors.danger),
              side: WidgetStatePropertyAll(BorderSide(color: FtColors.danger.withValues(alpha: 0.3), width: 1.5)),
            ),
          ),
      ],
    );
  }

  Future<void> _editCustomer(CompanyCustomer customer) async {
    final nameController = TextEditingController(text: customer.name);
    final addressController = TextEditingController(text: customer.address ?? '');
    final emailController = TextEditingController(text: customer.email ?? '');
    final phoneController = TextEditingController(text: customer.phone ?? '');
    final notesController = TextEditingController(text: customer.notes ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Customer'),
        content: SizedBox(
          width: 500,
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
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: FtColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
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

    final companyId = _companyId;
    if (companyId == null) return;

    try {
      final address = addressController.text.trim();
      final email = emailController.text.trim();
      final phone = phoneController.text.trim();
      final notes = notesController.text.trim();

      final updated = customer.copyWith(
        name: name,
        address: address.isEmpty ? null : address,
        email: email.isEmpty ? null : email,
        phone: phone.isEmpty ? null : phone,
        notes: notes.isEmpty ? null : notes,
        updatedAt: DateTime.now(),
      );
      await CompanyService.instance.updateCustomer(companyId, updated);
      if (mounted) context.showSuccessToast('Customer updated');
    } catch (e) {
      if (mounted) context.showErrorToast('Failed to update customer');
    }
  }

  Future<void> _deleteCustomer(CompanyCustomer customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Customer?'),
        content: Text('This will permanently delete "${customer.name}". This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: FtColors.danger, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final companyId = _companyId;
    if (companyId == null) return;

    try {
      await CompanyService.instance.deleteCustomer(companyId, customer.id);
      if (mounted) context.showSuccessToast('Customer deleted');
      _closePanel();
    } catch (e) {
      if (mounted) context.showErrorToast('Failed to delete customer');
    }
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      padding: FtSpacing.cardBody,
      decoration: FtDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: FtText.label),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: FtText.helper),
          ),
          Expanded(
            child: Text(value, style: FtText.inter(size: 13, weight: FontWeight.w500, color: FtColors.fg1)),
          ),
        ],
      ),
    );
  }

  static Color _avatarColor(String name) {
    const colors = [
      Color(0xFF6366F1),
      Color(0xFF8B5CF6),
      Color(0xFF06B6D4),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
      Color(0xFFEC4899),
      Color(0xFF3B82F6),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return '?';
  }
}
