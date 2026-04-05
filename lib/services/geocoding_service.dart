import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

/// Shared geocoding service with in-memory cache and rate-limiting.
/// Uses Nominatim HTTP API on web, native geocoding package elsewhere.
class GeocodingService {
  static final GeocodingService instance = GeocodingService._();
  GeocodingService._();

  /// LRU cache: address → (lat, lng). Max 100 entries.
  final LinkedHashMap<String, ({double lat, double lng})> _cache =
      LinkedHashMap();
  static const _maxCacheSize = 100;

  /// Nominatim requires max 1 request/second.
  DateTime _lastRequest = DateTime.fromMillisecondsSinceEpoch(0);

  /// Geocode an address string to coordinates.
  /// Returns null if the address cannot be resolved.
  Future<({double lat, double lng})?> geocode(String address) async {
    final key = address.trim().toLowerCase();
    if (key.isEmpty) return null;

    // Check cache
    if (_cache.containsKey(key)) {
      final cached = _cache.remove(key)!;
      _cache[key] = cached; // Move to end (most recently used)
      return cached;
    }

    // Rate-limit (Nominatim 1 req/sec policy)
    await _throttle();

    try {
      ({double lat, double lng})? result;

      if (kIsWeb) {
        result = await _geocodeWeb(address);
      } else {
        result = await _geocodeNative(address);
      }

      if (result != null) {
        _cacheResult(key, result);
      }
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<({double lat, double lng})?> _geocodeWeb(String address) async {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?q=${Uri.encodeComponent(address)}&format=json&limit=1',
    );
    final response = await http.get(uri, headers: {
      'User-Agent': 'com.firethings.app',
    });
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      if (data.isNotEmpty) {
        final lat = double.parse(data.first['lat']);
        final lng = double.parse(data.first['lon']);
        return (lat: lat, lng: lng);
      }
    }
    return null;
  }

  Future<({double lat, double lng})?> _geocodeNative(String address) async {
    final locations = await locationFromAddress(address);
    if (locations.isNotEmpty) {
      return (lat: locations.first.latitude, lng: locations.first.longitude);
    }
    return null;
  }

  Future<void> _throttle() async {
    final now = DateTime.now();
    final elapsed = now.difference(_lastRequest);
    if (elapsed < const Duration(seconds: 1)) {
      await Future.delayed(const Duration(seconds: 1) - elapsed);
    }
    _lastRequest = DateTime.now();
  }

  void _cacheResult(String key, ({double lat, double lng}) result) {
    if (_cache.length >= _maxCacheSize) {
      _cache.remove(_cache.keys.first); // Evict oldest
    }
    _cache[key] = result;
  }
}
