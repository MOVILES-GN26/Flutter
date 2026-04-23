import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/models/pending_post.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/file_storage_service.dart';
import '../../../core/services/hive_service.dart';
import '../../../core/services/preferences_service.dart';

enum PostStatus { initial, loading, success, error, queued }

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

  PostViewModel() {
    // Pre-select the user's last-used store so they don't have to pick it
    // every time they open the Post screen.
    _selectedStoreId = PreferencesService.instance.defaultStoreId;
    // Best-effort recovery of draft images from a previous session.
    _restoreDraftImages();
  }

  /// Restore any images left behind in the drafts folder (e.g. the user
  /// picked a photo, the app was killed, and now they're reopening Post).
  Future<void> _restoreDraftImages() async {
    try {
      final drafts = await FileStorageService.listPostDrafts();
      if (drafts.isEmpty) return;
      _images
        ..clear()
        ..addAll(drafts.take(maxImages));
      notifyListeners();
    } catch (e) {
      debugPrint('[PostViewModel] draft restore failed: $e');
    }
  }

  PostStatus get status => _status;
  String? get errorMessage => _errorMessage;
  List<File> get images => List.unmodifiable(_images);
  List<Map<String, dynamic>> get stores => List.unmodifiable(_stores);
  bool get storesLoaded => _storesLoaded;
  String? get selectedStoreId => _selectedStoreId;

  void selectStore(String? storeId) {
    _selectedStoreId = storeId;
    PreferencesService.instance.setDefaultStoreId(storeId);
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
    if (photo != null) await _adoptPickedImage(File(photo.path));
  }

  /// Pick an image from the gallery.
  Future<void> pickFromGallery() async {
    if (_images.length >= maxImages) return;
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (photo != null) await _adoptPickedImage(File(photo.path));
  }

  /// Copy the picked file into the app's drafts directory so it survives
  /// image-picker cache cleanup and app restarts.
  Future<void> _adoptPickedImage(File picked) async {
    try {
      final saved = await FileStorageService.savePostDraftImage(picked);
      _images.add(saved);
    } catch (e) {
      // Fallback: keep the original path even if the copy fails.
      debugPrint('[PostViewModel] draft save failed, keeping original: $e');
      _images.add(picked);
    }
    notifyListeners();
  }

  /// Remove an image at the given index (also deletes the draft file on disk).
  void removeImage(int index) {
    if (index < 0 || index >= _images.length) return;
    final removed = _images.removeAt(index);
    FileStorageService.deletePostDraft(removed);
    notifyListeners();
  }

  // ---- Submit ----

  /// Create the listing via the API.
  ///
  /// If the request throws (network down, timeout…), the post is queued in
  /// Hive so it can be retried later by [flushPendingPosts]. The caller can
  /// distinguish the two outcomes via [PostStatus.success] vs
  /// [PostStatus.queued].
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
        // Delete only the images we just uploaded. Draft files that belong
        // to still-pending queued posts must be preserved.
        for (final f in List<File>.from(_images)) {
          await FileStorageService.deletePostDraft(f);
        }
      } else {
        _errorMessage = 'Could not publish item. Please try again.';
        _status = PostStatus.error;
      }
    } catch (_) {
      // Looks like a connectivity failure: save it for later retry.
      await _enqueueCurrentDraft(
        title: title,
        description: description,
        category: category,
        buildingLocation: buildingLocation,
        price: price,
        condition: condition,
      );
      // The image files were moved into the queued-post subfolder, so the
      // drafts list no longer points to anything valid.
      _images.clear();
      _errorMessage =
          'No connection. Your item was saved and will be posted automatically when you\'re back online.';
      _status = PostStatus.queued;
    }

    notifyListeners();
  }

  Future<void> _enqueueCurrentDraft({
    required String title,
    required String description,
    required String category,
    required String buildingLocation,
    required double price,
    required String condition,
  }) async {
    final postId = DateTime.now().microsecondsSinceEpoch.toString();
    // Move the draft images to a post-scoped subfolder. This decouples the
    // queue from the live `post_drafts/` dir, so subsequent successful
    // submissions can safely wipe their own drafts without touching the
    // files this queued post depends on.
    final moved = await FileStorageService.movePostDraftsToPendingQueue(
      postId,
      _images,
    );

    final post = PendingPost(
      id: postId,
      title: title,
      description: description,
      category: category,
      buildingLocation: buildingLocation,
      price: price,
      condition: condition,
      imagePaths: moved.map((f) => f.path).toList(),
      storeId: _selectedStoreId,
      queuedAt: DateTime.now(),
    );
    await HiveService.enqueuePendingPost(post);
  }

  /// Number of posts currently waiting to be uploaded.
  int get pendingPostsCount => HiveService.getPendingPosts().length;

  /// Try to upload every queued post. Entries that upload successfully are
  /// removed from the queue; the rest stay for the next attempt.
  /// Returns the number of posts successfully flushed.
  Future<int> flushPendingPosts() async {
    final queue = HiveService.getPendingPosts();
    int flushed = 0;
    for (final post in queue) {
      final files = post.imagePaths
          .map((p) => File(p))
          .where((f) => f.existsSync())
          .toList();
      try {
        final ok = await _apiService.createPost(
          title: post.title,
          description: post.description,
          category: post.category,
          buildingLocation: post.buildingLocation,
          price: post.price,
          condition: post.condition,
          images: files,
          storeId: post.storeId,
        );
        if (ok) {
          await HiveService.removePendingPost(post.id);
          // Drop the whole per-post subfolder in one shot instead of
          // deleting files individually.
          await FileStorageService.deletePendingPostImages(post.id);
          flushed++;
        }
      } catch (_) {
        // Still offline — keep it queued and bail out; trying further
        // entries would just fail the same way.
        break;
      }
    }
    if (flushed > 0) notifyListeners();
    return flushed;
  }

  /// Reset to initial state (e.g. after navigating away).
  /// Keeps [_selectedStoreId] aligned with the persisted default so the next
  /// post pre-selects the same store the user chose previously.
  void reset() {
    _status = PostStatus.initial;
    _errorMessage = null;
    _images.clear();
    _selectedStoreId = PreferencesService.instance.defaultStoreId;
    notifyListeners();
  }
}
