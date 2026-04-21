import 'package:flutter/material.dart';
import '../../models/company_member.dart';
import '../../models/permission.dart';
import '../../services/company_service.dart';
import '../../services/user_profile_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../widgets/premium_toast.dart';
import '../../widgets/premium_dialog.dart';

class MemberPermissionsScreen extends StatefulWidget {
  final String companyId;
  final CompanyMember member;

  const MemberPermissionsScreen({
    super.key,
    required this.companyId,
    required this.member,
  });

  @override
  State<MemberPermissionsScreen> createState() =>
      _MemberPermissionsScreenState();
}

class _MemberPermissionsScreenState extends State<MemberPermissionsScreen> {
  late CompanyRole _selectedRole;
  late Map<String, bool> _permissions;
  bool _isSaving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.member.role;
    _permissions = Map<String, bool>.from(widget.member.permissions);
  }

  bool get _isEditingSelf =>
      widget.member.uid == UserProfileService.instance.profile?.uid;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Permissions'),
        actions: [
          if (_hasChanges)
            TextButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(AppIcons.tickCircle),
              label: const Text('Save'),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 750),
          child: ListView(
            padding: const EdgeInsets.all(AppTheme.screenPadding),
            children: [
              _buildMemberHeader(isDark),
              const SizedBox(height: 24),
              _buildRoleSection(isDark),
              const SizedBox(height: 24),
              ...AppPermission.categories.map(
                (category) => _buildCategorySection(category, isDark),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
            child: Text(
              widget.member.displayName.isNotEmpty
                  ? widget.member.displayName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                color: AppTheme.primaryBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.member.displayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  widget.member.email,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.mediumGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Role',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? AppTheme.darkTextSecondary : Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite,
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            boxShadow: AppTheme.cardShadow,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<CompanyRole>(
              value: _selectedRole,
              isExpanded: true,
              items: CompanyRole.values.map((role) {
                return DropdownMenuItem(
                  value: role,
                  child: Text(_roleLabel(role)),
                );
              }).toList(),
              onChanged: _isEditingSelf ? null : _onRoleChanged,
            ),
          ),
        ),
        if (_isEditingSelf)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'You cannot change your own role',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppTheme.darkTextSecondary : Colors.grey,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCategorySection(String category, bool isDark) {
    final perms = AppPermission.forCategory(category);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            category,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.darkTextSecondary : Colors.grey,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite,
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: perms.asMap().entries.map((entry) {
              final perm = entry.value;
              final isLast = entry.key == perms.length - 1;
              final enabled = _permissions[perm.key] ?? false;
              final isProtected = _isEditingSelf &&
                  perm == AppPermission.teamManage;

              return Column(
                children: [
                  SwitchListTile(
                    title: Text(
                      perm.label,
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: isProtected
                        ? const Text(
                            'Cannot remove your own team management',
                            style: TextStyle(fontSize: 11),
                          )
                        : perm.description != null
                            ? Text(
                                perm.description!,
                                style: const TextStyle(fontSize: 11),
                              )
                            : null,
                    value: _selectedRole == CompanyRole.admin ? true : enabled,
                    onChanged: _selectedRole == CompanyRole.admin || isProtected
                        ? null
                        : (val) {
                            setState(() {
                              _permissions[perm.key] = val;
                              _hasChanges = true;
                            });
                          },
                    activeTrackColor: (isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue).withValues(alpha: 0.5),
                    activeThumbColor: isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue,
                  ),
                  if (!isLast)
                    Divider(height: 1, indent: 16, endIndent: 16),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Future<void> _onRoleChanged(CompanyRole? newRole) async {
    if (newRole == null || newRole == _selectedRole) return;

    final applyDefaults = await showAdaptiveAlertDialog<bool>(
      context: context,
      title: 'Change Role',
      message:
          'Change to ${_roleLabel(newRole)}?\n\nApply default permissions for this role, or keep current custom permissions?',
      confirmLabel: 'Apply Defaults',
      cancelLabel: 'Keep Current',
    );

    setState(() {
      _selectedRole = newRole;
      if (applyDefaults == true) {
        _permissions = AppPermission.defaultsForRole(newRole);
      }
      _hasChanges = true;
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    try {
      final roleChanged = _selectedRole != widget.member.role;

      if (roleChanged) {
        await CompanyService.instance.updateMemberRole(
          widget.companyId,
          widget.member.uid,
          _selectedRole,
        );
      }

      final permsChanged = roleChanged
          ? !_mapsEqual(_permissions, AppPermission.defaultsForRole(_selectedRole))
          : !_mapsEqual(_permissions, widget.member.permissions);
      if (permsChanged) {
        await CompanyService.instance.updateMemberPermissions(
          widget.companyId,
          widget.member.uid,
          _permissions,
        );
      }

      if (mounted) {
        context.showSuccessToast('Permissions saved');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        context.showErrorToast('Failed to save permissions');
      }
    }
  }

  bool _mapsEqual(Map<String, bool> a, Map<String, bool> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }

  String _roleLabel(CompanyRole role) {
    switch (role) {
      case CompanyRole.admin:
        return 'Admin';
      case CompanyRole.dispatcher:
        return 'Dispatcher';
      case CompanyRole.engineer:
        return 'Engineer';
    }
  }
}
