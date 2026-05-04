import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'api_config.dart';
import 'hive_service.dart';
import 'queue_events.dart';
import 'storage_service.dart';
import '../cache/lru_cache.dart';
import '../isolates/json_isolates.dart';
import '../models/listing.dart';

/// Central HTTP service for all API requests.
class ApiService {
  final StorageService _storageService = StorageService();
  static final LruCache<String, Listing> listingDetailCache = LruCache(
    maxSize: 30,
  );

  static final LruCache<String, Map<String, dynamic>> productStatsCache =
      LruCache(
    maxSize: 50,
    onEvict: (productId, stats) {
      HiveService.putProductStats(productId, stats);
    },
  );
  
  /// GET /home using the current access token.
  Future<bool> validateHomeAccess() async {
    try {
      final token = await _storageService.getAccessToken();
      if (token == null) return false;
      
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.homeEndpoint}'),
        headers: ApiConfig.authHeaders(token),
      ).timeout(ApiConfig.connectionTimeout);
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  /// Attempts to refresh the access token using the stored refresh token.
  Future<bool> refreshToken() async {
    try {
      final refreshToken = await _storageService.getRefreshToken();
      if (refreshToken == null) return false;
      
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.refreshEndpoint}'),
        headers: ApiConfig.defaultHeaders,
        body: jsonEncode({'refresh_token': refreshToken}),
      ).timeout(ApiConfig.connectionTimeout);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _storageService.saveAccessToken(data['access_token']);
        if (data.containsKey('refresh_token')) {
          await _storageService.saveRefreshToken(data['refresh_token']);
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  
  /// User login.
  Future<Map<String, dynamic>?> login(
    String email,
    String password, {
    String loginType = 'email-password',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.loginEndpoint}'),
        headers: ApiConfig.defaultHeaders,
        body: jsonEncode({
          'email': email,
          'password': password,
          'login_type': loginType,
        }),
      ).timeout(ApiConfig.connectionTimeout);

      try {
        return jsonDecode(response.body);
      } catch (_) {
        return null;
      }
    } catch (e) {
      return null;
    }
  }


  Future<bool> forgotPassword(String email) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.forgotPasswordEndpoint}'),
        headers: ApiConfig.defaultHeaders,
        body: jsonEncode({'email': email}),
      ).timeout(ApiConfig.connectionTimeout);
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Register a new user.
  Future<Map<String, dynamic>?> register({
    required String firstName,
    required String lastName,
    required String email,
    required String major,
    required String password,
    required String phoneNumber,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.registerEndpoint}'),
        headers: ApiConfig.defaultHeaders,
        body: jsonEncode({
          'first_name': firstName,
          'last_name': lastName,
          'email': email,
          'major': major,
          'password': password,
          'phone_number': phoneNumber,
        }),
      ).timeout(ApiConfig.connectionTimeout);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      // Return error message from API if available
      try {
        return jsonDecode(response.body);
      } catch (_) {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getProducts({
    String? search,
    String? category,
    String? condition,
    String? priceSort,
  }) async {
    try {
      final token = await _storageService.getAccessToken();
      final queryParams = <String, String>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (category != null && category.isNotEmpty) queryParams['category'] = category;
      if (condition != null && condition.isNotEmpty) queryParams['condition'] = condition;
      if (priceSort != null && priceSort.isNotEmpty) queryParams['price_sort'] = priceSort;

      final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.productsEndpoint}')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(
        uri,
        headers: token != null
            ? ApiConfig.authHeaders(token)
            : ApiConfig.defaultHeaders,
      ).timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        // Offload JSON parsing to a background isolate — the catalog can
        // return hundreds of rows and the parse is pure CPU work with no
        // I/O, so it's a textbook fit for `compute`.
        return await compute(parseListingMaps, response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> createPost({
    required String title,
    required String description,
    required String category,
    required String buildingLocation,
    required double price,
    required String condition,
    required List<File> images,
    String? storeId,
  }) async {
    // ── Setup phase: async/await (each step depends on the previous) ──
    try {
      final token = await _storageService.getAccessToken();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.postsEndpoint}'),
      );

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields['title'] = title;
      request.fields['description'] = description;
      request.fields['category'] = category;
      request.fields['building_location'] = buildingLocation;
      request.fields['price'] = price.toString();
      request.fields['condition'] = condition;
      if (storeId != null) {
        request.fields['store_id'] = storeId;
      }

      for (final image in images) {
        final ext = image.path.split('.').last.toLowerCase();
        final subtype =
            (ext == 'png' || ext == 'gif' || ext == 'webp') ? ext : 'jpeg';
        request.files.add(
          await http.MultipartFile.fromPath(
            'images',
            image.path,
            contentType: MediaType('image', subtype),
          ),
        );
      }

      // ── Submission phase: handler-style composition ──
      // `send()` returns Future<StreamedResponse>; `.then()` maps it into a
      // bool, `.catchError()` converts network errors into a false result.
      // The outer method still `await`s the composed Future to keep the
      // call-site ergonomic.
      return await request
          .send()
          .timeout(ApiConfig.connectionTimeout)
          .then((streamed) async {
            final ok = streamed.statusCode == 200 || streamed.statusCode == 201;
            if (!ok) {
              final body = await streamed.stream.bytesToString();
              debugPrint(
                  '[createPost] failed ${streamed.statusCode}: $body');
            }
            return ok;
          })
          .catchError((Object e) {
            debugPrint('[createPost] network handler caught: $e');
            return false;
          });
    } catch (e) {
      // Setup phase failure (token read, file read, etc.).
      debugPrint('[createPost] setup caught: $e');
      return false;
    }
  }

  /// Fetch the top trending categories of the last 7 days.
  Future<List<String>> getTrendingCategories() async {
    try {
      final uri = Uri.parse(
          '${ApiConfig.baseUrl}${ApiConfig.trendingCategoriesEndpoint}');
      final response = await http
          .get(uri, headers: ApiConfig.defaultHeaders)
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        return data.map((e) => e['category'] as String).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Fetch the stores owned by the authenticated user.
  Future<List<Map<String, dynamic>>> getMyStores() async {
    try {
      final token = await _storageService.getAccessToken();
      if (token == null) return [];
      final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.myStoresEndpoint}');
      final response = await http
          .get(uri, headers: ApiConfig.authHeaders(token))
          .timeout(ApiConfig.connectionTimeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Recommended-for-you
  // ════════════════════════════════════════════════════════════════════════════

  /// Records that the authenticated user viewed a product in [category].
  ///
  /// Write-behind: if the POST fails the category is queued in Hive and
  /// flushed by [flushPendingCategoryViews] as soon as connectivity is
  /// restored. Anonymous sessions are ignored (no token → no-op).
  Future<void> recordCategoryView(String category) async {
    if (category.trim().isEmpty) return;
    try {
      final token = await _storageService.getAccessToken();
      if (token == null) return; // anonymous — no personalisation
      final response = await http
          .post(
            Uri.parse(
                '${ApiConfig.baseUrl}${ApiConfig.viewedCategoryEndpoint}'),
            headers: ApiConfig.authHeaders(token),
            body: jsonEncode({'category': category}),
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        await HiveService.enqueuePendingCategoryView(category);
      }
    } catch (e) {
      debugPrint('[recordCategoryView] queueing offline: $e');
      await HiveService.enqueuePendingCategoryView(category);
    }
  }

  /// Flushes any category-view events that were queued while offline.
  /// Returns the number of events successfully delivered.
  Future<int> flushPendingCategoryViews() async {
    final categories = HiveService.getPendingCategoryViewIds();
    if (categories.isEmpty) return 0;

    final token = await _storageService.getAccessToken();
    if (token == null) return 0;
    final uri = Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.viewedCategoryEndpoint}');

    int flushed = 0;
    for (final category in categories) {
      try {
        final response = await http
            .post(
              uri,
              headers: ApiConfig.authHeaders(token),
              body: jsonEncode({'category': category}),
            )
            .timeout(ApiConfig.connectionTimeout);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          await HiveService.removePendingCategoryView(category);
          flushed++;
        } else {
          if (response.statusCode == 404) {
            await HiveService.removePendingCategoryView(category);
          }
          break;
        }
      } catch (_) {
        break;
      }
    }
    return flushed;
  }

  /// Fetches personalised product recommendations for the authenticated user.
  ///
  /// Strategy: **cache-falling-on-network**.
  ///   1. Always try the network first; if it succeeds, refresh the Hive
  ///      cache and return `fromCache: false`.
  ///   2. If the network fails (offline / timeout / 5xx), fall back to the
  ///      Hive snapshot and return `fromCache: true`.
  ///   3. If neither has data, return an empty list.
  ///
  /// Sold products are filtered out in both paths.
  Future<({List<Listing> items, bool fromCache})> getRecommendedProducts() async {
    try {
      final token = await _storageService.getAccessToken();
      if (token == null) {
        // Unauthenticated — nothing to personalise.
        return (items: const <Listing>[], fromCache: false);
      }

      final response = await http
          .get(
            Uri.parse(
                '${ApiConfig.baseUrl}${ApiConfig.recommendedProductsEndpoint}'),
            headers: ApiConfig.authHeaders(token),
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final parsed = await parseListings(response.body);
        final fresh = parsed.where((l) => !l.isSold).toList();
        // Fire-and-forget cache write.
        HiveService.putRecommendedListings(fresh);
        return (items: fresh, fromCache: false);
      }
      throw Exception('HTTP ${response.statusCode}');
    } catch (e) {
      debugPrint('[getRecommendedProducts] network failed, trying cache: $e');
      final cached = HiveService.getRecommendedListings()
          .where((l) => !l.isSold)
          .toList();
      return (items: cached, fromCache: true);
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // View interactions
  // ════════════════════════════════════════════════════════════════════════════

  /// Registers a view interaction for a product.
  ///
  /// Write-behind: if the POST fails (no network, backend down), the view
  /// is queued in Hive keyed by productId and flushed by
  /// [flushPendingViews] as soon as connectivity is restored.
  Future<void> registerView(String productId) async {
    try {
      final token = await _storageService.getAccessToken();
      final response = await http
          .post(
            Uri.parse(
                '${ApiConfig.baseUrl}${ApiConfig.interactionsViewEndpoint}'),
            headers: token != null
                ? ApiConfig.authHeaders(token)
                : ApiConfig.defaultHeaders,
            body: jsonEncode({'product_id': productId}),
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        // Non-2xx (e.g. backend up but flaky): queue for retry so we don't
        // lose the analytics event.
        await HiveService.enqueuePendingView(productId);
      }
    } catch (e) {
      debugPrint('[registerView] queueing offline: $e');
      await HiveService.enqueuePendingView(productId);
    }
  }

  /// Logs a buyer→seller direct-contact event (e.g. tapped the WhatsApp
  /// button). Write-behind: failures are queued in Hive and flushed by
  /// [flushPendingContacts] on reconnect.
  ///
  /// Backs the BQ Type 3:
  ///   "% of orders in the last N days preceded by a direct contact between
  ///    the same buyer and seller."
  Future<void> recordContact({
    required String productId,
    required String sellerId,
    String channel = 'whatsapp',
  }) async {
    try {
      final token = await _storageService.getAccessToken();
      if (token == null) {
        // Anonymous users can't be correlated with orders, so the event is
        // useless for the BQ. Drop it silently.
        return;
      }
      final response = await http
          .post(
            Uri.parse(
                '${ApiConfig.baseUrl}${ApiConfig.analyticsContactEndpoint}'),
            headers: ApiConfig.authHeaders(token),
            body: jsonEncode({
              'product_id': productId,
              'seller_id': sellerId,
              'channel': channel,
            }),
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        // Backend reachable but rejected — queue for retry. Lets transient
        // 5xx blips heal automatically without losing the event.
        await HiveService.enqueuePendingContact(
          productId: productId,
          sellerId: sellerId,
          channel: channel,
        );
      }
    } catch (e) {
      debugPrint('[recordContact] queueing offline: $e');
      await HiveService.enqueuePendingContact(
        productId: productId,
        sellerId: sellerId,
        channel: channel,
      );
    }
  }

 
  Future<int> flushPendingContacts() async {
    final pending = HiveService.getPendingContacts();
    if (pending.isEmpty) return 0;

    final token = await _storageService.getAccessToken();
    if (token == null) return 0;

    final headers = ApiConfig.authHeaders(token);
    final uri =
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.analyticsContactEndpoint}');

    int flushed = 0;
    for (final entry in pending) {
      final key = entry['_key'] as String?;
      if (key == null) continue;
      try {
        final response = await http
            .post(
              uri,
              headers: headers,
              body: jsonEncode({
                'product_id': entry['product_id'],
                'seller_id': entry['seller_id'],
                'channel': entry['channel'] ?? 'whatsapp',
              }),
            )
            .timeout(ApiConfig.connectionTimeout);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          await HiveService.removePendingContact(key);
          flushed++;
        } else {
          // 4xx with bad payload — drop so we don't loop forever.
          if (response.statusCode == 400 || response.statusCode == 404) {
            await HiveService.removePendingContact(key);
          }
          break;
        }
      } catch (_) {
        // Still offline — keep remaining for next try.
        break;
      }
    }
    return flushed;
  }

  /// Drains [HiveService.getPendingViewIds] by POSTing each entry. Stops
  /// on the first failure so we don't hammer the server during a partial
  /// outage. Returns the count of events successfully flushed.
  Future<int> flushPendingViews() async {
    final ids = HiveService.getPendingViewIds();
    if (ids.isEmpty) return 0;

    final token = await _storageService.getAccessToken();
    final headers = token != null
        ? ApiConfig.authHeaders(token)
        : ApiConfig.defaultHeaders;
    final uri = Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.interactionsViewEndpoint}');

    int flushed = 0;
    for (final productId in ids) {
      try {
        final response = await http
            .post(
              uri,
              headers: headers,
              body: jsonEncode({'product_id': productId}),
            )
            .timeout(ApiConfig.connectionTimeout);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          await HiveService.removePendingView(productId);
          flushed++;
        } else {
          // Server responded but rejected — don't retry forever, drop.
          if (response.statusCode == 404) {
            await HiveService.removePendingView(productId);
          }
          break;
        }
      } catch (_) {
        // Network hiccup mid-flush — keep remaining events for next try.
        break;
      }
    }
    if (flushed > 0) {
      QueueEventBus.instance.emit(ViewsFlushed(flushed));
    }
    return flushed;
  }

  Future<({Map<String, dynamic> data, DateTime? updatedAt})?>
      getProductStats(String productId) async {
    // ── 1. Check LRU RAM cache (O(1)) ──
    final lruHit = productStatsCache.get(productId);
    if (lruHit != null) {
      debugPrint('[getProductStats] LRU RAM hit for $productId');
      return (data: lruHit, updatedAt: null);
    }

    // ── 2. Try network ──
    try {
      final token = await _storageService.getAccessToken();
      final uri = Uri.parse(
          '${ApiConfig.baseUrl}${ApiConfig.interactionsStatsEndpoint(productId)}');
      final response = await http.get(
        uri,
        headers: token != null
            ? ApiConfig.authHeaders(token)
            : ApiConfig.defaultHeaders,
      ).timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        // Populate both LRU and Hive for future lookups.
        productStatsCache.put(productId, data);
        await HiveService.putProductStats(productId, data);
        return (data: data, updatedAt: null);
      }
    } catch (e) {
      debugPrint('[getProductStats] falling back to cache: $e');
    }

    // ── 3. Fall back to Hive disk cache ──
    final cached = HiveService.getProductStats(productId);
    if (cached == null) return null;
    // Warm the LRU with the Hive result so subsequent reads are O(1).
    productStatsCache.put(productId, cached.data);
    return (data: cached.data, updatedAt: cached.updatedAt);
  }

  /// Fetch the most recent listings for the Home screen.
  /// Populates the [listingDetailCache] with each listing for O(1)
  /// subsequent lookups by product ID.
  Future<List<Listing>> getRecentProducts() async {
    try {
      final token = await _storageService.getAccessToken();
      final uri =
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.productsEndpoint}');
      final response = await http.get(
        uri,
        headers: token != null
            ? ApiConfig.authHeaders(token)
            : ApiConfig.defaultHeaders,
      ).timeout(ApiConfig.connectionTimeout);

      if (response.statusCode != 200) return [];
      // Parse + construct `Listing` instances off the UI thread.
      final listings = await compute(parseListings, response.body);
      // Exclude products that have already been sold.
      final available = listings.where((l) => !l.isSold).toList();
      // Warm the LRU cache so tapping a product skips deserialization.
      for (final listing in available) {
        if (listing.id != null) {
          listingDetailCache.put(listing.id!, listing);
        }
      }
      return available;
    } catch (e) {
      return [];
    }
  }

  /// Fetch all products belonging to a specific user.
  Future<List<Listing>> getUserProducts(String userId) async {
    try {
      final token = await _storageService.getAccessToken();
      final uri = Uri.parse(
          '${ApiConfig.baseUrl}${ApiConfig.usersEndpoint}/$userId/products');
      final response = await http.get(
        uri,
        headers: token != null
            ? ApiConfig.authHeaders(token)
            : ApiConfig.defaultHeaders,
      ).timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        // Background-isolate parse — same reasoning as getRecentProducts.
        return await compute(parseListings, response.body);
      }
      return [];
    } catch (e) {
      debugPrint('[getUserProducts] exception: $e');
      return [];
    }
  }

  /// Fetch a single product by ID. Returns null if not found or on error.
  Future<Listing?> getProductById(String productId) async {
    // Check LRU cache first.
    final cached = listingDetailCache.get(productId);
    try {
      final token = await _storageService.getAccessToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.productsEndpoint}/$productId'),
        headers: token != null
            ? ApiConfig.authHeaders(token)
            : ApiConfig.defaultHeaders,
      ).timeout(ApiConfig.connectionTimeout);
      if (response.statusCode == 200) {
        final listing = Listing.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
        listingDetailCache.put(productId, listing);
        return listing;
      }
    } catch (_) {}
    return cached;
  }

  /// Deletes a product by ID. Returns true on success.
  Future<bool> deleteProduct(String id) async {
    try {
      final token = await _storageService.getAccessToken();
      if (token == null) return false;

      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.productsEndpoint}/$id'),
        headers: ApiConfig.authHeaders(token),
      ).timeout(ApiConfig.connectionTimeout);

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('[deleteProduct] exception: $e');
      return false;
    }
  }

  /// Updates the authenticated user's profile via PATCH /users/me.
  Future<bool> updateProfile({
    required String firstName,
    required String lastName,
    required String major,
    String? password,
    String? phoneNumber,
  }) async {
    try {
      final token = await _storageService.getAccessToken();
      if (token == null) return false;

      final body = <String, dynamic>{
        'first_name': firstName,
        'last_name': lastName,
        'major': major,
      };
      if (password != null) body['password'] = password;
      if (phoneNumber != null) body['phone_number'] = phoneNumber;

      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.usersEndpoint}/me'),
        headers: ApiConfig.authHeaders(token),
        body: jsonEncode(body),
      ).timeout(ApiConfig.connectionTimeout);

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('[updateProfile] exception: $e');
      return false;
    }
  }

  /// Uploads a new avatar image. Returns the new avatar URL on success.
  ///
  /// Same mixed `async/await + .then/.catchError` pattern as [createPost]:
  /// async setup, composed submission.
  Future<String?> updateAvatar(File imageFile) async {
    try {
      final token = await _storageService.getAccessToken();
      if (token == null) return null;

      final ext = imageFile.path.split('.').last.toLowerCase();
      final subtype =
          ['png', 'gif', 'webp'].contains(ext) ? ext : 'jpeg';

      final request = http.MultipartRequest(
        'PATCH',
        Uri.parse(
            '${ApiConfig.baseUrl}${ApiConfig.usersEndpoint}/me/avatar'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        await http.MultipartFile.fromPath(
          'avatar',
          imageFile.path,
          contentType: MediaType('image', subtype),
        ),
      );

      return await request
          .send()
          .timeout(ApiConfig.connectionTimeout)
          .then((streamed) async {
            final body = await streamed.stream.bytesToString();
            if (streamed.statusCode == 200 || streamed.statusCode == 201) {
              final data = jsonDecode(body);
              return data['avatar_url'] as String? ?? data['url'] as String?;
            }
            debugPrint('[updateAvatar] failed ${streamed.statusCode}: $body');
            return null;
          })
          .catchError((Object e) {
            debugPrint('[updateAvatar] network handler caught: $e');
            return null;
          });
    } catch (e) {
      debugPrint('[updateAvatar] setup caught: $e');
      return null;
    }
  }

  /// Creates an order for a product.
  Future<Map<String, dynamic>?> createOrder({
    required String productId,
    required int quantity,
    String? deliveryOption,
  }) async {
    try {
      final token = await _storageService.getAccessToken();
      if (token == null) return null;

      final body = <String, dynamic>{
        'product_id': productId,
        'quantity': quantity,
      };
      if (deliveryOption != null) body['delivery_option'] = deliveryOption;

      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.ordersEndpoint}'),
            headers: ApiConfig.authHeaders(token),
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      debugPrint('[createOrder] failed ${response.statusCode}: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('[createOrder] exception: $e');
      return null;
    }
  }

  /// Uploads a payment proof image (as bytes) for the given order.
  Future<Map<String, dynamic>?> uploadPaymentProof(
    String orderId,
    List<int> fileBytes,
    String fileName,
  ) async {
    try {
      final token = await _storageService.getAccessToken();
      if (token == null) return null;

      final ext = fileName.split('.').last.toLowerCase();
      final subtype =
          ['png', 'gif', 'webp'].contains(ext) ? ext : 'jpeg';

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
            '${ApiConfig.baseUrl}${ApiConfig.ordersEndpoint}/$orderId/upload-proof'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
          contentType: MediaType('image', subtype),
        ),
      );

      final streamed =
          await request.send().timeout(ApiConfig.connectionTimeout);
      final responseBody = await streamed.stream.bytesToString();

      if (streamed.statusCode == 200 || streamed.statusCode == 201) {
        return jsonDecode(responseBody) as Map<String, dynamic>;
      }
      debugPrint(
          '[uploadPaymentProof] failed ${streamed.statusCode}: $responseBody');
      return null;
    } catch (e) {
      debugPrint('[uploadPaymentProof] exception: $e');
      return null;
    }
  }
  /// Add a product to the authenticated user's favorites. Returns true on success.
  Future<bool> addFavorite(String productId) async {
    try {
      final token = await _storageService.getAccessToken();
      if (token == null) return false;
      final response = await http
          .post(
            Uri.parse(
                '${ApiConfig.baseUrl}${ApiConfig.favoritesEndpoint}/$productId'),
            headers: ApiConfig.authHeaders(token),
          )
          .timeout(ApiConfig.connectionTimeout);
      return response.statusCode == 204 ||
          response.statusCode == 200 ||
          response.statusCode == 201;
    } catch (e) {
      debugPrint('[addFavorite] exception: $e');
      return false;
    }
  }

  /// Remove a product from the authenticated user's favorites. Returns true on success.
  Future<bool> removeFavorite(String productId) async {
    try {
      final token = await _storageService.getAccessToken();
      if (token == null) return false;
      final response = await http
          .delete(
            Uri.parse(
                '${ApiConfig.baseUrl}${ApiConfig.favoritesEndpoint}/$productId'),
            headers: ApiConfig.authHeaders(token),
          )
          .timeout(ApiConfig.connectionTimeout);
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      debugPrint('[removeFavorite] exception: $e');
      return false;
    }
  }

  /// Fetch the authenticated user's favorite products.
  Future<List<Listing>> getFavorites() async {
    try {
      final token = await _storageService.getAccessToken();
      if (token == null) return [];
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.favoritesEndpoint}'),
            headers: ApiConfig.authHeaders(token),
          )
          .timeout(ApiConfig.connectionTimeout);
      if (response.statusCode == 200) {
        // Background-isolate parse — same reasoning as getRecentProducts.
        final listings = await compute(parseListings, response.body);
        // Exclude favorites that have already been sold.
        return listings.where((l) => !l.isSold).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[getFavorites] exception: $e');
      return [];
    }
  }

  /// Fetch orders associated with a product (seller only).
  /// Results are cached in Hive so the seller can see them offline.
  Future<List<Map<String, dynamic>>?> getOrdersByProduct(
      String productId) async {
    // ── 1. Try network ──
    try {
      final token = await _storageService.getAccessToken();
      if (token == null) throw Exception('No token');
      final uri = Uri.parse(
          '${ApiConfig.baseUrl}${ApiConfig.ordersEndpoint}?product_id=$productId');
      final response = await http
          .get(uri, headers: ApiConfig.authHeaders(token))
          .timeout(ApiConfig.connectionTimeout);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list = (body is List ? body : [body])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        await HiveService.putProductOrders(productId, list);
        return list;
      }
    } catch (e) {
      debugPrint('[getOrdersByProduct] falling back to cache: $e');
    }
    // ── 2. Fall back to Hive ──
    final cached = HiveService.getProductOrders(productId);
    return cached?.orders;
  }

  /// Fetch how many users have favorited a product. No auth required.
  Future<int?> getFavoritesCount(String productId) async {
    try {
      final response = await http
          .get(
            Uri.parse(
                '${ApiConfig.baseUrl}${ApiConfig.favoriteCountEndpoint(productId)}'),
            headers: ApiConfig.defaultHeaders,
          )
          .timeout(ApiConfig.connectionTimeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is int) return data;
        if (data is Map) {
          return data['count'] as int? ??
              data['favorites_count'] as int? ??
              data['total'] as int?;
        }
      }
      return null;
    } catch (e) {
      debugPrint('[getFavoritesCount] exception: $e');
      return null;
    }
  }}
