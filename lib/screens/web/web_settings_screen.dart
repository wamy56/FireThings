import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../services/auth_service.dart';
import '../../services/user_profile_service.dart';
import '../../theme/web_theme.dart';
import '../../utils/icon_map.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/premium_toast.dart';
import '../settings/privacy_policy_screen.dart';

class WebSettingsScreen extends StatefulWidget {
  const WebSettingsScreen({super.key});

  @override
  State<WebSettingsScreen> createState() => _WebSettingsScreenState();
}

class _WebSettingsScreenState extends State<WebSettingsScreen> {
  final _nameController = TextEditingController();
  final _authService = AuthService();
  String _appVersion = '';
  bool _isEditingName = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _nameController.text = user?.displayName ?? '';
    _loadVersion();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _appVersion = '${info.version}+${info.buildNumber}');
  }

  Future<void> _updateName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    try {
      await _authService.updateDisplayName(newName);
      if (mounted) {
        setState(() => _isEditingName = false);
        context.showSuccessToast('Name updated');
      }
    } catch (e) {
      if (mounted) context.showErrorToast('Failed to update name');
    }
  }

  Future<void> _resetPassword() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) return;

    try {
      await _authService.resetPassword(email);
      if (mounted) {
        context.showSuccessToast('Password reset email sent to $email');
      }
    } catch (e) {
      if (mounted) context.showErrorToast('Failed to send reset email');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final profile = UserProfileService.instance;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Settings', style: FtText.sectionTitle),
              const SizedBox(height: 24),

              _buildSectionCard('Profile', [
                ListTile(
                  leading: Icon(AppIcons.user),
                  title: _isEditingName
                      ? Row(
                          children: [
                            Expanded(
                              child: CustomTextField(
                                controller: _nameController,
                                label: 'Display Name',
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _updateName,
                              icon: Icon(AppIcons.tickCircle, color: FtColors.success),
                            ),
                            IconButton(
                              onPressed: () => setState(() => _isEditingName = false),
                              icon: Icon(AppIcons.close, color: FtColors.fg2),
                            ),
                          ],
                        )
                      : Text(user?.displayName ?? 'No name set'),
                  subtitle: _isEditingName ? null : const Text('Display Name'),
                  trailing: _isEditingName
                      ? null
                      : IconButton(
                          onPressed: () => setState(() => _isEditingName = true),
                          icon: Icon(AppIcons.edit, size: 18),
                        ),
                ),
                ListTile(
                  leading: Icon(AppIcons.sms),
                  title: Text(user?.email ?? ''),
                  subtitle: const Text('Email'),
                ),
                ListTile(
                  leading: Icon(AppIcons.lock),
                  title: const Text('Reset Password'),
                  subtitle: const Text('Send a password reset email'),
                  trailing: Icon(AppIcons.arrowRight, size: 18),
                  onTap: _resetPassword,
                ),
              ]),
              const SizedBox(height: 16),

              if (profile.hasCompany)
                ...[
                  _buildSectionCard('Company', [
                    ListTile(
                      leading: Icon(AppIcons.building),
                      title: Text(profile.companyId ?? 'Unknown'),
                      subtitle: const Text('Company ID'),
                    ),
                    ListTile(
                      leading: Icon(AppIcons.crown),
                      title: Text(profile.companyRole?.name ?? 'Unknown'),
                      subtitle: const Text('Your Role'),
                    ),
                  ]),
                  const SizedBox(height: 16),
                ],

              _buildSectionCard('About', [
                ListTile(
                  leading: Icon(AppIcons.infoCircle),
                  title: Text('FireThings v$_appVersion'),
                  subtitle: const Text('Version'),
                ),
                ListTile(
                  leading: Icon(AppIcons.shield),
                  title: const Text('Privacy Policy'),
                  subtitle: const Text('View privacy policy'),
                  trailing: Icon(AppIcons.arrowRight, size: 18),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyScreen(),
                      ),
                    );
                  },
                ),
              ]),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  icon: Icon(AppIcons.logout),
                  label: const Text('Sign Out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FtColors.danger,
                    side: BorderSide(color: FtColors.danger.withValues(alpha: 0.3), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: FtRadii.mdAll),
                    textStyle: FtText.button,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Container(
      decoration: FtDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(title.toUpperCase(), style: FtText.label),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
