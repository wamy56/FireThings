import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../utils/icon_map.dart';
import '../../widgets/premium_toast.dart';
import '../../widgets/adaptive_app_bar.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/keyboard_dismiss_wrapper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isEditingName = false;
  bool _isEditingEmail = false;
  bool _isChangingPassword = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    final user = _authService.currentUser;
    _nameController = TextEditingController(
      text: user?.displayName ?? '',
    );
    _emailController = TextEditingController(
      text: user?.email ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    return Scaffold(
      appBar: AdaptiveNavigationBar(
        title: 'Profile Settings',
      ),
      body: KeyboardDismissWrapper(
        child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Avatar
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Theme.of(context).primaryColor,
                    child: Text(
                      _getInitial(),
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user?.displayName ?? user?.email?.split('@')[0] ?? 'Engineer',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    user?.email ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Personal Information Section
            _buildSectionHeader('Personal Information'),
            const SizedBox(height: 12),
            _buildNameField(),
            const SizedBox(height: 24),

            // Email Section
            _buildSectionHeader('Email Address'),
            const SizedBox(height: 12),
            _buildEmailField(),
            const SizedBox(height: 24),

            // Password Section
            _buildSectionHeader('Password'),
            const SizedBox(height: 12),
            _buildPasswordSection(),
            const SizedBox(height: 32),

            // Account Info
            _buildSectionHeader('Account Information'),
            const SizedBox(height: 12),
            _buildInfoCard(
              'Account Created',
              user?.metadata.creationTime != null
                  ? _formatDate(user!.metadata.creationTime!)
                  : 'Unknown',
              AppIcons.calendar,
            ),
            const SizedBox(height: 8),
            _buildInfoCard(
              'Last Sign In',
              user?.metadata.lastSignInTime != null
                  ? _formatDate(user!.metadata.lastSignInTime!)
                  : 'Unknown',
              AppIcons.clock,
            ),
            const SizedBox(height: 8),
            _buildInfoCard(
              'User ID',
              user?.uid ?? 'Unknown',
              AppIcons.profileCircle,
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.grey[600],
      ),
    );
  }

  Widget _buildNameField() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Display Name',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                if (!_isEditingName)
                  TextButton(
                    onPressed: () => setState(() => _isEditingName = true),
                    child: const Text('Edit'),
                  ),
              ],
            ),
            if (_isEditingName) ...[
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'Enter your name',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isEditingName = false;
                        _nameController.text =
                            _authService.currentUser?.displayName ?? '';
                      });
                    },
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _updateName,
                    child: _isLoading
                        ? const AdaptiveLoadingIndicator(size: 20)
                        : const Text('Save'),
                  ),
                ],
              ),
            ] else ...[
              Text(
                _authService.currentUser?.displayName ?? 'Not set',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Email',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                if (!_isEditingEmail)
                  TextButton(
                    onPressed: () => setState(() => _isEditingEmail = true),
                    child: const Text('Change'),
                  ),
              ],
            ),
            if (_isEditingEmail) ...[
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  hintText: 'Enter new email',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
                ),
              const SizedBox(height: 8),
              Text(
                'A verification email will be sent to your new address.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isEditingEmail = false;
                        _emailController.text =
                            _authService.currentUser?.email ?? '';
                      });
                    },
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _updateEmail,
                    child: _isLoading
                        ? const AdaptiveLoadingIndicator(size: 20)
                        : const Text('Update'),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _authService.currentUser?.email ?? 'Not set',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (_authService.currentUser?.emailVerified == true)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            AppIcons.tickCircleBold,
                            size: 14,
                            color: Colors.green,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Verified',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Password',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                if (!_isChangingPassword)
                  TextButton(
                    onPressed: () => setState(() => _isChangingPassword = true),
                    child: const Text('Change'),
                  ),
              ],
            ),
            if (_isChangingPassword) ...[
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _currentPasswordController,
                      obscureText: _obscureCurrentPassword,
                      textInputAction: TextInputAction.done,
                              decoration: InputDecoration(
                        labelText: 'Current Password',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureCurrentPassword
                                ? AppIcons.eye
                                : AppIcons.eyeSlash,
                          ),
                          onPressed: () => setState(
                            () => _obscureCurrentPassword =
                                !_obscureCurrentPassword,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your current password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: _obscureNewPassword,
                      textInputAction: TextInputAction.done,
                              decoration: InputDecoration(
                        labelText: 'New Password',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureNewPassword
                                ? AppIcons.eye
                                : AppIcons.eyeSlash,
                          ),
                          onPressed: () => setState(
                            () => _obscureNewPassword = !_obscureNewPassword,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a new password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      textInputAction: TextInputAction.done,
                              decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? AppIcons.eye
                                : AppIcons.eyeSlash,
                          ),
                          onPressed: () => setState(
                            () => _obscureConfirmPassword =
                                !_obscureConfirmPassword,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value != _newPasswordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isChangingPassword = false;
                        _currentPasswordController.clear();
                        _newPasswordController.clear();
                        _confirmPasswordController.clear();
                      });
                    },
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _changePassword,
                    child: _isLoading
                        ? const AdaptiveLoadingIndicator(size: 20)
                        : const Text('Update Password'),
                  ),
                ],
              ),
            ] else ...[
              const Text(
                '••••••••••••',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Colors.grey[600]),
        title: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String _getInitial() {
    final user = _authService.currentUser;
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      return user.displayName!.substring(0, 1).toUpperCase();
    } else if (user?.email != null && user!.email!.isNotEmpty) {
      return user.email!.substring(0, 1).toUpperCase();
    }
    return 'E';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _updateName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      context.showErrorToast('Please enter a name');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.updateDisplayName(newName);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isEditingName = false;
      });

      context.showSuccessToast('Name updated successfully');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      context.showErrorToast('Error updating name: $e');
    }
  }

  Future<void> _updateEmail() async {
    final newEmail = _emailController.text.trim();
    if (newEmail.isEmpty || !newEmail.contains('@')) {
      context.showErrorToast('Please enter a valid email');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.updateEmail(newEmail);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isEditingEmail = false;
      });

      context.showSuccessToast('Verification email sent to your new address');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      context.showErrorToast('$e');
    }
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Re-authenticate first (required for password change)
      final email = _authService.currentUser?.email;
      if (email != null) {
        await _authService.signIn(
          email: email,
          password: _currentPasswordController.text,
        );
      }

      // Update password
      await _authService.updatePassword(_newPasswordController.text);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isChangingPassword = false;
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      });

      context.showSuccessToast('Password updated successfully');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      context.showErrorToast('$e');
    }
  }
}
