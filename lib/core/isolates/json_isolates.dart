import 'dart:convert';

import '../models/listing.dart';

/// Top-level functions intended to run inside a **background isolate** via
/// [compute] (or [Isolate.run]).
///
/// ## Why isolates here?
///
/// Dart is single-threaded per isolate: every `jsonDecode` + object
/// construction runs on the UI thread by default. For small payloads this
/// is invisible, but:
///
///   * The catalog endpoint can return hundreds of listings, each with a
///     nested `seller` map.
///   * The JWT `base64Url.decode` + `utf8.decode` + `jsonDecode` chain runs
///     on every cold start of the Profile screen.
///
/// Parsing those payloads on the main isolate blocks rendering and can
/// introduce visible jank on mid-range Android devices. Running the parse
/// in a secondary isolate keeps the UI thread free for animations.
///
/// ## Isolate contract (important)
///
///   * Entry points **must** be top-level (or `static`) functions.
///   * Arguments and return values are **copied** across the isolate
///     boundary — they cannot carry closures, `dart:ui` handles, or
///     references to services. That is why we only pass the raw `String`
///     body and return POD lists / maps.
///   * These functions **must not** import Flutter or call into Hive /
///     `debugPrint`. They do pure CPU work.

/// Decode a JSON-array response body into a `List<Listing>`.
///
/// Accepts either a bare `[...]` array or an object with an `items` field
/// (the backend uses both shapes depending on the endpoint).
List<Listing> parseListings(String body) {
  final decoded = jsonDecode(body);
  final List<dynamic> rawList;
  if (decoded is List) {
    rawList = decoded;
  } else if (decoded is Map && decoded['items'] is List) {
    rawList = decoded['items'] as List;
  } else {
    return const [];
  }

  return rawList
      .whereType<Map<String, dynamic>>()
      .map(Listing.fromJson)
      .toList(growable: false);
}

/// Decode a JSON-array response body into a list of raw maps, used when the
/// caller wants the raw JSON (e.g. catalog filter page) instead of [Listing]
/// instances.
List<Map<String, dynamic>> parseListingMaps(String body) {
  final decoded = jsonDecode(body);
  if (decoded is List) {
    return List<Map<String, dynamic>>.from(decoded);
  }
  if (decoded is Map && decoded['items'] is List) {
    return List<Map<String, dynamic>>.from(decoded['items']);
  }
  return const [];
}

/// Decode the middle segment of a JWT and return its payload as a Map.
/// Runs base64-url normalisation, UTF-8 decoding and JSON parsing off the
/// UI thread. Returns `null` on any malformed input.
Map<String, dynamic>? decodeJwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    final data = jsonDecode(payload);
    if (data is Map<String, dynamic>) return data;
    return null;
  } catch (_) {
    return null;
  }
}
