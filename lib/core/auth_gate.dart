import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/services/preferences_service.dart';
import '../../core/services/storage_service.dart';
import '../../features/auth/views/login_view.dart';
import '../../features/auth/views/onboarding_view.dart';
import '../../features/navigation/main_screen.dart';

enum AuthDestination { home, onboarding, login }

/// AuthGate - Decides the initial route based on the authentication state.
///
/// Resolution order:
///   1. [forceDestination] override (dev-only).
///   2. Valid access/refresh token → [AuthDestination.home].
///   3. No tokens, onboarding not yet completed → [AuthDestination.onboarding].
///   4. No tokens, onboarding already completed → [AuthDestination.login].
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  /// Set to a non-null value to force a destination during development.
  /// Leave as `null` in production to honor the real resolution logic.
  static const AuthDestination? forceDestination = null;

  Future<AuthDestination> _determineDestination() async {
    if (forceDestination != null) {
      return forceDestination!;
    }

    final storageService = StorageService();
    final apiService = ApiService();
    final prefs = PreferencesService.instance;

    final accessToken = await storageService.getAccessToken();
    final refreshToken = await storageService.getRefreshToken();

    // No tokens → decide between onboarding and login based on whether the
    // user has ever completed the onboarding flow before.
    if (accessToken == null && refreshToken == null) {
      return prefs.onboardingCompleted
          ? AuthDestination.login
          : AuthDestination.onboarding;
    }

    // Try the access token first.
    if (accessToken != null) {
      final isHomeValid = await apiService.validateHomeAccess();
      if (isHomeValid) return AuthDestination.home;
    }

    // Access token failed (or was missing) — try to refresh.
    if (refreshToken != null) {
      final refreshed = await apiService.refreshToken();
      if (refreshed) {
        final isHomeValid = await apiService.validateHomeAccess();
        if (isHomeValid) return AuthDestination.home;
      }
    }

    // Tokens are unusable. Send the user to login (not onboarding —
    // a returning user with stale tokens has clearly onboarded already).
    return AuthDestination.login;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AuthDestination>(
      future: _determineDestination(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final destination = snapshot.data ?? AuthDestination.onboarding;
        switch (destination) {
          case AuthDestination.home:
            return const MainScreen();
          case AuthDestination.onboarding:
            return const OnboardingView();
          case AuthDestination.login:
            return const LoginView();
        }
      },
    );
  }
}
