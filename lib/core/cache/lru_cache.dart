import 'dart:collection';

/// A generic Least-Recently-Used (LRU) cache backed by Dart's [LinkedHashMap].
///
/// ## Algorithm
///
/// * **get(key)**: if the key exists, it is removed and re-inserted at the
///   tail of the map (promoting it to the Most-Recently-Used position).
/// * **put(key, value)**: if the key already exists, it is removed first.
///   If the cache is at capacity, the entry at the **head** of the map (the
///   Least-Recently-Used item) is evicted via [onEvict]. Finally the new
///   entry is inserted at the tail.
/// * **remove(key)**: delegates directly to the map.
///
/// ## Complexity
///
/// All operations are **O(1) amortized** because [LinkedHashMap] maintains
/// insertion order with a doubly-linked list while still providing hash-based
/// key lookup.
///
/// ## Why LRU over LFU or FIFO?
///
/// * **LFU** penalises newly-inserted keys — a product the user just opened
///   would be immediately evicted if the heap is small.
/// * **FIFO** ignores access patterns entirely, so a frequently revisited
///   product would be evicted solely because it was inserted earlier.
/// * **LRU** balances both: the item most-recently used survives, which
///   matches how users navigate a marketplace (revisiting the same 3–5
///   products in a session).
///
/// ## Thread-safety
///
/// Dart is single-threaded per isolate, so no synchronisation is needed.
/// If the cache were moved to a background isolate, a `Lock` from
/// `package:synchronized` would be added.
///
/// ## Comparison with native platform cache structures
///
/// | Structure        | Platform       | Complexity     | When to use                                    | Why NOT used in Flutter                                              |
/// |------------------|----------------|----------------|------------------------------------------------|----------------------------------------------------------------------|
/// | LinkedHashMap+LRU | Dart (this)    | O(1) amortised | Volatile cache of medium-sized objects         | ✓ **chosen** — portable, no native bindings                         |
/// | LruCache         | Android/Kotlin | O(1)           | Bitmap caches with cost-based eviction         | Not available in Dart; would require MethodChannel bindings          |
/// | `SparseArray<E>` | Android        | O(log n)       | int→Object maps <1 000 items, avoids autoboxing | Dart has no int/Integer distinction; `Map<int, V>` is already compact |
/// | `ArrayMap<K,V>`  | Android        | O(log n)       | Maps <1 000 items prioritising memory          | Dart Map already uses a compact implementation                      |
/// | NSCache          | iOS/macOS      | O(1)           | Volatile caches the OS can purge under pressure | Not available in Dart; Flutter's `ImageCache` is the closest analogue |
///
class LruCache<K, V> {
  /// Maximum number of entries the cache will hold before evicting the
  /// least-recently-used item.
  final int maxSize;

  /// Optional callback invoked **before** an entry is removed due to
  /// capacity overflow. Useful for persisting evicted items to a
  /// secondary store (e.g. Hive disk cache) — a two-tier caching pattern.
  final void Function(K key, V value)? onEvict;

  /// The underlying ordered map. Iteration order equals insertion order,
  /// so `.keys.first` is always the LRU entry.
  final LinkedHashMap<K, V> _map = LinkedHashMap<K, V>();

  /// Creates a cache with the given [maxSize] and an optional [onEvict]
  /// callback that fires whenever an entry is evicted to make room.
  LruCache({required this.maxSize, this.onEvict}) : assert(maxSize > 0);

  // ── Public API ────────────────────────────────────────────────────────

  /// Returns the value associated with [key], or `null` if absent.
  ///
  /// **Side-effect**: promotes the entry to MRU position (remove + re-insert).
  V? get(K key) {
    final value = _map.remove(key);
    if (value != null) {
      _map[key] = value; // re-insert at tail → MRU
    }
    return value;
  }

  /// Inserts or updates [key] with [value].
  ///
  /// If the cache is at [maxSize], the LRU entry (`.keys.first`) is evicted
  /// first via [onEvict].
  void put(K key, V value) {
    // If the key already exists, remove it so the re-insert lands at the tail.
    _map.remove(key);

    // Evict LRU entry when at capacity.
    if (_map.length >= maxSize) {
      final lruKey = _map.keys.first;
      final lruValue = _map.remove(lruKey);
      if (lruValue != null) {
        onEvict?.call(lruKey, lruValue);
      }
    }

    _map[key] = value;
  }

  /// Removes [key] from the cache. Returns the removed value, or `null`.
  V? remove(K key) => _map.remove(key);

  /// Whether [key] is present in the cache.
  ///
  /// **Note**: does NOT promote the key (peek semantics). Use [get] if
  /// you want to count the access as a "use".
  bool containsKey(K key) => _map.containsKey(key);

  /// Current number of entries.
  int get length => _map.length;

  /// Whether the cache is empty.
  bool get isEmpty => _map.isEmpty;

  /// Removes all entries. Does **not** fire [onEvict].
  void clear() => _map.clear();

  // ── Debug helpers ─────────────────────────────────────────────────────

  /// Returns an unmodifiable view of all keys, ordered from LRU → MRU.
  Iterable<K> get keys => _map.keys;

  @override
  String toString() => 'LruCache(size=${_map.length}, maxSize=$maxSize)';
}
