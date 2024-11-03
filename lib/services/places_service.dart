import 'dart:convert';
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

  Future<List<Place>> searchNearbyPlaces(List<LatLng> routePoints) async {
    if (apiKey == null || apiKey!.isEmpty) {
      throw Exception('Foursquare API key not found');
    }

    Set<Place> uniquePlaces = {};
    final failedPoints = <LatLng>[];

    // 500m 간격으로 포인트 샘플링
    for (int i = 0; i < routePoints.length; i += 5) {
      final point = routePoints[i];

      try {
        print('Searching near point: ${point.latitude}, ${point.longitude}');

        final url = Uri.parse(
            'https://api.foursquare.com/v3/places/search'
                '?ll=${point.latitude},${point.longitude}'
                '&radius=500'
                '&limit=10'
                '&categories=13065,13002,13003,13032,13387,13338,13376,13338,13145'
                '&sort=RATING'
                '&min_rating=3'
                '&fields=fsq_id,name,location,categories,rating,distance,photos,geocodes'
                '&exclude_chains=false'
                '&exclude_all_chains=false'
        );

        final response = await http.get(
          url,
          headers: {
            'Authorization': apiKey!,
            'Accept': 'application/json',
          },
        );

        print('API Response status: ${response.statusCode}');
        print('API Response body: ${response.body}');

        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          final results = data['results'] as List<dynamic>?;

          if (results != null && results.isNotEmpty) {
            for (var result in results) {
              try {
                // geocodes 필드가 있다면 그것을 사용
                if (result['geocodes'] != null && result['geocodes']['main'] != null) {
                  final geocodes = result['geocodes']['main'] as Map<String, dynamic>;
                  result['location'] = {
                    'latitude': geocodes['latitude'],
                    'longitude': geocodes['longitude'],
                  };
                }

                final place = Place.fromJson(result);
                // 좌표 검증
                if (place.latitude != 0 && place.longitude != 0 &&
                    place.name.isNotEmpty && place.category.isNotEmpty) {
                  print('Adding place: ${place.name} at (${place.latitude}, ${place.longitude})');
                  uniquePlaces.add(place);
                } else {
                  print('Skipping invalid place: ${place.name}');
                  print('Coordinates: (${place.latitude}, ${place.longitude})');
                  print('Category: ${place.category}');
                }
              } catch (e, stackTrace) {
                print('Error parsing place result: $e');
                print('Stack trace: $stackTrace');
                print('Problematic result: $result');
              }
            }
            print('Found ${uniquePlaces.length} valid places near ${point.latitude}, ${point.longitude}');
          } else {
            print('No results found at point: ${point.latitude}, ${point.longitude}');
          }
        } else {
          print('API error: ${response.statusCode} - ${response.body}');
          failedPoints.add(point);
        }
      } catch (e, stackTrace) {
        print('Error searching places: $e');
        print('Stack trace: $stackTrace');
        failedPoints.add(point);
      }

      // API 호출 간 짧은 딜레이
      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (uniquePlaces.isEmpty) {
      print('No places found along the route!');
      if (failedPoints.isNotEmpty) {
        print('Failed points: ${failedPoints.map((p) => '(${p.latitude}, ${p.longitude})').join(', ')}');
      }
    } else {
      print('Total unique places found: ${uniquePlaces.length}');
      // 모든 찾은 장소의 상세 정보 출력
      uniquePlaces.forEach((place) {
        print('''
        Place: ${place.name}
        Category: ${place.category}
        Coordinates: (${place.latitude}, ${place.longitude})
        Distance: ${place.distance}m
        Rating: ${place.rating}
        Address: ${place.address}
        ''');
      });
    }

    // 거리순으로 정렬
    final sortedPlaces = uniquePlaces.toList()
      ..sort((a, b) => a.distance.compareTo(b.distance));

    return sortedPlaces;
  }
}