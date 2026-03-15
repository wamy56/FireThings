import 'package:flutter/material.dart';
import '../../models/company_member.dart';
import '../../services/company_service.dart';
import '../../services/user_profile_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/premium_toast.dart';
import '../../widgets/premium_dialog.dart';

class TeamManagementScreen extends StatefulWidget {
  const TeamManagementScreen({super.key});

  @override
  State<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen> {
  bool get _isAdmin => UserProfileService.instance.isAdmin;
  String? get _companyId => UserProfileService.instance.companyId;
  String? get _currentUid => UserProfileService.instance.profile?.uid;

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
      body: StreamBuilder<List<CompanyMember>>(
        stream: CompanyService.instance.getCompanyMembersStream(companyId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: AdaptiveLoadingIndicator());
          }

          final members = snapshot.data ?? [];
          if (members.isEmpty) {
            return const Center(child: Text('No team members'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppTheme.screenPadding),
            itemCount: members.length,
            itemBuilder: (context, index) =>
                _buildMemberTile(members[index], isDark),
          );
        },
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
          if (_isAdmin && !isCurrentUser)
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
