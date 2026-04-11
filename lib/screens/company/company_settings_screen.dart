import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/company.dart';
import '../../services/company_service.dart';
import '../../models/permission.dart';
import '../../services/user_profile_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/keyboard_dismiss_wrapper.dart';
import '../../widgets/premium_toast.dart';
import '../../widgets/premium_dialog.dart';
import 'team_management_screen.dart';
import 'company_pdf_design_screen.dart';
import 'company_sites_screen.dart';
import 'company_customers_screen.dart';

class CompanySettingsScreen extends StatefulWidget {
  const CompanySettingsScreen({super.key});

  @override
  State<CompanySettingsScreen> createState() => _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends State<CompanySettingsScreen> {
  Company? _company;
  int _memberCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCompany();
  }

  Future<void> _loadCompany() async {
    final companyId = UserProfileService.instance.companyId;
    if (companyId == null) return;

    final company = await CompanyService.instance.getCompany(companyId);
    final members = await CompanyService.instance.getCompanyMembers(companyId);

    if (mounted) {
      setState(() {
        _company = company;
        _memberCount = members.length;
        _isLoading = false;
      });
    }
  }

  final _ups = UserProfileService.instance;
  bool get _canBrand => _ups.hasPermission(AppPermission.pdfBranding);
  bool get _canEditCompany => _ups.hasPermission(AppPermission.companyEdit);
  bool get _canDeleteCompany => _ups.hasPermission(AppPermission.companyDelete);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Company Settings')),
      body: KeyboardDismissWrapper(
        child: _isLoading
          ? const Center(child: AdaptiveLoadingIndicator())
          : _company == null
              ? const Center(child: Text('Company not found'))
              : ListView(
                  padding: const EdgeInsets.all(AppTheme.screenPadding),
                  children: [
                    _buildInfoSection(isDark),
                    const SizedBox(height: 24),
                    _buildInviteCodeSection(isDark),
                    const SizedBox(height: 24),
                    _buildTeamSection(isDark),
                    const SizedBox(height: 24),
                    if (_ups.hasPermission(AppPermission.sitesEdit) ||
                        _ups.hasPermission(AppPermission.customersEdit)) ...[
                      _buildSharedDataSection(isDark),
                      const SizedBox(height: 24),
                    ],
                    if (_canBrand) ...[
                      _buildPdfBrandingSection(isDark),
                      const SizedBox(height: 24),
                    ],
                    if (!_canEditCompany && !_canDeleteCompany) _buildLeaveButton(),
                    if (_canEditCompany) ...[
                      _buildEditButton(),
                      const SizedBox(height: 12),
                    ],
                    if (_canDeleteCompany) ...[
                      _buildDeleteButton(),
                    ],
                  ],
                ),
      ),
    );
  }

  Widget _buildInfoSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Company Details',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? AppTheme.darkTextSecondary : Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        _infoTile(AppIcons.building, 'Name', _company!.name),
        if (_company!.address != null)
          _infoTile(AppIcons.location, 'Address', _company!.address!),
        if (_company!.phone != null)
          _infoTile(AppIcons.call, 'Phone', _company!.phone!),
        if (_company!.email != null)
          _infoTile(AppIcons.sms, 'Email', _company!.email!),
      ],
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(value),
    );
  }

  Widget _buildInviteCodeSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Invite Code',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? AppTheme.darkTextSecondary : Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurfaceElevated : AppTheme.lightGrey,
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _company!.inviteCode ?? 'N/A',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                ),
              ),
              IconButton(
                icon: Icon(AppIcons.copy),
                onPressed: () {
                  if (_company!.inviteCode != null) {
                    Clipboard.setData(
                      ClipboardData(text: _company!.inviteCode!),
                    );
                    context.showSuccessToast('Invite code copied');
                  }
                },
              ),
              if (_ups.hasPermission(AppPermission.inviteCodeRegenerate))
                IconButton(
                  icon: Icon(AppIcons.refresh),
                  onPressed: _regenerateInviteCode,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTeamSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Team',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? AppTheme.darkTextSecondary : Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        ListTile(
          leading: Icon(AppIcons.people),
          title: const Text(
            'Team Members',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text('$_memberCount members'),
          trailing: Icon(AppIcons.arrowRight),
          onTap: () {
            Navigator.push(
              context,
              adaptivePageRoute(
                builder: (_) => const TeamManagementScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSharedDataSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Shared Data',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? AppTheme.darkTextSecondary : Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        ListTile(
          leading: Icon(AppIcons.building),
          title: const Text(
            'Shared Sites',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text('Company-wide site locations'),
          trailing: Icon(AppIcons.arrowRight),
          onTap: () {
            Navigator.push(
              context,
              adaptivePageRoute(
                builder: (_) =>
                    CompanySitesScreen(companyId: _company!.id),
              ),
            );
          },
        ),
        ListTile(
          leading: Icon(AppIcons.people),
          title: const Text(
            'Shared Customers',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text('Company-wide customer contacts'),
          trailing: Icon(AppIcons.arrowRight),
          onTap: () {
            Navigator.push(
              context,
              adaptivePageRoute(
                builder: (_) =>
                    CompanyCustomersScreen(companyId: _company!.id),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPdfBrandingSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Branding',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? AppTheme.darkTextSecondary : Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        ListTile(
          leading: Icon(AppIcons.designtools),
          title: const Text(
            'PDF Branding',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text('Customise company PDF headers, footers & colours'),
          trailing: Icon(AppIcons.arrowRight),
          onTap: () {
            Navigator.push(
              context,
              adaptivePageRoute(
                builder: (_) => CompanyPdfDesignScreen(companyId: _company!.id),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLeaveButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _confirmLeave,
        icon: Icon(AppIcons.logout),
        label: const Text('Leave Company'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildEditButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _editCompany,
        icon: Icon(AppIcons.edit),
        label: const Text('Edit Company Details'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: _confirmDelete,
        icon: Icon(AppIcons.danger),
        label: const Text('Delete Company'),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          foregroundColor: Colors.red,
        ),
      ),
    );
  }

  Future<void> _regenerateInviteCode() async {
    final confirm = await showAdaptiveAlertDialog<bool>(
      context: context,
      title: 'Regenerate Invite Code',
      message:
          'The current invite code will stop working. Anyone with the old code won\'t be able to join.',
      confirmLabel: 'Regenerate',
      cancelLabel: 'Cancel',
    );

    if (confirm != true) return;

    try {
      final newCode = await CompanyService.instance
          .regenerateInviteCode(_company!.id);
      setState(() {
        _company = _company!.copyWith(inviteCode: newCode);
      });
      if (mounted) context.showSuccessToast('New invite code generated');
    } catch (e) {
      if (mounted) context.showErrorToast('Failed to regenerate code');
    }
  }

  Future<void> _confirmLeave() async {
    final confirm = await showAdaptiveAlertDialog<bool>(
      context: context,
      title: 'Leave Company',
      message:
          'Are you sure you want to leave ${_company!.name}? You will lose access to dispatched jobs.',
      confirmLabel: 'Leave',
      cancelLabel: 'Cancel',
      isDestructive: true,
    );

    if (confirm != true) return;

    try {
      await CompanyService.instance.leaveCompany();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) context.showErrorToast('Failed to leave company');
    }
  }

  Future<void> _confirmDelete() async {
    final confirm = await showAdaptiveAlertDialog<bool>(
      context: context,
      title: 'Delete Company',
      message:
          'This will permanently delete ${_company!.name} and all its data, including dispatched jobs. All members will be removed.\n\nThis action cannot be undone.',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      isDestructive: true,
    );

    if (confirm != true) return;

    try {
      await CompanyService.instance.deleteCompany(_company!.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) context.showErrorToast('Failed to delete company');
    }
  }

  Future<void> _editCompany() async {
    final nameController = TextEditingController(text: _company!.name);
    final addressController =
        TextEditingController(text: _company!.address ?? '');
    final phoneController =
        TextEditingController(text: _company!.phone ?? '');
    final emailController =
        TextEditingController(text: _company!.email ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Company'),
        content: KeyboardDismissWrapper(
          child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                controller: nameController,
                label: 'Company Name',
                prefixIcon: Icon(AppIcons.building),
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: addressController,
                label: 'Address',
                prefixIcon: Icon(AppIcons.location),
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: phoneController,
                label: 'Phone',
                prefixIcon: Icon(AppIcons.call),
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: emailController,
                label: 'Email',
                prefixIcon: Icon(AppIcons.sms),
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
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != true) return;

    try {
      final updated = _company!.copyWith(
        name: nameController.text.trim(),
        address: addressController.text.trim().isEmpty
            ? null
            : addressController.text.trim(),
        phone: phoneController.text.trim().isEmpty
            ? null
            : phoneController.text.trim(),
        email: emailController.text.trim().isEmpty
            ? null
            : emailController.text.trim(),
      );

      await CompanyService.instance.updateCompany(updated);
      setState(() => _company = updated);
      if (mounted) context.showSuccessToast('Company updated');
    } catch (e) {
      if (mounted) context.showErrorToast('Failed to update company');
    }
  }
}
