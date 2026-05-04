import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../core/isolates/json_isolates.dart';
import '../../../core/models/listing.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/hive_service.dart';
import '../../../core/services/storage_service.dart';
import '../../auth/models/auth_user.dart';

enum ProfileStatus { initial, loading, loaded, error }

/// ViewModel for the Profile screen.
/// Decodes the stored JWT to read user info, then fetches the user's listings.
class ProfileViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();

  ProfileStatus _status = ProfileStatus.initial;
  List<Listing> _listings = [];
  String? _errorMessage;

  // User info
  String? _userId;
  String? _name;
  String? _email;
  String? _major;
  String? _studentId;
  String? _firstName;
  String? _lastName;
  String? _avatarUrl;
  String? _phoneNumber;

  ProfileStatus get status => _status;
  List<Listing> get listings => List.unmodifiable(_listings);
  String? get errorMessage => _errorMessage;
  String? get name => _name;
  String? get email => _email;
  String? get major => _major;
  String? get studentId => _studentId;
  String? get firstName => _firstName;
  String? get lastName => _lastName;
  String? get avatarUrl => _avatarUrl;
  String? get phoneNumber => _phoneNumber;

  /// Loads the profile.
  ///
  /// Source-of-truth order for user info:
  ///   1. [authUser] — populated when the user logged in this session.
  ///   2. Hive cache — survives restarts while tokens are valid.
  ///   3. JWT payload decoding — last resort.
  Future<void> loadProfile({AuthUser? authUser}) async {
    _status = ProfileStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      if (authUser != null && authUser.id.isNotEmpty) {
        _applyAuthUser(authUser);
      } else {
        final cached = HiveService.getUser();
        if (cached != null && cached.id.isNotEmpty) {
          _applyAuthUser(cached);
        } else {
          await _loadUserFromToken();
        }
      }

      // Refresh user fields (avatar, phone, etc.) from the API so we always
      // show the latest data, not just what was cached at login time.
      final me = await _apiService.getMe();
      if (me != null) {
        final fresh = AuthUser.fromJson(me);
        _applyAuthUser(fresh);
        // Persist the enriched record so the next cold-start also has it.
        await HiveService.putUser(fresh);
      }

      if (_userId != null && _userId!.isNotEmpty) {
        _listings = await _apiService.getUserProducts(_userId!);
      }

      _status = ProfileStatus.loaded;
    } catch (e) {
      debugPrint('[ProfileViewModel] loadProfile error: $e');
      _errorMessage = 'Could not load profile. Please try again.';
      _status = ProfileStatus.error;
    }

    notifyListeners();
  }

  void _applyAuthUser(AuthUser user) {
    _userId = user.id;
    _name = user.fullName;
    _email = user.email;
    _major = user.major;
    _firstName = user.firstName;
    _lastName = user.lastName;
    // These fields may be absent from older cached AuthUser objects; they are
    // overwritten by the fresh getMe() call in loadProfile when online.
    if (user.avatarUrl != null) _avatarUrl = user.avatarUrl;
    if (user.phoneNumber != null) _phoneNumber = user.phoneNumber;
  }

  /// Deletes a product by ID and removes it from the local list.
  /// Returns true on success.
  Future<bool> deleteProduct(String id) async {
    try {
      final success = await _apiService.deleteProduct(id);
      if (success) {
        _listings = _listings.where((l) => l.id != id).toList();
        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('[ProfileViewModel] deleteProduct error: $e');
      return false;
    }
  }

  /// Sends PATCH /users/me with the given fields. Returns true on success.
  Future<bool> updateProfile({
    required String firstName,
    required String lastName,
    required String major,
    String? password,
    String? phoneNumber,
  }) async {
    try {
      final success = await _apiService.updateProfile(
        firstName: firstName,
        lastName: lastName,
        major: major,
        password: password?.isNotEmpty == true ? password : null,
        phoneNumber: phoneNumber?.isNotEmpty == true ? phoneNumber : null,
      );
      if (success) {
        _firstName = firstName;
        _lastName = lastName;
        _major = major;
        _name = '$firstName $lastName'.trim();
        if (phoneNumber != null) _phoneNumber = phoneNumber;

        // Keep the cached AuthUser in sync so other screens hydrated from
        // Hive (e.g. AuthViewModel on cold start) see the updated values.
        if (_userId != null && _email != null) {
          await HiveService.putUser(AuthUser(
            id: _userId!,
            email: _email!,
            firstName: firstName,
            lastName: lastName,
            major: major,
            avatarUrl: _avatarUrl,
            phoneNumber: _phoneNumber,
          ));
        }
        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('[ProfileViewModel] updateProfile error: $e');
      return false;
    }
  }

  /// Uploads a new avatar image and updates the local avatarUrl.
  Future<bool> updateAvatar(File imageFile) async {
    try {
      final url = await _apiService.updateAvatar(imageFile);
      if (url != null) {
        _avatarUrl = url;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[ProfileViewModel] updateAvatar error: $e');
      return false;
    }
  }

  /// Wipes every field so the next account does not briefly see the previous
  /// user's name, avatar, or listings on the Profile tab.
  void resetForLogout() {
    _status = ProfileStatus.initial;
    _errorMessage = null;
    _listings = const [];
    _userId = null;
    _name = null;
    _email = null;
    _major = null;
    _studentId = null;
    _firstName = null;
    _lastName = null;
    _avatarUrl = null;
    _phoneNumber = null;
    notifyListeners();
  }

  /// Refreshes only the listings (e.g. after posting a new item).
  Future<void> refreshListings() async {
    if (_userId == null || _userId!.isEmpty) return;
    try {
      _listings = await _apiService.getUserProducts(_userId!);
      notifyListeners();
    } catch (_) {}
  }

  /// Decodes the stored JWT payload to extract user fields.
  ///
  /// The base64-url + utf8 + JSON decode chain runs in a background isolate
  /// via [compute] so the cold-start of the Profile screen does not do
  /// crypto-adjacent string work on the UI thread.
  Future<void> _loadUserFromToken() async {
    try {
      final token = await _storageService.getAccessToken();
      if (token == null) return;

      final data = await compute(decodeJwtPayload, token);
      if (data == null) return;

      _userId = data['sub'] as String?;
      _email = data['email'] as String?;

      final firstName = data['first_name'] as String?;
      final lastName = data['last_name'] as String?;
      _firstName = firstName;
      _lastName = lastName;
      if (firstName != null || lastName != null) {
        _name = [firstName, lastName]
            .where((p) => p != null && p.isNotEmpty)
            .join(' ');
      } else {
        _name = data['name'] as String?;
      }

      _major = data['major'] as String?;
      _studentId = data['student_id']?.toString();
      _phoneNumber = data['phone_number'] as String?;
    } catch (e) {
      debugPrint('[ProfileViewModel] JWT decode error: $e');
    }
  }
}
