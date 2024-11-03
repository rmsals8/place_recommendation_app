// lib/models/place.dart
class Place {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String address;
  final String category;
  final double rating;

  Place({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.category,
    this.rating = 0.0,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    final location = json['location'] ?? {};
    final categories = json['categories'] as List<dynamic>? ?? [];

    return Place(
      id: json['fsq_id'] ?? '',  // Foursquare specific ID
      name: json['name'] ?? '',
      latitude: location['latitude']?.toDouble() ?? 0.0,
      longitude: location['longitude']?.toDouble() ?? 0.0,
      address: location['formatted_address'] ?? location['address'] ?? '',
      category: categories.isNotEmpty ? categories[0]['name'] ?? '' : '',
      rating: json['rating']?.toDouble() ?? 0.0,
    );
  }

  @override
  String toString() {
    return 'Place{id: $id, name: $name, address: $address}';
  }
}