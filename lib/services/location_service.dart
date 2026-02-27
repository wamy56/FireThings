import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

/// Singleton service for GPS tracking + reverse geocoding with throttling.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  StreamSubscription<Position>? _positionSubscription;
  Timer? _geocodeTimer;

  String? _currentCoords;
  String? _currentAddress;
  double? _latitude;
  double? _longitude;

  String? get currentCoords => _currentCoords;
  String? get currentAddress => _currentAddress;
  double? get latitude => _latitude;
  double? get longitude => _longitude;

  bool _isTracking = false;
  bool get isTracking => _isTracking;

  /// Start listening to GPS updates (throttled to ~5s) and reverse geocoding (~10s).
  Future<bool> startTracking() async {
    if (_isTracking) return true;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return false;
      }
      if (permission == LocationPermission.deniedForever) return false;

      // Get initial position
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
        _updatePosition(position);
      } catch (e) {
        debugPrint('LocationService: initial position error: $e');
      }

      // Stream updates throttled to 5 seconds / 10 metres
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
          timeLimit: Duration(seconds: 30),
        ),
      ).listen(
        _updatePosition,
        onError: (e) => debugPrint('LocationService: stream error: $e'),
      );

      // Reverse geocode every 10 seconds
      _geocodeTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _reverseGeocode(),
      );

      // Do initial geocode
      _reverseGeocode();

      _isTracking = true;
      return true;
    } catch (e) {
      debugPrint('LocationService: startTracking error: $e');
      return false;
    }
  }

  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _geocodeTimer?.cancel();
    _geocodeTimer = null;
    _isTracking = false;
  }

  void _updatePosition(Position position) {
    _latitude = position.latitude;
    _longitude = position.longitude;
    _currentCoords =
        '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
  }

  Future<void> _reverseGeocode() async {
    if (_latitude == null || _longitude == null) return;
    try {
      final placemarks = await placemarkFromCoordinates(
        _latitude!,
        _longitude!,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = <String>[
          if (p.street != null && p.street!.isNotEmpty) p.street!,
          if (p.locality != null && p.locality!.isNotEmpty) p.locality!,
          if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty)
            p.administrativeArea!,
        ];
        _currentAddress = parts.isNotEmpty ? parts.join(', ') : null;
      }
    } catch (e) {
      debugPrint('LocationService: geocode error: $e');
    }
  }
}
