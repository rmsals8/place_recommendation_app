import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteInfo {
  final List<LatLng> points;
  final String distance;
  final String duration;
  final List<LatLng> samplePoints;

  RouteInfo({
    required this.points,
    required this.distance,
    required this.duration,
    required this.samplePoints,
  });
}