import 'dart:async';

/// Event emitted by the offline write-behind queues (posts, interaction views).
///
/// The [QueueEventBus] broadcasts these so any widget can subscribe via
/// [StreamBuilder] or `stream.listen(...)` to surface a SnackBar / toast /
/// badge update when background sync happens — without each screen needing
/// to know about the specific ViewModel that did the work.
sealed class QueueEvent {
  const QueueEvent();
}

/// A brand-new post was saved locally because the network call failed.
class PostQueued extends QueueEvent {
  final String postId;
  const PostQueued(this.postId);
}

/// One or more queued posts were successfully uploaded after reconnect.
class PostsFlushed extends QueueEvent {
  final int count;
  const PostsFlushed(this.count);
}

/// One or more queued view events were successfully uploaded after reconnect.
class ViewsFlushed extends QueueEvent {
  final int count;
  const ViewsFlushed(this.count);
}

/// One or more pending favorite add/remove actions were synced after reconnect.
class FavoritesFlushed extends QueueEvent {
  final int count;
  const FavoritesFlushed(this.count);
}

/// Application-wide event bus for the offline queues.
///
/// ## Why a custom Stream instead of Provider / ChangeNotifier?
///
/// Provider works well for *state* (current user, theme, products list) but
/// not for *one-shot events* ("the reconnect just flushed 3 pending posts").
/// Rebuilding widgets on every notify would fire the toast more than once.
///
/// A broadcast [StreamController] is the idiomatic Dart primitive here:
///
///   * `broadcast` = many listeners (SnackBar in root, badge in AppBar…),
///     each sees every event exactly once, no replay.
///   * Events are values, not state — so there's no "current value" to read.
///   * Listeners cancel their subscription on `dispose()`, preventing leaks.
///
/// ## API
///
///   QueueEventBus.instance.emit(const PostQueued('abc'));
///
///   final sub = QueueEventBus.instance.stream.listen((evt) {
///     if (evt is PostsFlushed) showSnack('${evt.count} posts sent');
///   });
///   // later:
///   await sub.cancel();
class QueueEventBus {
  QueueEventBus._();
  static final QueueEventBus instance = QueueEventBus._();

  final StreamController<QueueEvent> _controller =
      StreamController<QueueEvent>.broadcast();

  /// Public stream. Subscribe with `.listen` or use a [StreamBuilder].
  Stream<QueueEvent> get stream => _controller.stream;

  /// Emit an event to every current subscriber. No-op if nobody is listening,
  /// which is fine — events are not persisted.
  void emit(QueueEvent event) {
    if (_controller.isClosed) return;
    _controller.add(event);
  }

  /// Shuts the bus. Only call this in tests or on full app teardown — the
  /// singleton is meant to live for the lifetime of the process.
  Future<void> close() => _controller.close();
}
