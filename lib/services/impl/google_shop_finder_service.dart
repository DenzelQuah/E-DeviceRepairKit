import 'dart:convert';
import 'package:e_repairkit/models/location.dart';
import 'package:e_repairkit/models/shop.dart';
import 'package:e_repairkit/services/findshop_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GoogleShopFinderService implements ShopFinderService {
  final String _apiKey = dotenv.env['PLACES_API_KEY']!;
  final String _baseUrl = 'https://places.googleapis.com/v1/places:searchNearby';

  @override
  Future<List<Shop>> findNearby(Location location) async {
    final Uri uri = Uri.parse(_baseUrl);

    // This is the JSON data we send to Google
    final requestBody = {
      "includedTypes": ["electronics_store", "store"],
      "maxResultCount": 10,
      "locationRestriction": {
        "circle": {
          "center": {
            "latitude": location.latitude,
            "longitude": location.longitude
          },
          "radius": 5000.0 // 5km radius
        }
      },
      // We add a text query to focus on repairs
      "textQuery": "electronics repair"
    };

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey,
          // This tells Google which fields to return (saves money)
          'X-Goog-FieldMask': 'places.displayName,places.id,places.location',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List places = data['places'] ?? [];
        return places.map((place) => _convertFromGoogle(place)).toList();
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
  Shop _convertFromGoogle(Map<String, dynamic> place) {
    return Shop(
      id: place['id'] ?? 'unknown_id',
      name: place['displayName']?['text'] ?? 'Unknown Shop',
      // The Places API doesn't return distance, 
      // so we just use 0.0 for now.
      distance: 0.0, 
    );
  }
}