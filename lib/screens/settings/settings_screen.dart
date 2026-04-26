import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/database_helper.dart';
import '../../services/firestore_sync_service.dart';
import '../../widgets/adaptive_app_bar.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/premium_toast.dart';
import '../../widgets/responsive_scaffold.dart';
import '../../utils/icon_map.dart';
import '../../utils/theme.dart';
import '../../utils/theme_style.dart';
import '../../utils/animate_helpers.dart';
import '../../utils/adaptive_widgets.dart';
import '../saved_sites/saved_sites_screen.dart';
import '../saved_customers/saved_customers_screen.dart';
import '../../services/email_service.dart';
import '../../services/remote_config_service.dart';
import '../../models/permission.dart';
import '../../services/user_profile_service.dart';
import '../debug/debug_screen.dart';
import '../company/create_company_screen.dart';
import '../company/join_company_screen.dart';
import '../company/company_settings_screen.dart';
import '../company/team_management_screen.dart';
import 'profile_screen.dart';
import 'privacy_policy_screen.dart';
import 'manage_permissions_screen.dart';
import '../bs5839/competency_screen.dart';
import 'branding/personal_branding_screen.dart';
import '../../widgets/premium_dialog.dart';
import '../../widgets/tools_disclaimer_gate.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _debugTapCount = 0;
  bool _draftReminders = true;
  bool _overdueReminders = true;
  String _appVersion = '';
  DateTime? _lastSyncTime;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationPrefs();
    _loadAppVersion();
    _loadLastSyncTime();
    UserProfileService.instance.addListener(_onProfileChanged);
  }

  void _onProfileChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    UserProfileService.instance.removeListener(_onProfileChanged);
    super.dispose();
  }

  Future<void> _loadLastSyncTime() async {
    final time = await FirestoreSyncService.instance.getLastSyncTime();
    if (mounted) setState(() => _lastSyncTime = time);
  }

  Future<void> _manualSync() async {
    final authService = AuthService();
    final uid = authService.userId;
    if (uid == null) return;

    setState(() => _isSyncing = true);
    await FirestoreSyncService.instance.performFullSync(uid);
    await _loadLastSyncTime();
    if (mounted) setState(() => _isSyncing = false);
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() => _appVersion = 'Version ${info.version} (${info.buildNumber})');
  }

  Future<void> _loadNotificationPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _draftReminders = prefs.getBool('notif_draft_reminders') ?? true;
      _overdueReminders = prefs.getBool('notif_overdue_reminders') ?? true;
    });
  }

  Future<void> _setDraftReminders(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_draft_reminders', value);
    setState(() => _draftReminders = value);
  }

  Future<void> _setOverdueReminders(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_overdue_reminders', value);
    setState(() => _overdueReminders = value);
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final user = authService.currentUser;

    // Safely get first letter for avatar
    String getInitial() {
      if (user?.displayName != null && user!.displayName!.isNotEmpty) {
        return user.displayName!.substring(0, 1).toUpperCase();
      } else if (user?.email != null && user!.email!.isNotEmpty) {
        return user.email!.substring(0, 1).toUpperCase();
      }
      return 'E'; // Default to 'E' for Engineer
    }

    final isApple = PlatformUtils.isApple;

    return Scaffold(
      appBar: AdaptiveNavigationBar(title: 'Settings'),
      body: ResponsiveListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Text(
                    getInitial(),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ??
                            user?.email?.split('@')[0] ??
                            'Engineer',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? 'No email',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animateEntrance(),
          const SizedBox(height: 24),

          // Account Section
          _buildAdaptiveSection(
            context,
            header: 'Account',
            isApple: isApple,
            tiles: [
              _SettingsTileData(
                title: 'Profile',
                subtitle: 'Manage your profile information',
                icon: AppIcons.user,
                onTap: () {
                  Navigator.push(
                    context,
                    adaptivePageRoute(builder: (_) => const ProfileScreen()),
                  );
                },
              ),
              if (RemoteConfigService.instance.bs5839CompetencyTrackingEnabled)
                _SettingsTileData(
                  title: 'Competency Record',
                  subtitle: 'Qualifications & CPD hours',
                  icon: AppIcons.medal,
                  onTap: () {
                    Navigator.push(
                      context,
                      adaptivePageRoute(
                          builder: (_) => const CompetencyScreen()),
                    );
                  },
                ),
              _SettingsTileData(
                title: 'Saved Sites',
                subtitle: 'Manage frequently visited locations',
                icon: AppIcons.location,
                onTap: () {
                  Navigator.push(
                    context,
                    adaptivePageRoute(builder: (_) => const SavedSitesScreen()),
                  );
                },
              ),
              _SettingsTileData(
                title: 'Saved Customers',
                subtitle: 'Manage customers for quick invoicing',
                icon: AppIcons.people,
                onTap: () {
                  Navigator.push(
                    context,
                    adaptivePageRoute(builder: (_) => const SavedCustomersScreen()),
                  );
                },
              ),
            ],
          ).animateEntrance(delay: const Duration(milliseconds: 80)),
          const SizedBox(height: 24),

          // Appearance Section
          _buildAdaptiveSection(
            context,
            header: 'Appearance',
            isApple: isApple,
            tiles: [
              _SettingsTileData(
                title: 'Theme',
                subtitle: themeStyleNotifier.value == ThemeStyle.siteOps
                    ? 'SiteOps'
                    : 'Classic',
                icon: AppIcons.colorSwatch,
                onTap: () => _showThemeStyleSelector(context),
              ),
            ],
          ).animateEntrance(delay: const Duration(milliseconds: 120)),
          const SizedBox(height: 24),

          // PDF Settings Section
          _buildAdaptiveSection(
            context,
            header: 'PDF Settings',
            isApple: isApple,
            tiles: [
              if (!UserProfileService.instance.hasCompany)
                _SettingsTileData(
                  title: 'Personal Branding',
                  subtitle: 'Customise your logo, colours and cover style',
                  icon: AppIcons.brush,
                  onTap: () {
                    Navigator.push(
                      context,
                      adaptivePageRoute(
                        builder: (_) => const PersonalBrandingScreen(),
                      ),
                    );
                  },
                ),
            ],
          ).animateEntrance(delay: const Duration(milliseconds: 200)),
          const SizedBox(height: 24),

          // Notifications Section
          _buildAdaptiveNotificationsSection(context, isApple: isApple)
              .animateEntrance(delay: const Duration(milliseconds: 280)),
          const SizedBox(height: 24),

          // Data Section
          _buildAdaptiveSection(
            context,
            header: 'Data',
            isApple: isApple,
            tiles: [
              _SettingsTileData(
                title: 'Clear Local Data',
                subtitle: 'Choose what data to remove',
                icon: AppIcons.trash,
                onTap: () => _showClearDataActionSheet(context),
                destructive: true,
              ),
            ],
          ).animateEntrance(delay: const Duration(milliseconds: 320)),
          const SizedBox(height: 24),

          // Cloud Sync Section
          _buildAdaptiveSection(
            context,
            header: 'Cloud Sync',
            isApple: isApple,
            tiles: [
              _SettingsTileData(
                title: 'Sync Now',
                subtitle: _isSyncing
                    ? 'Syncing...'
                    : _lastSyncTime != null
                        ? 'Last synced ${DateFormat.yMMMd().add_jm().format(_lastSyncTime!)}'
                        : 'Never synced',
                icon: AppIcons.refresh,
                onTap: _isSyncing ? () {} : () => _manualSync(),
              ),
            ],
          ).animateEntrance(delay: const Duration(milliseconds: 360)),
          const SizedBox(height: 24),

          // Company Section (dispatch feature)
          if (RemoteConfigService.instance.dispatchEnabled)
            _buildCompanySection(isApple)
                .animateEntrance(delay: const Duration(milliseconds: 380)),
          if (RemoteConfigService.instance.dispatchEnabled)
            const SizedBox(height: 24),

          // App Section
          _buildAdaptiveSection(
            context,
            header: 'App',
            isApple: isApple,
            tiles: [
              _SettingsTileData(
                title: 'Permissions',
                subtitle: 'Manage app permissions',
                icon: AppIcons.shield,
                onTap: () => Navigator.push(
                  context,
                  adaptivePageRoute(
                      builder: (_) => const ManagePermissionsScreen()),
                ),
              ),
              _SettingsTileData(
                title: 'Privacy Policy',
                subtitle: 'How we handle your data',
                icon: AppIcons.lock,
                onTap: () => Navigator.push(
                  context,
                  adaptivePageRoute(builder: (_) => const PrivacyPolicyScreen()),
                ),
              ),
              _SettingsTileData(
                title: 'Tools Disclaimer',
                subtitle: 'View safety tools disclaimer',
                icon: AppIcons.warning,
                onTap: () => ToolsDisclaimerGate.showDisclaimerReadOnly(context),
              ),
              _SettingsTileData(
                title: 'About',
                subtitle: _appVersion.isEmpty ? 'Version ...' : _appVersion,
                icon: AppIcons.infoCircle,
                onTap: () => _showAboutDialog(context),
              ),
              _SettingsTileData(
                title: 'Send Feedback',
                subtitle: 'Report a bug or suggest a feature',
                icon: AppIcons.messageQuestion,
                onTap: () => _sendFeedback(),
              ),
            ],
          ).animateEntrance(delay: const Duration(milliseconds: 400)),
          const SizedBox(height: 24),

          // Debug access - Tap version text 5 times to access
          GestureDetector(
            onTap: () {
              setState(() {
                _debugTapCount++;
              });

              if (_debugTapCount >= 5) {
                setState(() {
                  _debugTapCount = 0;
                });

                Navigator.push(
                  context,
                  adaptivePageRoute(builder: (_) => const DebugScreen()),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  _appVersion.isEmpty ? 'Version ...' : _appVersion,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Logout Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showLogoutDialog(context, authService),
              icon: Icon(AppIcons.logout),
              label: const Text('Logout'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Delete Account Button
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => _showDeleteAccountDialog(context, authService),
              icon: Icon(AppIcons.danger),
              label: const Text('Delete Account'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                foregroundColor: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdaptiveSection(
    BuildContext context, {
    required String header,
    required bool isApple,
    required List<_SettingsTileData> tiles,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          header,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? AppTheme.darkTextSecondary : Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        ...tiles.map((tile) => ListTile(
            leading: Icon(tile.icon, color: tile.destructive ? Colors.red : null),
            title: Text(
              tile.title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: tile.destructive ? Colors.red : null,
              ),
            ),
            subtitle: Text(tile.subtitle),
            trailing: Icon(AppIcons.arrowRight),
            onTap: tile.onTap,
        )),
      ],
    );
  }

  Widget _buildAdaptiveNotificationsSection(BuildContext context, {required bool isApple}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notifications',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? AppTheme.darkTextSecondary : Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          secondary: Icon(AppIcons.editNote),
          title: const Text(
            'Draft reminders',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text('Remind about idle draft invoices & jobsheets'),
          value: _draftReminders,
          onChanged: _setDraftReminders,
        ),
        SwitchListTile(
          secondary: Icon(AppIcons.receiptOutline),
          title: const Text(
            'Overdue invoice reminders',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text('Remind about unpaid invoices past due date'),
          value: _overdueReminders,
          onChanged: _setOverdueReminders,
        ),
      ],
    );
  }

  Widget _buildCompanySection(bool isApple) {
    final profile = UserProfileService.instance;

    if (!profile.hasCompany) {
      return _buildAdaptiveSection(
        context,
        header: 'Company',
        isApple: isApple,
        tiles: [
          _SettingsTileData(
            title: 'Create Company',
            subtitle: 'Set up your own company',
            icon: AppIcons.building,
            onTap: () async {
              final result = await Navigator.push<bool>(
                context,
                adaptivePageRoute(builder: (_) => const CreateCompanyScreen()),
              );
              if (result == true && mounted) setState(() {});
            },
          ),
          _SettingsTileData(
            title: 'Join Company',
            subtitle: 'Join with an invite code',
            icon: AppIcons.userAdd,
            onTap: () async {
              final result = await Navigator.push<bool>(
                context,
                adaptivePageRoute(builder: (_) => const JoinCompanyScreen()),
              );
              if (result == true && mounted) setState(() {});
            },
          ),
        ],
      );
    }

    final roleName = profile.companyRole?.name ?? 'member';
    final roleLabel = roleName[0].toUpperCase() + roleName.substring(1);

    final tiles = <_SettingsTileData>[
      _SettingsTileData(
        title: 'Company Settings',
        subtitle: 'View company details and invite code',
        icon: AppIcons.building,
        onTap: () async {
          final result = await Navigator.push<bool>(
            context,
            adaptivePageRoute(builder: (_) => const CompanySettingsScreen()),
          );
          if (result == true && mounted) setState(() {});
        },
      ),
    ];

    tiles.add(_SettingsTileData(
      title: 'Team',
      subtitle: profile.hasPermission(AppPermission.teamManage)
          ? 'Manage team members'
          : 'View team members',
      icon: AppIcons.people,
      onTap: () {
        Navigator.push(
          context,
          adaptivePageRoute(builder: (_) => const TeamManagementScreen()),
        );
      },
    ));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAdaptiveSection(
          context,
          header: 'Company — $roleLabel',
          isApple: isApple,
          tiles: tiles,
        ),
      ],
    );
  }

  void _showThemeStyleSelector(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final current = themeStyleNotifier.value;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose theme',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _buildThemeOption(
                context: ctx,
                title: 'Classic',
                subtitle: 'Blue & coral, light and dark modes',
                isSelected: current == ThemeStyle.classic,
                accentColor: const Color(0xFF1E3A5F),
                onTap: () {
                  Navigator.pop(ctx);
                  themeStyleNotifier.value = ThemeStyle.classic;
                  saveThemeStylePreference(ThemeStyle.classic);
                  setState(() {});
                },
              ),
              const SizedBox(height: 8),
              _buildThemeOption(
                context: ctx,
                title: 'SiteOps',
                subtitle: 'Dark instrument panel, amber accent',
                isSelected: current == ThemeStyle.siteOps,
                accentColor: const Color(0xFFFFB020),
                onTap: () {
                  Navigator.pop(ctx);
                  themeStyleNotifier.value = ThemeStyle.siteOps;
                  saveThemeStylePreference(ThemeStyle.siteOps);
                  setState(() {});
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool isSelected,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? accentColor : (isDark ? AppTheme.darkDivider : AppTheme.dividerColor),
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? accentColor.withValues(alpha: 0.08)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLogoutDialog(
    BuildContext context,
    AuthService authService,
  ) async {
    final confirm = await showAdaptiveAlertDialog<bool>(
      context: context,
      title: 'Logout',
      message: 'Are you sure you want to logout?',
      confirmLabel: 'Logout',
      cancelLabel: 'Cancel',
      isDestructive: true,
    );

    if (confirm == true) {
      await authService.signOut();
    }
  }

  Future<void> _showDeleteAccountDialog(
    BuildContext context,
    AuthService authService,
  ) async {
    // Step 1: Confirmation
    final confirm = await showAdaptiveAlertDialog<bool>(
      context: context,
      title: 'Delete Account',
      message: 'This will permanently delete your account and all associated data, including jobsheets, invoices, customers, sites, and templates.\n\nThis action cannot be undone.',
      confirmLabel: 'Continue',
      cancelLabel: 'Cancel',
      isDestructive: true,
    );

    if (confirm != true || !context.mounted) return;

    // Step 2: Password prompt
    final passwordController = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please enter your password to confirm account deletion.'),
            const SizedBox(height: 16),
            PasswordTextField(
              controller: passwordController,
              label: 'Password',
              hint: 'Enter your password',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(passwordController.text),
            child: const Text(
              'Delete Account',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (password == null || password.isEmpty || !context.mounted) return;

    // Step 3: Deletion sequence with loading overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: AdaptiveLoadingIndicator()),
      ),
    );

    try {
      await authService.reauthenticate(password);
      await FirestoreSyncService.instance.deleteAllUserData();
      await DatabaseHelper.instance.deleteAllData();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await authService.deleteAccount();
      // Auth state change will redirect to login screen
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // dismiss loading
        context.showErrorToast(e.toString());
      }
    }
  }

  Future<void> _showClearDataActionSheet(BuildContext context) async {
    final dbHelper = DatabaseHelper.instance;

    await showAdaptiveActionSheet(
      context: context,
      title: 'Clear Local Data',
      message: 'Choose what data to remove',
      options: [
        ActionSheetOption(
          label: 'Delete All Local Data',
          icon: AppIcons.trash,
          isDestructive: true,
          onTap: () => _confirmAndDelete(
            context,
            title: 'Delete All Local Data',
            message: 'This will permanently delete all jobsheets, invoices, customers, sites, and templates from this device.\n\nThis cannot be undone.',
            onDelete: () => dbHelper.deleteAllData(),
            successMessage: 'All local data deleted',
          ),
        ),
        ActionSheetOption(
          label: 'Delete All Jobsheets',
          icon: AppIcons.clipboard,
          isDestructive: true,
          onTap: () => _confirmAndDelete(
            context,
            title: 'Delete All Jobsheets',
            message: 'This will permanently delete all jobsheets from this device.\n\nThis cannot be undone.',
            onDelete: () => dbHelper.deleteAllJobsheets(),
            successMessage: 'All jobsheets deleted',
          ),
        ),
        ActionSheetOption(
          label: 'Delete All Invoices',
          icon: AppIcons.receipt,
          isDestructive: true,
          onTap: () => _confirmAndDelete(
            context,
            title: 'Delete All Invoices',
            message: 'This will permanently delete all invoices from this device.\n\nThis cannot be undone.',
            onDelete: () => dbHelper.deleteAllInvoices(),
            successMessage: 'All invoices deleted',
          ),
        ),
        ActionSheetOption(
          label: 'Delete Saved Customers',
          icon: AppIcons.people,
          isDestructive: true,
          onTap: () => _confirmAndDelete(
            context,
            title: 'Delete Saved Customers',
            message: 'This will permanently delete all saved customers from this device.\n\nThis cannot be undone.',
            onDelete: () => dbHelper.deleteAllSavedCustomers(),
            successMessage: 'All saved customers deleted',
          ),
        ),
        ActionSheetOption(
          label: 'Delete Saved Sites',
          icon: AppIcons.location,
          isDestructive: true,
          onTap: () => _confirmAndDelete(
            context,
            title: 'Delete Saved Sites',
            message: 'This will permanently delete all saved sites from this device.\n\nThis cannot be undone.',
            onDelete: () => dbHelper.deleteAllSavedSites(),
            successMessage: 'All saved sites deleted',
          ),
        ),
      ],
    );
  }

  Future<void> _confirmAndDelete(
    BuildContext context, {
    required String title,
    required String message,
    required Future<dynamic> Function() onDelete,
    required String successMessage,
  }) async {
    final confirm = await showAdaptiveAlertDialog<bool>(
      context: context,
      title: title,
      message: message,
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      isDestructive: true,
    );

    if (confirm == true && context.mounted) {
      await onDelete();

      if (!context.mounted) return;
      context.showWarningToast(successMessage);
    }
  }

  Future<void> _sendFeedback() async {
    try {
      await EmailService.sendFeedback();
    } catch (e) {
      if (mounted) {
        context.showErrorToast(
          'Could not open email client. Send feedback manually to cscott93@hotmail.co.uk',
        );
      }
    }
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'FireThings',
      applicationVersion: _appVersion,
      applicationIcon: Image.asset('assets/images/firethings_logo_vertical_centered.png', height: 64),
      children: const [
        Text('Fire alarm helper and jobsheet system for field engineers.'),
        SizedBox(height: 16),
        Text('© 2026 FireThings'),
      ],
    );
  }
}

class _SettingsTileData {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;

  const _SettingsTileData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.destructive = false,
  });
}
