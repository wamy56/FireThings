import '../models/asset.dart';
import '../services/service_history_service.dart';

/// Suggests which assets to test next based on quarterly rotation.
/// Returns the least-recently-tested ~25% of assets for a site.
class RotationTracker {
  RotationTracker._();

  /// Returns asset IDs sorted by least-recently-tested, limited to ~25%.
  /// Assets that have never been tested are prioritised first.
  static Future<List<String>> getSuggestedAssets({
    required String basePath,
    required String siteId,
    required List<Asset> assets,
  }) async {
    if (assets.isEmpty) return [];

    // Fetch all service records for the site in one query
    final records = await ServiceHistoryService.instance
        .getRecordsForSite(basePath, siteId)
        .first;

    // Build a map of assetId -> most recent service date
    final latestServiceByAsset = <String, DateTime>{};
    for (final record in records) {
      final existing = latestServiceByAsset[record.assetId];
      if (existing == null || record.serviceDate.isAfter(existing)) {
        latestServiceByAsset[record.assetId] = record.serviceDate;
      }
    }

    // Sort assets: never-tested first (null date), then oldest service date first
    final sorted = List<Asset>.from(assets);
    sorted.sort((a, b) {
      final dateA = latestServiceByAsset[a.id];
      final dateB = latestServiceByAsset[b.id];
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return -1;
      if (dateB == null) return 1;
      return dateA.compareTo(dateB);
    });

    // Take top 25% (ceil to always include at least 1)
    final count = (assets.length / 4).ceil();
    return sorted.take(count).map((a) => a.id).toList();
  }
}
