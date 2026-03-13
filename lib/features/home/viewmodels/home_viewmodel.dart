import 'package:flutter/foundation.dart';
import '../../../core/services/api_service.dart';
import '../../post/models/post_item.dart';

enum HomeStatus { initial, loading, loaded, error }

/// ViewModel para la pantalla de Home
class HomeViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  HomeStatus _status = HomeStatus.initial;
  List<PostItem> _recentlyAddedItems = [];
  String? _errorMessage;

  HomeStatus get status => _status;
  List<PostItem> get recentlyAddedItems => List.unmodifiable(_recentlyAddedItems);
  String? get errorMessage => _errorMessage;

  /// Cargar los productos recientes desde /products
  Future<void> loadHomeData() async {
    _status = HomeStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _recentlyAddedItems = await _apiService.getRecentProducts();
      _status = HomeStatus.loaded;
    } catch (e) {
      _errorMessage = 'Could not load items. Please try again.';
      _status = HomeStatus.error;
    }

    notifyListeners();
  }
}
