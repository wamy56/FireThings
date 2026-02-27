import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../utils/adaptive_widgets.dart';
import '../../utils/animate_helpers.dart';
import '../../utils/icon_map.dart';
import '../../utils/theme.dart';
import '../../widgets/adaptive_app_bar.dart';

class ManagePermissionsScreen extends StatefulWidget {
  const ManagePermissionsScreen({super.key});

  @override
  State<ManagePermissionsScreen> createState() =>
      _ManagePermissionsScreenState();
}

class _ManagePermissionsScreenState extends State<ManagePermissionsScreen>
    with WidgetsBindingObserver {
  final List<_PermissionInfo> _permissions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh statuses when returning from system settings
    if (state == AppLifecycleState.resumed) {
      _loadPermissions();
    }
  }

  Future<void> _loadPermissions() async {
    final cameraStatus = await Permission.camera.status;
    final micStatus = await Permission.microphone.status;
    final notifStatus = await Permission.notification.status;

    // Location uses Geolocator's own permission model
    final locPermission = await Geolocator.checkPermission();
    final locStatus = _mapLocationPermission(locPermission);

    if (!mounted) return;
    setState(() {
      _permissions
        ..clear()
        ..addAll([
          _PermissionInfo(
            name: 'Camera',
            description: 'Used by Photo Logger to take site photos',
            icon: AppIcons.camera,
            status: cameraStatus,
          ),
          _PermissionInfo(
            name: 'Microphone',
            description: 'Used by the Decibel Meter tool',
            icon: AppIcons.microphone,
            status: micStatus,
          ),
          _PermissionInfo(
            name: 'Location',
            description: 'Used by Photo Logger to tag photo locations',
            icon: AppIcons.location,
            status: locStatus,
          ),
          _PermissionInfo(
            name: 'Notifications',
            description: 'Used for draft and overdue invoice reminders',
            icon: AppIcons.notification,
            status: notifStatus,
          ),
        ]);
      _loading = false;
    });
  }

  PermissionStatus _mapLocationPermission(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return PermissionStatus.granted;
      case LocationPermission.denied:
        return PermissionStatus.denied;
      case LocationPermission.deniedForever:
        return PermissionStatus.permanentlyDenied;
      case LocationPermission.unableToDetermine:
        return PermissionStatus.denied;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const AdaptiveNavigationBar(title: 'Permissions'),
      body: _loading
          ? const Center(child: AdaptiveLoadingIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ..._permissions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final perm = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildPermissionCard(perm, isDark)
                        .animateListItem(index),
                  );
                }),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Permissions are managed through your device\'s system settings. '
                    'Tap the arrow on any permission to open settings.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textSecondary,
                    ),
                  ),
                ).animateListItem(_permissions.length),
              ],
            ),
    );
  }

  Widget _buildPermissionCard(_PermissionInfo perm, bool isDark) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(perm.icon),
        title: Text(
          perm.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(perm.description),
            const SizedBox(height: 6),
            _buildStatusChip(perm.status, isDark),
          ],
        ),
        trailing: IconButton(
          icon: Icon(AppIcons.arrowRight),
          onPressed: () => openAppSettings(),
          tooltip: 'Open settings',
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildStatusChip(PermissionStatus status, bool isDark) {
    final (label, color) = switch (status) {
      PermissionStatus.granted ||
      PermissionStatus.limited =>
        ('Granted', AppTheme.successGreen),
      PermissionStatus.denied => ('Denied', AppTheme.errorRed),
      PermissionStatus.permanentlyDenied =>
        ('Denied', AppTheme.errorRed),
      _ => ('Not Requested', isDark ? Colors.grey[400]! : Colors.grey[600]!),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _PermissionInfo {
  final String name;
  final String description;
  final IconData icon;
  final PermissionStatus status;

  const _PermissionInfo({
    required this.name,
    required this.description,
    required this.icon,
    required this.status,
  });
}
