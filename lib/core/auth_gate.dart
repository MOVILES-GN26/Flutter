import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../features/auth/views/login_view.dart';
import '../../features/auth/views/onboarding_view.dart';
import '../../features/navigation/main_screen.dart';

enum AuthDestination { home, onboarding, login }

/// AuthGate - Decide el destino inicial basado en el estado de autenticación
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  
  // TODO: Cambiar este valor para forzar el destino durante desarrollo
  // null = verificación automática, AuthDestination.home/onboarding/login = forzar destino
  // ignore: unnecessary_nullable_for_final_variable_declarations
  static const AuthDestination? forceDestination = AuthDestination.home;
  
  Future<AuthDestination> _determineDestination() async {
    // Si hay un destino forzado, usarlo
    if (forceDestination != null) {
      return forceDestination!;
    }
    
    final storageService = StorageService();
    final apiService = ApiService();
    
    // Verificar si hay tokens en storage
    final accessToken = await storageService.getAccessToken();
    final refreshToken = await storageService.getRefreshToken();
    
    // Caso 1: No hay tokens -> Onboarding
    if (accessToken == null && refreshToken == null) {
      return AuthDestination.onboarding;
    }
    
    // Caso 2: Hay tokens -> Verificar validez
    if (accessToken != null) {
      // Intentar validar con el endpoint /home
      final isHomeValid = await apiService.validateHomeAccess();
      
      if (isHomeValid) {
        return AuthDestination.home;
      }
    }
    
    // Caso 3: Access token falló, intentar refresh
    if (refreshToken != null) {
      final refreshSuccess = await apiService.refreshToken();
      
      if (refreshSuccess) {
        // Si el refresh fue exitoso, validar de nuevo
        final isHomeValid = await apiService.validateHomeAccess();
        if (isHomeValid) {
          return AuthDestination.home;
        }
      }
    }
    
    // Caso 4: Todo falló -> Login
    return AuthDestination.login;
  }
  
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AuthDestination>(
      future: _determineDestination(),
      builder: (context, snapshot) {
        // Mostrar loading mientras se determina el destino
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        // Navegar al destino correspondiente
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
