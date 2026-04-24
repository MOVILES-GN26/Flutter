import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'core/auth_gate.dart';
import 'core/services/hive_service.dart';
import 'core/services/local_db_service.dart';
import 'core/services/preferences_service.dart';
import 'core/viewmodels/theme_viewmodel.dart';
import 'features/auth/viewmodels/auth_viewmodel.dart';
import 'features/catalog/viewmodels/catalog_viewmodel.dart';
import 'features/favorites/viewmodels/favorites_viewmodel.dart';
import 'features/home/viewmodels/home_viewmodel.dart';
import 'features/post/viewmodels/post_viewmodel.dart';
import 'features/profile/viewmodels/profile_viewmodel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    PreferencesService.init(),
    HiveService.init(),
    LocalDbService.init(),
  ]);
  runApp(const MyApp());
}

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
        ChangeNotifierProvider(create: (_) => ThemeViewModel()),
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => HomeViewModel()),
        ChangeNotifierProvider(create: (_) => CatalogViewModel()),
        ChangeNotifierProvider(create: (_) => PostViewModel()),
        ChangeNotifierProvider(create: (_) => ProfileViewModel()),
        ChangeNotifierProvider(create: (_) => FavoritesViewModel()),
      ],
      child: Consumer<ThemeViewModel>(
        builder: (_, themeVM, __) => MaterialApp(
          title: 'AndesHub',
          debugShowCheckedModeBanner: false,
          themeMode: themeVM.themeMode,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          home: const AuthGate(),
        ),
      ),
    );
  }
}
