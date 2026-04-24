import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Wrapper around the app's internal documents directory for three kinds
/// of binary files that live outside of SQL and key-value stores:
///
///   * **Post drafts** — images the user has picked for a listing but not
///     yet uploaded. Copying them out of the image-picker cache protects
///     them from being cleaned up by the OS if the user backgrounds the app.
///   * **Pending-post images** — drafts that were enqueued for retry
///     because the upload failed. Kept in a per-post subfolder keyed by
///     the pending post id so they don't collide with new drafts.
///   * **Payment proofs** — receipts/screenshots that were successfully
///     uploaded to the server. Keeping a local copy gives the buyer an
///     offline record of their purchases.
///
/// Files are stored under [getApplicationDocumentsDirectory] (private to
/// the app, not visible in the gallery).
class FileStorageService {
  FileStorageService._();

  static const String _postDraftsDir = 'post_drafts';
  static const String _pendingPostsImagesDir = 'pending_posts_images';
  static const String _paymentProofsDir = 'payment_proofs';

  // ── Directory helpers ─────────────────────────────────────────────────

  static Future<Directory> _subdir(String name) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, name));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  // ══════════════════════════════════════════════════════════════════════
  // Post drafts
  // ══════════════════════════════════════════════════════════════════════

  /// Copies [source] into the post-drafts directory with a timestamped
  /// filename and returns the new file. The returned [File] is safe to
  /// keep around — it lives in the app's private docs directory.
  static Future<File> savePostDraftImage(File source) async {
    final dir = await _subdir(_postDraftsDir);
    final ext = p.extension(source.path);
    final fileName = '${DateTime.now().microsecondsSinceEpoch}$ext';
    final target = File(p.join(dir.path, fileName));
    return source.copy(target.path);
  }

  /// Every image currently sitting in the drafts folder, newest first.
  /// Used by [PostViewModel] to recover a draft after a crash / app kill.
  static Future<List<File>> listPostDrafts() async {
    final dir = await _subdir(_postDraftsDir);
    final files = dir.listSync().whereType<File>().toList();
    files.sort(
      (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
    );
    return files;
  }

  /// Best-effort delete of a single draft. Silent no-op if the file is gone.
  static Future<void> deletePostDraft(File file) async {
    if (file.existsSync()) {
      await file.delete();
    }
  }

  /// Wipe every draft image. Call on successful post submission.
  static Future<void> clearPostDrafts() async {
    final dir = await _subdir(_postDraftsDir);
    for (final entity in dir.listSync()) {
      if (entity is File) {
        try {
          await entity.delete();
        } catch (_) {/* keep going on partial failure */}
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // Pending-post images (per-post subfolders keyed by post id)
  // ══════════════════════════════════════════════════════════════════════

  /// Move the given draft files into `pending_posts_images/{postId}/` and
  /// return the new [File] handles. Falls back to copying when a cross-
  /// filesystem rename is not permitted. Callers should use the returned
  /// paths (not the originals) from then on.
  static Future<List<File>> movePostDraftsToPendingQueue(
    String postId,
    List<File> drafts,
  ) async {
    if (drafts.isEmpty) return const [];
    final base = await _subdir(_pendingPostsImagesDir);
    final targetDir = Directory(p.join(base.path, postId));
    if (!targetDir.existsSync()) {
      await targetDir.create(recursive: true);
    }

    final moved = <File>[];
    for (final draft in drafts) {
      if (!draft.existsSync()) continue;
      final target = File(p.join(targetDir.path, p.basename(draft.path)));
      try {
        moved.add(await draft.rename(target.path));
      } on FileSystemException {
        // Rename can fail across filesystems; fall back to copy + delete.
        final copied = await draft.copy(target.path);
        try {
          await draft.delete();
        } catch (_) {/* best-effort */}
        moved.add(copied);
      }
    }
    return moved;
  }

  /// Delete the entire `pending_posts_images/{postId}/` subfolder after a
  /// queued post is flushed successfully.
  static Future<void> deletePendingPostImages(String postId) async {
    final base = await _subdir(_pendingPostsImagesDir);
    final dir = Directory(p.join(base.path, postId));
    if (dir.existsSync()) {
      try {
        await dir.delete(recursive: true);
      } catch (_) {/* best-effort */}
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // Payment proofs
  // ══════════════════════════════════════════════════════════════════════

  /// Save a payment proof under `payment_proofs/{orderId}{ext}`.
  /// If a file for the same order already exists it is overwritten.
  static Future<File> savePaymentProof({
    required String orderId,
    required List<int> bytes,
    required String originalFileName,
  }) async {
    final dir = await _subdir(_paymentProofsDir);
    final ext = p.extension(originalFileName).isNotEmpty
        ? p.extension(originalFileName)
        : '.jpg';
    final target = File(p.join(dir.path, '$orderId$ext'));
    return target.writeAsBytes(bytes, flush: true);
  }

  /// Returns the locally-stored proof for [orderId], regardless of
  /// extension (jpg/png/webp). Null if not found.
  static Future<File?> getPaymentProof(String orderId) async {
    final dir = await _subdir(_paymentProofsDir);
    for (final entity in dir.listSync()) {
      if (entity is File &&
          p.basenameWithoutExtension(entity.path) == orderId) {
        return entity;
      }
    }
    return null;
  }

  /// Every saved proof, newest first. Used by a future "My purchases" view.
  static Future<List<File>> listPaymentProofs() async {
    final dir = await _subdir(_paymentProofsDir);
    final files = dir.listSync().whereType<File>().toList();
    files.sort(
      (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
    );
    return files;
  }

  // ══════════════════════════════════════════════════════════════════════
  // Session cleanup
  // ══════════════════════════════════════════════════════════════════════

  /// Delete every file this service manages for the current user session:
  /// draft images, queued-post images, and archived payment proofs. Invoke
  /// from the logout path so the next account starts with an empty disk.
  static Future<void> wipeUserFiles() async {
    await Future.wait([
      _deleteDirContents(_postDraftsDir),
      _deleteDirContents(_pendingPostsImagesDir),
      _deleteDirContents(_paymentProofsDir),
    ]);
  }

  /// Recursively deletes every entry inside [_subdir(name)] without removing
  /// the folder itself. Swallows individual failures so a single locked file
  /// never blocks the rest of the wipe.
  static Future<void> _deleteDirContents(String name) async {
    final dir = await _subdir(name);
    for (final entity in dir.listSync()) {
      try {
        await entity.delete(recursive: true);
      } catch (_) {/* keep going */}
    }
  }
}
