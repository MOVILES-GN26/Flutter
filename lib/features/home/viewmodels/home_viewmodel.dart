import 'package:flutter/foundation.dart';
import '../../../core/services/api_service.dart';
import '../models/home_data.dart';
import '../models/home_item.dart';

enum HomeStatus { initial, loading, loaded, error }

/// ViewModel para la pantalla de Home
class HomeViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  HomeStatus _status = HomeStatus.initial;
  HomeData? _homeData;
  List<HomeItem> _recentlyAddedItems = [];
  String? _errorMessage;
  
  HomeStatus get status => _status;
  HomeData? get homeData => _homeData;
  List<HomeItem> get recentlyAddedItems => _recentlyAddedItems;
  String? get errorMessage => _errorMessage;
  
  /// Cargar datos del home
  Future<void> loadHomeData() async {
    _status = HomeStatus.loading;
    _errorMessage = null;
    notifyListeners();
    
    try {
      // Cargar items del home
      _recentlyAddedItems = await _apiService.getHomeItems();
      
      // Validar acceso
      final isValid = await _apiService.validateHomeAccess();
      
      if (isValid || _recentlyAddedItems.isNotEmpty) {
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
