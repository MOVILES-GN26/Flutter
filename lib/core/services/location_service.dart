import 'dart:math';
import 'package:geolocator/geolocator.dart';
import '../constants/uniandes_buildings.dart';
import 'preferences_service.dart';

/// How old a cached GPS fix can be before we refuse to use it. 24h keeps
/// things useful for a user that reopens the app the next day still on
/// campus, without pretending we know their location days later.
const Duration _staleLocationCutoff = Duration(hours: 24);

/// A position returned by [LocationService.resolvePosition], plus whether
/// it came from a fresh GPS fix or from the persisted fallback.
class ResolvedPosition {
  final double latitude;
  final double longitude;
  final bool isFresh;
  final DateTime? cachedAt;

  const ResolvedPosition({
    required this.latitude,
    required this.longitude,
    required this.isFresh,
    this.cachedAt,
  });
}

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
  ///
  /// Side effect: successful fixes are persisted via [PreferencesService]
  /// so they can be used as a fallback by [resolvePosition].
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
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      // Fire-and-forget: the fix is already returned, don't block on I/O.
      PreferencesService.instance.setLastKnownLocation(
        latitude: pos.latitude,
        longitude: pos.longitude,
      );
      return pos;
    } catch (_) {
      return null;
    }
  }

  /// Offline-first location resolver. Tries GPS first; if that fails or
  /// times out, falls back to the last cached fix provided it is younger
  /// than [_staleLocationCutoff]. Returns null only if both options fail,
  /// at which point the UI should hide the "nearby" section gracefully.
  Future<ResolvedPosition?> resolvePosition() async {
    final fresh = await getCurrentPosition();
    if (fresh != null) {
      return ResolvedPosition(
        latitude: fresh.latitude,
        longitude: fresh.longitude,
        isFresh: true,
      );
    }
    final cached = PreferencesService.instance.lastKnownLocation;
    if (cached == null || cached.age > _staleLocationCutoff) return null;
    return ResolvedPosition(
      latitude: cached.latitude,
      longitude: cached.longitude,
      isFresh: false,
      cachedAt: cached.timestamp,
    );
  }

  /// Variant of [isOnCampus] that accepts the coordinate pair directly so
  /// it can be used with both [Position] and [ResolvedPosition].
  bool isOnCampusAt(double latitude, double longitude) {
    final distance = _distanceMetres(
      latitude,
      longitude,
      _campusCenterLat,
      _campusCenterLng,
    );
    return distance <= _campusRadiusMetres;
  }

  /// Variant of [getNearestBuilding] that accepts the coordinate pair
  /// directly. Returns null if no building is within [nearbyRadiusMetres].
  String? getNearestBuildingAt(double latitude, double longitude) {
    String? nearest;
    double minDist = double.infinity;
    for (final entry in buildingCoordinates.entries) {
      final d = _distanceMetres(
        latitude,
        longitude,
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

  /// Variant of [getNearbyBuildings] that accepts coordinates directly.
  List<String> getNearbyBuildingsAt(double latitude, double longitude) {
    final distances = <String, double>{};
    for (final entry in buildingCoordinates.entries) {
      final d = _distanceMetres(
        latitude,
        longitude,
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
