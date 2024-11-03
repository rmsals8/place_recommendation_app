// lib/config/env.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Environment {
  static String get googleMapsApiKey {
    return dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  }

  static String get foursquareApiKey {
    return dotenv.env['FOURSQUARE_API_KEY'] ?? '';
  }
}