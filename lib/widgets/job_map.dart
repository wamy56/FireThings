import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../utils/theme.dart';

/// Data for a single pin on the job map.
class JobMapPin {
  final String jobId;
  final LatLng location;
  final Color color;
  final String title;
  final String? engineerName;
  final String? scheduledTime;
  final String? statusLabel;
  final int? sequenceNumber;

  const JobMapPin({
    required this.jobId,
    required this.location,
    required this.color,
    required this.title,
    this.engineerName,
    this.scheduledTime,
    this.statusLabel,
    this.sequenceNumber,
  });
}

/// A multi-marker interactive map for displaying job locations.
/// Supports optional route polyline and pin tap callbacks.
class JobMap extends StatefulWidget {
  final List<JobMapPin> pins;
  final List<LatLng>? routePoints;
  final void Function(String jobId)? onPinTap;
  final int missingLocationCount;

  const JobMap({
    super.key,
    required this.pins,
    this.routePoints,
    this.onPinTap,
    this.missingLocationCount = 0,
  });

  @override
  State<JobMap> createState() => _JobMapState();
}

class _JobMapState extends State<JobMap> {
  final MapController _mapController = MapController();
  String? _selectedPinId;

  @override
  void didUpdateWidget(JobMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pins.length != oldWidget.pins.length) {
      _selectedPinId = null;
      _fitBounds();
    }
  }

  void _fitBounds() {
    if (widget.pins.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.pins.length == 1) {
        _mapController.move(widget.pins.first.location, 15);
      } else {
        final bounds = LatLngBounds.fromPoints(
          widget.pins.map((p) => p.location).toList(),
        );
        _mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.pins.isEmpty) {
      return _buildEmptyState(isDark);
    }

    final initialCenter =
        widget.pins.length == 1 ? widget.pins.first.location : widget.pins.first.location;
    final selectedPin = _selectedPinId != null
        ? widget.pins.where((p) => p.jobId == _selectedPinId).firstOrNull
        : null;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: widget.pins.length == 1 ? 15 : 10,
            onTap: (tapPos, latLng) => setState(() => _selectedPinId = null),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.firethings.app',
            ),
            if (widget.routePoints != null && widget.routePoints!.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: widget.routePoints!,
                    color: AppTheme.primaryBlue.withValues(alpha: 0.7),
                    strokeWidth: 3,
                    pattern: const StrokePattern.dotted(),
                  ),
                ],
              ),
            MarkerLayer(
              markers: widget.pins.map((pin) => _buildMarker(pin)).toList(),
            ),
          ],
        ),
        // Missing location chip
        if (widget.missingLocationCount > 0)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Text(
                '${widget.missingLocationCount} job${widget.missingLocationCount == 1 ? '' : 's'} without location',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
                ),
              ),
            ),
          ),
        // Pin popup card
        if (selectedPin != null)
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: _buildPopupCard(selectedPin, isDark),
          ),
      ],
    );
  }

  Marker _buildMarker(JobMapPin pin) {
    final isSelected = _selectedPinId == pin.jobId;
    final size = isSelected ? 36.0 : 28.0;

    return Marker(
      point: pin.location,
      width: size,
      height: size,
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedPinId = pin.jobId);
          widget.onPinTap?.call(pin.jobId);
        },
        child: Container(
          decoration: BoxDecoration(
            color: pin.color,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: isSelected ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: pin.sequenceNumber != null
              ? Text(
                  '${pin.sequenceNumber}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildPopupCard(JobMapPin pin, bool isDark) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 48,
              decoration: BoxDecoration(
                color: pin.color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    pin.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isDark ? Colors.white : AppTheme.darkGrey,
                    ),
                  ),
                  if (pin.engineerName != null || pin.scheduledTime != null)
                    Text(
                      [
                        if (pin.engineerName != null) pin.engineerName!,
                        if (pin.scheduledTime != null) pin.scheduledTime!,
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.mediumGrey,
                      ),
                    ),
                  if (pin.statusLabel != null)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: pin.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        pin.statusLabel!,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: pin.color,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                widget.onPinTap?.call(pin.jobId);
              },
              child: const Text('View Details', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      color: isDark ? AppTheme.darkSurface : AppTheme.backgroundGrey,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.map_outlined,
              size: 40,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
            ),
            const SizedBox(height: 8),
            Text(
              'No jobs with locations for this period',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
