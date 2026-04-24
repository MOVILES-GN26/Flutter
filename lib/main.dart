import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'core/auth_gate.dart';
import 'core/services/api_service.dart';
import 'core/services/hive_service.dart';
import 'core/services/local_db_service.dart';
import 'core/services/prefetch_service.dart';
import 'core/services/preferences_service.dart';
import 'core/services/queue_events.dart';
import 'core/viewmodels/connectivity_viewmodel.dart';
import 'core/viewmodels/theme_viewmodel.dart';
import 'features/auth/viewmodels/auth_viewmodel.dart';
import 'features/catalog/viewmodels/catalog_viewmodel.dart';
import 'features/favorites/viewmodels/favorites_viewmodel.dart';
import 'features/home/viewmodels/home_viewmodel.dart';
import 'features/post/viewmodels/post_viewmodel.dart';
import 'features/profile/viewmodels/profile_viewmodel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Configure Flutter's in-memory image cache ─────────────────────────
  // Default: 100 images / 100 MB (LRU).
  // Bumped to 200 / 150 MB because the Home screen loads many thumbnails
  // via horizontal scroll; the stock limits cause visible reloads when the
  // user scrolls back.
  //
  // Image cache flow:
  //   URL → memory LRU (ImageCache, 200/150 MB)
  //       → disk LRU (flutter_cache_manager, 400 objects / 30 days)
  //       → network (HTTP GET)
  //       → decode → display
  PaintingBinding.instance.imageCache
    ..maximumSize = 200
    ..maximumSizeBytes = 150 * (1 << 20); // 150 MB

  await Future.wait([
    PreferencesService.init(),
    HiveService.init(),
    LocalDbService.init(),
  ]);
  runApp(const MyApp());

  // Fire-and-forget background warm-up: pre-populate Home caches 2s after
  // the first frame paints. Uses raw Future primitives (no `async`/`await`).
  // ignore: unawaited_futures
  PrefetchService.warmHomeCaches();
}

/// Root-level messenger key, shared between [MaterialApp] (which attaches
/// the ScaffoldMessenger it creates to this key) and the
/// [_NetworkSyncListener] above it (which needs to surface SnackBars in
/// response to app-wide Stream events — QueueEventBus).
final GlobalKey<ScaffoldMessengerState> rootMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF1C1A0D) : const Color(0xFFFCFAF7),
      textTheme: GoogleFonts.plusJakartaSansTextTheme().apply(
        bodyColor: isDark ? const Color(0xFFF0EDD5) : const Color(0xFF1C1A0D),
        displayColor:
            isDark ? const Color(0xFFF0EDD5) : const Color(0xFF1C1A0D),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFD4C84A),
        brightness: brightness,
        surface: isDark ? const Color(0xFF2A2820) : Colors.white,
        onSurface: isDark ? Colors.white : const Color(0xFF1C1A0D),
        secondary: const Color(0xFF878563),
        onSecondary: isDark ? Colors.white : const Color(0xFF1C1A0D),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF2A2820) : Colors.white,
        foregroundColor:
            isDark ? const Color(0xFFF0EDD5) : const Color(0xFF1C1A0D),
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: isDark ? const Color(0xFFF0EDD5) : const Color(0xFF1C1A0D),
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF2A2820) : const Color(0xFFF2F2E8),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE8E5D1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF3A3A2A) : const Color(0xFFE8E5D1),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD4C84A), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        hintStyle: const TextStyle(
          color: Color(0xFF99944D),
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        prefixIconColor: const Color(0xFF99944D),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF0E342),
          foregroundColor: const Color(0xFF1C1A0D),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectivityViewModel()),
        ChangeNotifierProvider(create: (_) => ThemeViewModel()),
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => HomeViewModel()),
        ChangeNotifierProvider(create: (_) => CatalogViewModel()),
        ChangeNotifierProvider(create: (_) => PostViewModel()),
        ChangeNotifierProvider(create: (_) => ProfileViewModel()),
        ChangeNotifierProvider(create: (_) => FavoritesViewModel()),
      ],
      child: _NetworkSyncListener(
        child: Consumer<ThemeViewModel>(
          builder: (_, themeVM, __) => MaterialApp(
            title: 'AndesHub',
            debugShowCheckedModeBanner: false,
            scaffoldMessengerKey: rootMessengerKey,
            themeMode: themeVM.themeMode,
            theme: _buildTheme(Brightness.light),
            darkTheme: _buildTheme(Brightness.dark),
            home: const AuthGate(),
          ),
        ),
      ),
    );
  }
}

/// Sits just inside the MultiProvider and drains every offline queue the
/// moment connectivity is restored. One instance is mounted for the entire
/// app lifetime, so all background flushes happen here — individual screens
/// don't need to wire their own listeners.
///
/// Also subscribes to the app-wide [QueueEventBus] Stream so it can show a
/// single global SnackBar whenever a queued post/view is flushed, no matter
/// which screen is currently on top.
class _NetworkSyncListener extends StatefulWidget {
  final Widget child;
  const _NetworkSyncListener({required this.child});

  @override
  State<_NetworkSyncListener> createState() => _NetworkSyncListenerState();
}

class _NetworkSyncListenerState extends State<_NetworkSyncListener> {
  ConnectivityViewModel? _connectivity;
  bool _wasOffline = false;
  StreamSubscription<QueueEvent>? _queueSub;

  @override
  void initState() {
    super.initState();
    // Custom Stream subscription — one listener for the entire app lifetime.
    // Each event is a one-shot notification, so we don't use setState here;
    // we just surface a transient SnackBar.
    _queueSub = QueueEventBus.instance.stream.listen(_onQueueEvent);
  }

  void _onQueueEvent(QueueEvent event) {
    final messenger = _rootMessenger;
    if (messenger == null) return;

    final String message = switch (event) {
      PostsFlushed(:final count) => count == 1
          ? '1 pending item was published.'
          : '$count pending items were published.',
      ViewsFlushed(:final count) => count == 1
          ? '1 pending view was synced.'
          : '$count pending views were synced.',
      PostQueued() =>
        'No connection — saved locally. We\'ll publish it when you\'re back online.',
    };

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  ScaffoldMessengerState? get _rootMessenger {
    if (!mounted) return null;
    return rootMessengerKey.currentState;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _connectivity ??= context.read<ConnectivityViewModel>()
      ..addListener(_onConnectivityChanged);
    _wasOffline = _connectivity!.isOffline;
  }

  void _onConnectivityChanged() {
    final c = _connectivity;
    if (c == null) return;
    if (_wasOffline && c.isOnline) {
      _flushAllQueues();
    }
    _wasOffline = c.isOffline;
  }

  /// Best-effort drain of every write-behind queue. Each `flush*` method
  /// is independently safe to retry, so we don't bother coordinating them.
  Future<void> _flushAllQueues() async {
    try {
      await ApiService().flushPendingViews();
    } catch (_) {/* next reconnect will retry */}
    try {
      if (!mounted) return;
      await context.read<PostViewModel>().flushPendingPosts();
    } catch (_) {/* next reconnect will retry */}
  }

  @override
  void dispose() {
    _queueSub?.cancel();
    _connectivity?.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
