import 'dart:convert';
import 'dart:math' show pi, sin, cos, sqrt, atan2;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/place.dart';

class PlacesService {
  final String? apiKey = dotenv.env['FOURSQUARE_API_KEY'];

  static const Map<String, String> categories = {
    '13065': '관광 명소',
    '13002': '예술/문화',
    '13003': '공원',
    '13032': '카페',
    '13387': '맛집',
    '13338': '쇼핑',
    '13376': '엔터테인먼트',
    '13145': '랜드마크',
  };

  double _calculateDistance(LatLng p1, LatLng p2) {
    const double earthRadius = 6371000;
    final lat1 = p1.latitude * (pi / 180);
    final lat2 = p2.latitude * (pi / 180);
    final dLat = (p2.latitude - p1.latitude) * (pi / 180);
    final dLng = (p2.longitude - p1.longitude) * (pi / 180);

    final a = sin(dLat/2) * sin(dLat/2) +
        cos(lat1) * cos(lat2) *
            sin(dLng/2) * sin(dLng/2);
    final c = 2 * atan2(sqrt(a), sqrt(1-a));

    return earthRadius * c;
  }

  Future<List<Place>> searchNearbyPlaces(List<LatLng> routePoints) async {
    if (apiKey == null || apiKey!.isEmpty) {
      throw Exception('Foursquare API key not found');
    }

    if (routePoints.isEmpty) {
      return [];
    }

    final startPoint = routePoints.first;
    final endPoint = routePoints.last;
    final Set<Place> uniquePlaces = {};

    print('Searching near start point: ${startPoint.latitude}, ${startPoint.longitude}');

    // 출발지 주변 검색
    final startPlaces = await _searchAtPoint(startPoint, true);
    uniquePlaces.addAll(startPlaces);
    await Future.delayed(const Duration(milliseconds: 300));

    // 도착지 주변 검색
    if (_calculateDistance(startPoint, endPoint) > 1000) {
      print('Searching near end point: ${endPoint.latitude}, ${endPoint.longitude}');
      final endPlaces = await _searchAtPoint(endPoint, false);
      uniquePlaces.addAll(endPlaces);
    }

    final sortedPlaces = uniquePlaces.toList()
      ..sort((a, b) => a.distance.compareTo(b.distance));

    print('Total places found: ${sortedPlaces.length}');
    return sortedPlaces;
  }

  Future<List<Place>> _searchAtPoint(LatLng point, bool isStart) async {
    final List<Place> places = [];

    try {
      final url = Uri.parse(
          'https://api.foursquare.com/v3/places/search'
              '?ll=${point.latitude},${point.longitude}'
              '&radius=1000'
              '&limit=15'
              '&categories=13065,13002,13003,13032,13387,13338,13376,13145'
              '&sort=RATING'
              '&min_rating=3'
              '&fields=fsq_id,name,location,categories,rating,distance,photos,geocodes'
      );

      final response = await http.get(
        url,
        headers: {
          'Authorization': apiKey!,
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List<dynamic>?;

        print('Found ${results?.length ?? 0} places at ${isStart ? "start" : "end"} point');

        if (results != null) {
          for (var result in results) {
            try {
              if (result['geocodes'] != null && result['geocodes']['main'] != null) {
                final geocodes = result['geocodes']['main'] as Map<String, dynamic>;
                result['location'] = {
                  'latitude': geocodes['latitude'],
                  'longitude': geocodes['longitude'],
                };
              }

              final place = Place.fromJson(result);
              if (_isValidPlace(place)) {
                final distanceFromPoint = place.distance;
                double adjustedDistance = isStart ?
                distanceFromPoint : // 출발지 주변 장소는 원래 거리 사용
                2000 + distanceFromPoint; // 도착지 주변 장소는 2000m를 더해서 구분

                final updatedPlace = Place(
                  id: place.id,
                  name: place.name,
                  latitude: place.latitude,
                  longitude: place.longitude,
                  address: place.address,
                  category: place.category,
                  rating: place.rating,
                  photoUrl: place.photoUrl,
                  distance: adjustedDistance,
                );

                places.add(updatedPlace);
                print('Added ${isStart ? "start" : "end"} place: ${place.name} at distance: ${adjustedDistance}m');
              }
            } catch (e) {
              print('Error parsing place: $e');
            }
          }
        }
      } else {
        print('API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error searching at point: $e');
    }

    return places;
  }

  bool _isValidPlace(Place place) {
    return place.latitude != 0 &&
        place.longitude != 0 &&
        place.name.isNotEmpty &&
        place.category.isNotEmpty;
  }
}