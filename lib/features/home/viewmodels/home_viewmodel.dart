import 'package:flutter/foundation.dart';
import '../../../core/services/api_service.dart';
import '../models/home_data.dart';

enum HomeStatus { initial, loading, loaded, error }

/// ViewModel para la pantalla de Home
class HomeViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  HomeStatus _status = HomeStatus.initial;
  HomeData? _homeData;
  String? _errorMessage;
  
  HomeStatus get status => _status;
  HomeData? get homeData => _homeData;
  String? get errorMessage => _errorMessage;
  
  /// Cargar datos del home
  Future<void> loadHomeData() async {
    _status = HomeStatus.loading;
    _errorMessage = null;
    notifyListeners();
    
    try {
      final isValid = await _apiService.validateHomeAccess();
      
      if (isValid) {
        // Aquí podrías cargar más datos específicos del home
        _homeData = HomeData(message: 'Bienvenido al home');
        _status = HomeStatus.loaded;
      } else {
        _errorMessage = 'No se pudo validar el acceso';
        _status = HomeStatus.error;
      }
    } catch (e) {
      _errorMessage = 'Error al cargar datos';
      _status = HomeStatus.error;
    }
    
    notifyListeners();
  }
}
