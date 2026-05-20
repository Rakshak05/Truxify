import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Lightweight geocoding helper using Nominatim (OpenStreetMap).
class GeocodeService {
  GeocodeService._();

  static final Map<String, LatLng?> _cache = <String, LatLng?>{};

  /// Resolve a place name to a LatLng. Returns null if resolution failed.
  static Future<LatLng?> resolvePlace(String query) async {
    final key = query.trim().toLowerCase();
    if (key.isEmpty) return null;
    if (_cache.containsKey(key)) return _cache[key];

    final uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/search',
      <String, String>{'q': query, 'format': 'jsonv2', 'limit': '1'},
    );

    try {
      final resp = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) {
        _cache[key] = null;
        return null;
      }

      final decoded = jsonDecode(resp.body) as List<dynamic>?;
      if (decoded == null || decoded.isEmpty) {
        _cache[key] = null;
        return null;
      }

      final item = decoded.first as Map<String, dynamic>;
      final lat = double.tryParse('${item['lat']}');
      final lon = double.tryParse('${item['lon']}');
      if (lat == null || lon == null) {
        _cache[key] = null;
        return null;
      }

      final ll = LatLng(lat, lon);
      _cache[key] = ll;
      return ll;
    } catch (_) {
      _cache[key] = null;
      return null;
    }
  }
}
