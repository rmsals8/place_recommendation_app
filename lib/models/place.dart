import 'package:google_maps_flutter/google_maps_flutter.dart';  // LatLng import 추가

class Place {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String address;
  final String category;
  final double rating;
  final String? photoUrl;
  final double distance;

  const Place({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.category,
    this.rating = 0.0,
    this.photoUrl,
    this.distance = 0.0,
  });

  LatLng get location => LatLng(latitude, longitude);

  factory Place.fromJson(Map<String, dynamic> json) {
    try {
      final location = json['location'] as Map<String, dynamic>? ?? {};
      print('Location data: $location');

      final lat = location['lat'] ?? location['latitude'];
      final lng = location['lng'] ?? location['longitude'];

      print('Extracted coordinates - Lat: $lat, Lng: $lng');

      if (lat == null || lng == null) {
        print('Warning: Invalid coordinates in place data: $json');
      }

      final categories = json['categories'] as List<dynamic>? ?? [];
      final firstCategory = categories.isNotEmpty ? categories.first as Map<String, dynamic> : {};

      return Place(
        id: json['fsq_id']?.toString() ?? json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        latitude: (lat is num ? lat.toDouble() : 0.0),
        longitude: (lng is num ? lng.toDouble() : 0.0),
        address: [
          location['formatted_address'],
          location['address'],
          location['neighborhood'],
          location['crossStreet'],
        ].whereType<String>().join(', '),
        category: firstCategory['name']?.toString() ?? '',
        rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
        distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      );
    } catch (e, stackTrace) {
      print('Error parsing place: $e');
      print('Stack trace: $stackTrace');
      print('Raw JSON: $json');
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Place && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Place{id: $id, name: $name, location: ($latitude, $longitude)}';
}