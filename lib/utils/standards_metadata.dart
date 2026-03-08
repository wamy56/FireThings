class ToolStandardInfo {
  final String standardRef;
  final String lastReviewed;
  final String dataVersion;
  final String scope;

  const ToolStandardInfo({
    required this.standardRef,
    required this.lastReviewed,
    required this.dataVersion,
    required this.scope,
  });
}

class StandardsMetadata {
  StandardsMetadata._();

  static const String localDataVersion = '08/03/2026';

  static const Map<String, ToolStandardInfo> tools = {
    'bs5839_reference': ToolStandardInfo(
      standardRef: 'BS 5839-1:2025',
      lastReviewed: '2026-03-08',
      dataVersion: '08/03/2026',
      scope: 'Fire detection and fire alarm systems for buildings. '
          'System categories, detector spacing, sounders, call points, '
          'cables, testing & maintenance.',
    ),
    'detector_spacing': ToolStandardInfo(
      standardRef: 'BS 5839-1:2025',
      lastReviewed: '2026-03-08',
      dataVersion: '08/03/2026',
      scope: 'Detector spacing and coverage calculations based on '
          'Table 4 (point detectors) of BS 5839-1.',
    ),
    'battery_load_test': ToolStandardInfo(
      standardRef: 'BS 5839-1:2025 (Annex E)',
      lastReviewed: '2026-03-08',
      dataVersion: '08/03/2026',
      scope: 'Battery capacity calculations for standby and alarm '
          'current draw per BS 5839-1 requirements.',
    ),
    'decibel_meter': ToolStandardInfo(
      standardRef: 'BS 5839-1:2025',
      lastReviewed: '2026-03-08',
      dataVersion: '08/03/2026',
      scope: 'Sound level reference values for fire alarm sounder '
          'compliance (65 dB at bedhead, 120 dB max at 1m).',
    ),
  };
}
