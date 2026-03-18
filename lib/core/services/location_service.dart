import 'dart:math';
import 'package:geolocator/geolocator.dart';
import '../constants/uniandes_buildings.dart';

/// Service that handles GPS location and maps it to nearby campus buildings.
class LocationService {
  /// Maximum distance (in metres) to consider a building "nearby".
  static const double nearbyRadiusMetres = 150;

  /// Uniandes campus centre — used to check if the user is on campus at all.
  static const double _campusCenterLat = 4.60180;
  static const double _campusCenterLng = -74.06480;
  static const double _campusRadiusMetres = 500;

  /// Check & request location permissions, then return current position.
  /// Returns `null` if permissions are denied or location services disabled.
  Future<Position?> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Returns `true` if the given position is within the campus boundary.
  bool isOnCampus(Position position) {
    final distance = _distanceMetres(
      position.latitude,
      position.longitude,
      _campusCenterLat,
      _campusCenterLng,
    );
    return distance <= _campusRadiusMetres;
  }

  /// Returns the name of the nearest campus building, or `null` if none
  /// is within [nearbyRadiusMetres].
  String? getNearestBuilding(Position position) {
    String? nearest;
    double minDist = double.infinity;

    for (final entry in buildingCoordinates.entries) {
      final d = _distanceMetres(
        position.latitude,
        position.longitude,
        entry.value.lat,
        entry.value.lng,
      );
      if (d < minDist) {
        minDist = d;
        nearest = entry.key;
      }
    }

    if (minDist <= nearbyRadiusMetres) return nearest;
    return null;
  }

  /// Returns all buildings within [nearbyRadiusMetres], ordered by distance.
  List<String> getNearbyBuildings(Position position) {
    final distances = <String, double>{};
    for (final entry in buildingCoordinates.entries) {
      final d = _distanceMetres(
        position.latitude,
        position.longitude,
        entry.value.lat,
        entry.value.lng,
      );
      if (d <= nearbyRadiusMetres) {
        distances[entry.key] = d;
      }
    }
    final sorted = distances.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return sorted.map((e) => e.key).toList();
  }

  /// Haversine distance in metres between two lat/lng pairs.
  double _distanceMetres(
      double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 6371000.0; // metres
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double deg) => deg * pi / 180;
}
