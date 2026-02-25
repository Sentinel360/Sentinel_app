import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'trip_service.dart';

class RouteService {
  final TripService _tripService = TripService();

  // API key loaded from environment variables
  String get _apiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  // Fetch route from Google Maps Directions API
  Future<List<GeoPoint>> fetchRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    final apiKey = _apiKey;
    if (apiKey.isEmpty) {
      throw Exception(
        'Google Maps API key not found in environment variables.',
      );
    }

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=$startLat,$startLng'
      '&destination=$endLat,$endLng'
      '&key=$apiKey',
    );

    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch route from Google Maps.');
    }

    final data = json.decode(response.body);

    if (data['status'] != 'OK') {
      throw Exception('Google Maps error: ${data['status']}');
    }

    // Decode the polyline points from the response
    final encodedPolyline = data['routes'][0]['overview_polyline']['points'];
    return _decodePolyline(encodedPolyline);
  }

  // Fetch route and save it to the trip document
  Future<void> fetchAndSaveRoute({
    required String tripId,
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    final polyline = await fetchRoute(
      startLat: startLat,
      startLng: startLng,
      endLat: endLat,
      endLng: endLng,
    );

    await _tripService.updateRoutePolyline(tripId: tripId, polyline: polyline);
  }

  // Check if a given point is within the route corridor
  bool isWithinRouteCorridor({
    required GeoPoint currentLocation,
    required List<GeoPoint> routePolyline,
    double thresholdMeters = 50,
  }) {
    if (routePolyline.isEmpty) return true;

    for (final point in routePolyline) {
      final distance = _calculateDistance(
        currentLocation.latitude,
        currentLocation.longitude,
        point.latitude,
        point.longitude,
      );
      if (distance <= thresholdMeters) return true;
    }
    return false;
  }

  // Decode Google Maps encoded polyline into GeoPoints
  List<GeoPoint> _decodePolyline(String encoded) {
    List<GeoPoint> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int shift = 0, result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(GeoPoint(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  // Calculate distance between two coordinates in meters (Haversine formula)
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000;
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    final double a =
        (dLat / 2) * (dLat / 2) +
        (dLon / 2) * (dLon / 2) * _cosApprox(lat1) * _cosApprox(lat2);
    final double c = 2 * _asinSqrt(a);
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * 3.141592653589793 / 180;

  double _cosApprox(double degrees) {
    final rad = _toRadians(degrees);
    return 1 - (rad * rad) / 2 + (rad * rad * rad * rad) / 24;
  }

  double _asinSqrt(double a) {
    final sqrtA = a < 0 ? 0.0 : (a > 1 ? 1.0 : a);
    return sqrtA +
        (sqrtA * sqrtA * sqrtA) / 6 +
        (3 * sqrtA * sqrtA * sqrtA * sqrtA * sqrtA) / 40;
  }
}
