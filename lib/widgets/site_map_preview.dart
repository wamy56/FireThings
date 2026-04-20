import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/geocoding_service.dart';
import '../utils/theme.dart';
import '../utils/icon_map.dart';

/// A small interactive map preview showing a site location with a pin marker.
/// Geocodes the address if lat/lng are not provided.
class SiteMapPreview extends StatefulWidget {
  final String address;
  final double? latitude;
  final double? longitude;
  final double height;
  final VoidCallback? onTap;

  const SiteMapPreview({
    super.key,
    required this.address,
    this.latitude,
    this.longitude,
    this.height = 180,
    this.onTap,
  });

  @override
  State<SiteMapPreview> createState() => _SiteMapPreviewState();
}

class _SiteMapPreviewState extends State<SiteMapPreview> {
  LatLng? _location;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _resolveLocation();
  }

  @override
  void didUpdateWidget(SiteMapPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.address != widget.address ||
        oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      _resolveLocation();
    }
  }

  Future<void> _resolveLocation() async {
    setState(() {
      _loading = true;
      _error = false;
    });

    // Use provided coordinates if available
    if (widget.latitude != null && widget.longitude != null) {
      setState(() {
        _location = LatLng(widget.latitude!, widget.longitude!);
        _loading = false;
      });
      return;
    }

    // Geocode the address via shared service
    final result = await GeocodingService.instance.geocode(widget.address);
    if (!mounted) return;

    if (result != null) {
      setState(() {
        _location = LatLng(result.lat, result.lng);
        _loading = false;
      });
    } else {
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppTheme.darkDivider : AppTheme.lightGrey,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: _loading
            ? _buildLoading(isDark)
            : _error || _location == null
                ? _buildError(isDark)
                : _buildMap(),
      ),
    );
  }

  Widget _buildLoading(bool isDark) {
    return Container(
      color: isDark ? AppTheme.darkSurfaceElevated : AppTheme.backgroundGrey,
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildError(bool isDark) {
    return Container(
      color: isDark ? AppTheme.darkSurfaceElevated : AppTheme.backgroundGrey,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.location,
              size: 28,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
            ),
            const SizedBox(height: 6),
            Text(
              'Map unavailable',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    return AbsorbPointer(
      child: FlutterMap(
        options: MapOptions(
          initialCenter: _location!,
          initialZoom: 15,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.firethings.app',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: _location!,
                width: 40,
                height: 40,
                child: Icon(
                  Icons.location_pin,
                  color: AppTheme.errorRed,
                  size: 40,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
