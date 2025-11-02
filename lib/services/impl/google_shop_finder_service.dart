// ...existing code...
import 'dart:convert';
import 'dart:math';
import 'package:e_repairkit/models/location.dart';
import 'package:e_repairkit/models/shop.dart';
import 'package:e_repairkit/services/findshop_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GoogleShopFinderService implements ShopFinderService {
  final String _apiKey = dotenv.env['PLACES_API_KEY']!;
  // Use the Text Search endpoint but keep the same variable name
  final String _baseUrl = 'https://maps.googleapis.com/maps/api/place/textsearch/json';

  @override
  Future<List<Shop>> findNearby(Location location) async {
    final query = Uri.encodeQueryComponent('electronics repair');
    final uri = Uri.parse('$_baseUrl?query=$query&location=${location.latitude},${location.longitude}&radius=5000&key=$_apiKey');

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final status = data['status'] as String? ?? 'UNKNOWN';
        if (status != 'OK' && status != 'ZERO_RESULTS') {
          print('Places API Error: $data');
          throw Exception('Failed to load shops');
        }
        final List places = data['results'] ?? [];
        return places.map((place) => _convertFromGoogle(place as Map<String, dynamic>, location)).toList();
      } else {
        print('Places API Error: ${response.body}');
        throw Exception('Failed to load shops');
      }
    } catch (e) {
      print('Error in shop finder: $e');
      throw Exception('Failed to find shops: $e');
    }
  }

  // Helper to convert Google's format to our simple 'Shop' model
  Shop _convertFromGoogle(Map<String, dynamic> place, Location userLocation) {
    final geometry = place['geometry'] as Map<String, dynamic>?;
    final loc = geometry?['location'] as Map<String, dynamic>?;
    final lat = (loc?['lat'] as num?)?.toDouble() ?? 0.0;
    final lng = (loc?['lng'] as num?)?.toDouble() ?? 0.0;
    final distanceKm = _distanceKm(userLocation.latitude, userLocation.longitude, lat, lng);

    return Shop(
      id: place['place_id'] ?? 'unknown_id',
      name: place['name'] ?? 'Unknown Shop',
      distance: double.parse(distanceKm.toStringAsFixed(2)),
    );
  }

  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0; // Earth radius km
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * (pi / 180.0);
}
// ...existing code...
