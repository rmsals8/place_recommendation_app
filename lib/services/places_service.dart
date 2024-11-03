import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/place.dart';

class PlacesService {
  Future<List<Place>> getNearbyPlaces(double lat, double lng) async {
    final apiKey = dotenv.env['FOURSQUARE_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Foursquare API key not found');
    }

    final url = Uri.parse(
        'https://api.foursquare.com/v3/places/search?ll=$lat,$lng&radius=1000&limit=5'
    );

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': apiKey,
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('API Response: ${response.body}'); // 디버깅용

        if (data['results'] != null) {
          return (data['results'] as List)
              .map((place) => Place.fromJson(place))
              .toList();
        }
        return [];
      } else {
        print('API Error: ${response.statusCode} - ${response.body}'); // 디버깅용
        throw Exception('Failed to load places: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception in getNearbyPlaces: $e'); // 디버깅용
      throw Exception('Failed to load places: $e');
    }
  }
}