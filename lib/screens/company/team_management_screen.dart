import 'package:flutter/material.dart';
import '../../models/company_member.dart';
import '../../models/permission.dart';
import '../../services/company_service.dart';
import '../../services/user_profile_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/premium_toast.dart';
import '../../widgets/premium_dialog.dart';
import 'member_permissions_screen.dart';

class TeamManagementScreen extends StatefulWidget {
  const TeamManagementScreen({super.key});

  @override
  State<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  bool get _canManageTeam => UserProfileService.instance.hasPermission(AppPermission.teamManage);
  String? get _companyId => UserProfileService.instance.companyId;
  String? get _currentUid => UserProfileService.instance.profile?.uid;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final companyId = _companyId;

    if (companyId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Team')),
        body: const Center(child: Text('No company found')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Team')),
      body: Center(
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
                hintText: 'Search members...',
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
            child: StreamBuilder<List<CompanyMember>>(
              stream: CompanyService.instance.getCompanyMembersStream(companyId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: AdaptiveLoadingIndicator());
                }

                final members = snapshot.data ?? [];
                final filtered = _searchQuery.isEmpty
                    ? members
                    : members.where((m) {
                        final q = _searchQuery.toLowerCase();
                        return m.displayName.toLowerCase().contains(q) ||
                            m.email.toLowerCase().contains(q);
                      }).toList();

                // Count label + list
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Text(
                            '${filtered.length} member${filtered.length == 1 ? '' : 's'}',
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
                                        : AppIcons.people,
                                    size: 64,
                                    color: isDark
                                        ? AppTheme.darkTextSecondary
                                        : AppTheme.mediumGrey,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'No Results Found'
                                        : 'No team members',
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
                                  ],
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(AppTheme.screenPadding),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) =>
                                  _buildMemberTile(filtered[index], isDark),
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
      ),
    );
  }

  Widget _buildMemberTile(CompanyMember member, bool isDark) {
    final isCurrentUser = member.uid == _currentUid;
    final roleColor = _roleColor(member.role);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: roleColor.withValues(alpha: 0.15),
        child: Text(
          member.displayName.isNotEmpty
              ? member.displayName[0].toUpperCase()
              : '?',
          style: TextStyle(
            color: roleColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        '${member.displayName}${isCurrentUser ? ' (You)' : ''}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(member.email),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _roleLabel(member.role),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: roleColor,
              ),
            ),
          ),
          if (_canManageTeam && !isCurrentUser)
            PopupMenuButton<String>(
              icon: Icon(AppIcons.more),
              onSelected: (action) =>
                  _handleMemberAction(action, member),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'change_role',
                  child: Text('Change Role'),
                ),
                const PopupMenuItem(
                  value: 'edit_permissions',
                  child: Text('Edit Permissions'),
                ),
                const PopupMenuItem(
                  value: 'remove',
                  child: Text(
                    'Remove',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Color _roleColor(CompanyRole role) {
    switch (role) {
      case CompanyRole.admin:
        return Colors.orange;
      case CompanyRole.dispatcher:
        return Colors.blue;
      case CompanyRole.engineer:
        return AppTheme.successGreen;
    }
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

  Future<void> _handleMemberAction(
    String action,
    CompanyMember member,
  ) async {
    final companyId = _companyId;
    if (companyId == null) return;

    if (action == 'change_role') {
      final newRole = await showDialog<CompanyRole>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Change Role'),
          children: CompanyRole.values.map((role) {
            return SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(role),
              child: Text(_roleLabel(role)),
            );
          }).toList(),
        ),
      );

      if (newRole == null || newRole == member.role) return;

      try {
        await CompanyService.instance.updateMemberRole(
          companyId,
          member.uid,
          newRole,
        );
        if (mounted) {
          context.showSuccessToast(
            '${member.displayName} is now a ${_roleLabel(newRole)}',
          );
        }
      } catch (e) {
        if (mounted) context.showErrorToast('Failed to change role');
      }
    } else if (action == 'edit_permissions') {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => MemberPermissionsScreen(
            companyId: companyId,
            member: member,
          ),
        ),
      );
      if (result == true && mounted) setState(() {});
    } else if (action == 'remove') {
      final confirm = await showAdaptiveAlertDialog<bool>(
        context: context,
        title: 'Remove Member',
        message:
            'Remove ${member.displayName} from the company? They will lose access to dispatched jobs.',
        confirmLabel: 'Remove',
        cancelLabel: 'Cancel',
        isDestructive: true,
      );

      if (confirm != true) return;

      try {
        await CompanyService.instance.removeMember(companyId, member.uid);
        if (mounted) {
          context.showSuccessToast('${member.displayName} removed');
        }
      } catch (e) {
        if (mounted) context.showErrorToast('Failed to remove member');
      }
    }
  }
}
