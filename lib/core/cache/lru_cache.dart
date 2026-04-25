import 'dart:collection';


class LruCache<K, V> {
  final int maxSize;
  final void Function(K key, V value)? onEvict;

  final LinkedHashMap<K, V> _map = LinkedHashMap<K, V>();


  LruCache({required this.maxSize, this.onEvict}) : assert(maxSize > 0);

  V? get(K key) {
    final value = _map.remove(key);
    if (value != null) {
      _map[key] = value; 
    }
    return value;
  }

  void put(K key, V value) {
    _map.remove(key);

    if (_map.length >= maxSize) {
      final lruKey = _map.keys.first;
      final lruValue = _map.remove(lruKey);
      if (lruValue != null) {
        onEvict?.call(lruKey, lruValue);
      }
    }

    _map[key] = value;
  }

  V? remove(K key) => _map.remove(key);

  bool containsKey(K key) => _map.containsKey(key);

  int get length => _map.length;

  bool get isEmpty => _map.isEmpty;

  void clear() => _map.clear();

  Iterable<K> get keys => _map.keys;

  @override
  String toString() => 'LruCache(size=${_map.length}, maxSize=$maxSize)';
}
