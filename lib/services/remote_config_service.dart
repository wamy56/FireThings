import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class RemoteConfigService {
  RemoteConfigService._();
  static final RemoteConfigService instance = RemoteConfigService._();

  final _remoteConfig = FirebaseRemoteConfig.instance;

  static const _defaults = <String, dynamic>{
    'timestamp_camera_enabled': true,
    'decibel_meter_enabled': true,
    'dip_switch_calculator_enabled': true,
    'detector_spacing_enabled': true,
    'battery_load_tester_enabled': true,
    'bs5839_reference_enabled': true,
    'invoicing_enabled': true,
    'pdf_forms_enabled': true,
    'cloud_sync_enabled': true,
    'custom_templates_enabled': true,
    'standards_data_version': '08/03/2026',
    'dispatch_enabled': false,
    'dispatch_max_members': 25,
    'dispatch_notifications_enabled': true,
    'asset_register_enabled': false,
    'barcode_scanning_enabled': false,
    'lifecycle_tracking_enabled': false,
    'compliance_report_enabled': false,
    'quoting_enabled': false,
  };

  Future<void> initialize() async {
    try {
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(minutes: 1),
          minimumFetchInterval: kDebugMode
              ? const Duration(minutes: 1)
              : const Duration(hours: 12),
        ),
      );
      await _remoteConfig.setDefaults(_defaults);
      await _remoteConfig.fetchAndActivate();
    } catch (e) {
      debugPrint('Remote Config initialization failed: $e');
    }
  }

  /// Re-fetch Remote Config after login.
  /// Must be called after the user is authenticated.
  Future<void> refreshForUser(String? email) async {
    try {
      await _remoteConfig.fetchAndActivate();
    } catch (e) {
      debugPrint('Remote Config refresh failed: $e');
    }
  }

  bool get timestampCameraEnabled =>
      _remoteConfig.getBool('timestamp_camera_enabled');

  bool get decibelMeterEnabled =>
      _remoteConfig.getBool('decibel_meter_enabled');

  bool get dipSwitchCalculatorEnabled =>
      _remoteConfig.getBool('dip_switch_calculator_enabled');

  bool get detectorSpacingEnabled =>
      _remoteConfig.getBool('detector_spacing_enabled');

  bool get batteryLoadTesterEnabled =>
      _remoteConfig.getBool('battery_load_tester_enabled');

  bool get bs5839ReferenceEnabled =>
      _remoteConfig.getBool('bs5839_reference_enabled');

  bool get invoicingEnabled => _remoteConfig.getBool('invoicing_enabled');

  bool get pdfFormsEnabled => _remoteConfig.getBool('pdf_forms_enabled');

  bool get cloudSyncEnabled => _remoteConfig.getBool('cloud_sync_enabled');

  bool get customTemplatesEnabled =>
      _remoteConfig.getBool('custom_templates_enabled');

  String get standardsDataVersion =>
      _remoteConfig.getString('standards_data_version');

  bool get dispatchEnabled => _remoteConfig.getBool('dispatch_enabled');

  int get dispatchMaxMembers => _remoteConfig.getInt('dispatch_max_members');

  bool get dispatchNotificationsEnabled =>
      _remoteConfig.getBool('dispatch_notifications_enabled');

  bool get assetRegisterEnabled =>
      _remoteConfig.getBool('asset_register_enabled');

  bool get barcodeScanningEnabled =>
      _remoteConfig.getBool('barcode_scanning_enabled');

  bool get lifecycleTrackingEnabled =>
      _remoteConfig.getBool('lifecycle_tracking_enabled');

  bool get complianceReportEnabled =>
      _remoteConfig.getBool('compliance_report_enabled');

  bool get quotingEnabled => _remoteConfig.getBool('quoting_enabled');
}
