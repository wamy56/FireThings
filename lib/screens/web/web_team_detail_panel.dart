import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/company_member.dart';
import '../../models/permission.dart';
import '../../services/company_service.dart';
import '../../services/user_profile_service.dart';
import '../../theme/web_theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/premium_toast.dart';
import '../company/member_permissions_screen.dart';
import 'dashboard/team_helpers.dart';

class WebTeamDetailPanel extends StatefulWidget {
  final String memberId;
  final VoidCallback onClose;
  final bool animateIn;

  const WebTeamDetailPanel({
    super.key,
    required this.memberId,
    required this.onClose,
    this.animateIn = true,
  });

  @override
  State<WebTeamDetailPanel> createState() => _WebTeamDetailPanelState();
}

class _WebTeamDetailPanelState extends State<WebTeamDetailPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;

  String? get _companyId => UserProfileService.instance.companyId;
  String? get _currentUid => UserProfileService.instance.profile?.uid;
  bool get _canManageTeam => UserProfileService.instance.hasPermission(AppPermission.teamManage);

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
        child: StreamBuilder<List<CompanyMember>>(
          stream: CompanyService.instance.getCompanyMembersStream(companyId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: AdaptiveLoadingIndicator());
            }

            final members = snapshot.data ?? [];
            final member = members.cast<CompanyMember?>().firstWhere(
              (m) => m!.uid == widget.memberId,
              orElse: () => null,
            );

            if (member == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(AppIcons.warning, size: 32, color: FtColors.hint),
                    const SizedBox(height: 8),
                    Text('Member not found', style: FtText.bodySoft),
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

            final isCurrentUser = member.uid == _currentUid;

            return Column(
              children: [
                _buildPanelHeader(member, isCurrentUser),
                Expanded(
                  child: ListView(
                    padding: FtSpacing.cardBody,
                    children: [
                      _buildSection('Member Details', [
                        _detailRow('Name', member.displayName),
                        _detailRow('Email', member.email),
                        _detailRow('Role', roleLabel(member.role)),
                        _detailRow('Joined', DateFormat('dd MMM yyyy').format(member.joinedAt)),
                        _detailRow('Status', member.isActive ? 'Active' : 'Inactive'),
                      ]),
                      const SizedBox(height: 16),
                      _buildPermissionsSection(member),
                      if (_canManageTeam && !isCurrentUser) ...[
                        const SizedBox(height: 24),
                        _buildActionButtons(member),
                      ],
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

  Widget _buildPanelHeader(CompanyMember member, bool isCurrentUser) {
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
              color: roleSoftColor(member.role),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              member.displayName.isNotEmpty ? member.displayName[0].toUpperCase() : '?',
              style: FtText.inter(size: 14, weight: FontWeight.w700, color: roleColor(member.role)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(member.displayName, style: FtText.cardTitle)),
                    if (isCurrentUser)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: FtColors.accentSoft,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('You', style: FtText.inter(size: 10, weight: FontWeight.w600, color: FtColors.accentHover)),
                        ),
                      ),
                  ],
                ),
                Text(member.email, style: FtText.helper),
              ],
            ),
          ),
          roleBadge(member.role),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _closePanel,
            icon: Icon(AppIcons.close, color: FtColors.fg2),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsSection(CompanyMember member) {
    final categories = AppPermission.categories;

    return Container(
      padding: FtSpacing.cardBody,
      decoration: FtDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PERMISSIONS', style: FtText.label),
          const SizedBox(height: 12),
          if (member.role == CompanyRole.admin)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: FtColors.warningSoft,
                borderRadius: FtRadii.smAll,
              ),
              child: Row(
                children: [
                  Icon(AppIcons.shield, size: 14, color: FtColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Admins have full access to all features',
                      style: FtText.inter(size: 12, weight: FontWeight.w500, color: FtColors.fg1),
                    ),
                  ),
                ],
              ),
            )
          else
            ...categories.map((category) {
              final perms = AppPermission.forCategory(category);
              final enabledCount = perms.where((p) => member.hasPermission(p)).length;
              if (enabledCount == 0) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          category,
                          style: FtText.inter(size: 12, weight: FontWeight.w600, color: FtColors.fg1),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$enabledCount/${perms.length}',
                          style: FtText.inter(size: 11, weight: FontWeight.w500, color: FtColors.hint),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: perms.where((p) => member.hasPermission(p)).map((p) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: FtColors.successSoft,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            p.label,
                            style: FtText.inter(size: 11, weight: FontWeight.w500, color: FtColors.success),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildActionButtons(CompanyMember member) {
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
        OutlinedButton.icon(
          onPressed: () => _changeRole(member),
          icon: Icon(AppIcons.user, size: 16),
          label: const Text('Change Role'),
          style: btnStyle,
        ),
        OutlinedButton.icon(
          onPressed: () => _editPermissions(member),
          icon: Icon(AppIcons.shield, size: 16),
          label: const Text('Edit Permissions'),
          style: btnStyle,
        ),
        OutlinedButton.icon(
          onPressed: () => _removeMember(member),
          icon: Icon(AppIcons.trash, size: 16),
          label: const Text('Remove'),
          style: btnStyle.copyWith(
            foregroundColor: const WidgetStatePropertyAll(FtColors.danger),
            side: WidgetStatePropertyAll(BorderSide(color: FtColors.danger.withValues(alpha: 0.3), width: 1.5)),
          ),
        ),
      ],
    );
  }

  Future<void> _changeRole(CompanyMember member) async {
    final newRole = await showDialog<CompanyRole>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Role'),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: CompanyRole.values.map((role) {
              final isSelected = role == member.role;
              return ListTile(
                leading: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: roleSoftColor(role),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    roleLabel(role)[0],
                    style: FtText.inter(size: 12, weight: FontWeight.w700, color: roleColor(role)),
                  ),
                ),
                title: Text(roleLabel(role)),
                trailing: isSelected ? Icon(AppIcons.tickCircle, color: FtColors.success, size: 18) : null,
                onTap: () => Navigator.of(ctx).pop(role),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (newRole == null || newRole == member.role) return;

    final companyId = _companyId;
    if (companyId == null) return;

    try {
      await CompanyService.instance.updateMemberRole(companyId, member.uid, newRole);
      if (mounted) {
        context.showSuccessToast('${member.displayName} is now a ${roleLabel(newRole)}');
      }
    } on LastAdminException catch (e) {
      if (mounted) context.showErrorToast(e.message);
    } catch (e) {
      if (mounted) context.showErrorToast('Failed to change role');
    }
  }

  Future<void> _editPermissions(CompanyMember member) async {
    final companyId = _companyId;
    if (companyId == null) return;

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
  }

  Future<void> _removeMember(CompanyMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Member?'),
        content: Text(
          'Remove ${member.displayName} from the company? They will lose access to dispatched jobs.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: FtColors.danger, foregroundColor: Colors.white),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final companyId = _companyId;
    if (companyId == null) return;

    try {
      await CompanyService.instance.removeMember(companyId, member.uid);
      if (mounted) {
        context.showSuccessToast('${member.displayName} removed');
        _closePanel();
      }
    } on SelfRemovalException catch (e) {
      if (mounted) context.showErrorToast(e.message);
    } on LastAdminException catch (e) {
      if (mounted) context.showErrorToast(e.message);
    } catch (e) {
      if (mounted) context.showErrorToast('Failed to remove member');
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
}
