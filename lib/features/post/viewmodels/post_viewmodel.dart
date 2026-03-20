import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/api_service.dart';

enum PostStatus { initial, loading, success, error }

/// ViewModel for the "Post an Item" feature.
class PostViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  PostStatus _status = PostStatus.initial;
  String? _errorMessage;
  final List<File> _images = [];
  List<Map<String, dynamic>> _stores = [];
  bool _storesLoaded = false;
  String? _selectedStoreId; // null = Personal Profile

  PostStatus get status => _status;
  String? get errorMessage => _errorMessage;
  List<File> get images => List.unmodifiable(_images);
  List<Map<String, dynamic>> get stores => List.unmodifiable(_stores);
  bool get storesLoaded => _storesLoaded;
  String? get selectedStoreId => _selectedStoreId;

  void selectStore(String? storeId) {
    _selectedStoreId = storeId;
    notifyListeners();
  }

  Future<void> loadStores() async {
    _stores = await _apiService.getMyStores();
    _storesLoaded = true;
    notifyListeners();
  }

  static const int maxImages = 1;

  // ---- Image handling ----

  /// Pick an image from the camera.
  Future<void> pickFromCamera() async {
    if (_images.length >= maxImages) return;
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (photo != null) {
      _images.add(File(photo.path));
      notifyListeners();
    }
  }

  /// Pick an image from the gallery.
  Future<void> pickFromGallery() async {
    if (_images.length >= maxImages) return;
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (photo != null) {
      _images.add(File(photo.path));
      notifyListeners();
    }
  }

  /// Remove an image at the given index.
  void removeImage(int index) {
    if (index >= 0 && index < _images.length) {
      _images.removeAt(index);
      notifyListeners();
    }
  }

  // ---- Submit ----

  /// Create the listing via the API.
  Future<void> createPost({
    required String title,
    required String description,
    required String category,
    required String buildingLocation,
    required double price,
    required String condition,
  }) async {
    _status = PostStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _apiService.createPost(
        title: title,
        description: description,
        category: category,
        buildingLocation: buildingLocation,
        price: price,
        condition: condition,
        images: _images,
        storeId: _selectedStoreId,
      );

      if (success) {
        _status = PostStatus.success;
      } else {
        _errorMessage = 'Could not publish item. Please try again.';
        _status = PostStatus.error;
      }
    } catch (e) {
      _errorMessage =
          'Unable to connect to the server. Please check your internet connection and try again.';
      _status = PostStatus.error;
    }

    notifyListeners();
  }

  /// Reset to initial state (e.g. after navigating away).
  void reset() {
    _status = PostStatus.initial;
    _errorMessage = null;
    _images.clear();
    _selectedStoreId = null;
    notifyListeners();
  }
}
