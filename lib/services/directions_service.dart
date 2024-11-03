import 'dart:convert';
import 'dart:math' show pi, sin, cos, sqrt, atan2;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import '../models/route_info.dart';  // RouteInfo 클래스 import

class DirectionsService {
  final String? apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
  final PolylinePoints polylinePoints = PolylinePoints();

  Future<List<RouteInfo>> getRoutes(LatLng origin, LatLng destination) async {
    if (apiKey == null) throw Exception('Google Maps API key not found');

    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?'
            'origin=${origin.latitude},${origin.longitude}'
            '&destination=${destination.latitude},${destination.longitude}'
            '&alternatives=true'
            '&mode=driving'
            '&language=ko'
            '&key=$apiKey'
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'ZERO_RESULTS') {
          return [_createStraightRoute(origin, destination)];
        }

        if (data['status'] != 'OK') {
          throw Exception('Directions API error: ${data['status']}');
        }

        final routes = data['routes'] as List;
        if (routes.isEmpty) {
          return [_createStraightRoute(origin, destination)];
        }

        return routes.map((route) {
          final points = polylinePoints
              .decodePolyline(route['overview_polyline']['points'])
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();

          final leg = route['legs'][0];

          return RouteInfo(
            points: points,
            distance: leg['distance']['text'],
            duration: leg['duration']['text'],
            samplePoints: _getSamplePoints(points),
          );
        }).toList();
      }

      throw Exception('Failed to fetch directions: ${response.statusCode}');
    } catch (e) {
      print('Error in getRoutes: $e');
      return [_createStraightRoute(origin, destination)];
    }
  }

  RouteInfo _createStraightRoute(LatLng origin, LatLng destination) {
    final points = _createSmoothPath(origin, destination);
    final distance = _calculateDistance(origin, destination);
    final durationInMinutes = (distance / 1000 / 40 * 60).round();

    return RouteInfo(
      points: points,
      distance: '${(distance / 1000).toStringAsFixed(1)} km',
      duration: '$durationInMinutes분',
      samplePoints: _getSamplePoints(points),
    );
  }

  List<LatLng> _createSmoothPath(LatLng start, LatLng end) {
    const segments = 10;
    List<LatLng> points = [];

    for (int i = 0; i <= segments; i++) {
      double fraction = i / segments;
      points.add(LatLng(
        start.latitude + (end.latitude - start.latitude) * fraction,
        start.longitude + (end.longitude - start.longitude) * fraction,
      ));
    }

    return points;
  }

  List<LatLng> _getSamplePoints(List<LatLng> points) {
    if (points.length <= 2) return points;

    List<LatLng> samples = [];
    int step = (points.length / 5).round();

    for (int i = 0; i < points.length; i += step) {
      samples.add(points[i]);
    }

    if (!samples.contains(points.last)) {
      samples.add(points.last);
    }

    return samples;
  }

  double _calculateDistance(LatLng p1, LatLng p2) {
    const earthRadius = 6371000.0;
    final lat1 = p1.latitude * pi / 180;
    final lat2 = p2.latitude * pi / 180;
    final dLat = (p2.latitude - p1.latitude) * pi / 180;
    final dLng = (p2.longitude - p1.longitude) * pi / 180;

    final a = sin(dLat/2) * sin(dLat/2) +
        cos(lat1) * cos(lat2) *
            sin(dLng/2) * sin(dLng/2);
    final c = 2 * atan2(sqrt(a), sqrt(1-a));

    return earthRadius * c;
  }
}