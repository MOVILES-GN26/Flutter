import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Single source of truth for network reachability across the app.
///
/// Wraps the `connectivity_plus` plugin so views can react via [Consumer]
/// or read via `context.read`. Note that this only tells you whether the
/// device has a network *interface* (wifi/mobile/ethernet); individual
/// API calls still need their own try/catch in case the backend is down.
///
/// Emits `notifyListeners()` only when the boolean [isOnline] flips —
/// widgets rebuild on real transitions, not every time Android reports
/// a new connectivity event.
class ConnectivityViewModel extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;

  /// Optimistic default: assume we're online until we learn otherwise.
  /// Prevents a one-frame "You are offline" flash at cold start.
  bool _isOnline = true;

  ConnectivityViewModel() {
    _bootstrap();
  }

  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;

  Future<void> _bootstrap() async {
    try {
      final initial = await _connectivity.checkConnectivity();
      _apply(initial);
    } catch (_) {/* keep optimistic default */}

    _sub = _connectivity.onConnectivityChanged.listen(_apply);
  }

  void _apply(List<ConnectivityResult> results) {
    final next = results.any((r) => r != ConnectivityResult.none);
    if (next == _isOnline) return;
    _isOnline = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
