import 'package:sqlite3/sqlite3.dart';

/// LRU (Least Recently Used) cache for compiled SQLite prepared statements.
///
/// SQL compilation takes ~30-40% of query execution time. By caching
/// compiled statements, repeated queries skip compilation entirely.
///
/// Default cache size is 100 statements (configurable). When the cache
/// is full, the least recently used statement is evicted and finalized.
class StatementCache {
  /// Creates a new [StatementCache] with the given [maxSize].
  StatementCache(this._db, {int maxSize = 100}) : _maxSize = maxSize;

  final Database _db;
  final int _maxSize;

  /// Ordered map: most recently used at the end.
  final Map<String, PreparedStatement> _cache = {};

  /// Number of cached statements.
  int get size => _cache.length;

  /// Maximum number of statements that can be cached.
  int get maxSize => _maxSize;

  /// Number of cache hits since creation.
  int get hits => _hits;
  int _hits = 0;

  /// Number of cache misses since creation.
  int get misses => _misses;
  int _misses = 0;

  /// Returns the cache hit ratio (0.0 to 1.0).
  double get hitRatio {
    final total = _hits + _misses;
    if (total == 0) return 0.0;
    return _hits / total;
  }

  /// Gets or creates a prepared statement for the given [sql].
  ///
  /// If the statement is cached, it is moved to the end (most recently used).
  /// If not cached, it is compiled and added to the cache.
  /// If the cache is full, the least recently used statement is evicted.
  PreparedStatement get(String sql) {
    final existing = _cache.remove(sql);
    if (existing != null) {
      // Cache hit — move to end (most recently used)
      _hits++;
      _cache[sql] = existing;
      return existing;
    }

    // Cache miss — compile and cache
    _misses++;
    final statement = _db.prepare(sql);

    if (_cache.length >= _maxSize) {
      _evictLru();
    }

    _cache[sql] = statement;
    return statement;
  }

  /// Removes and finalizes the least recently used statement.
  void _evictLru() {
    if (_cache.isEmpty) return;
    final lruKey = _cache.keys.first;
    final lruStatement = _cache.remove(lruKey);
    lruStatement?.dispose();
  }

  /// Removes a specific statement from the cache.
  void remove(String sql) {
    final statement = _cache.remove(sql);
    statement?.dispose();
  }

  /// Clears all cached statements and finalizes them.
  void clear() {
    for (final statement in _cache.values) {
      statement.dispose();
    }
    _cache.clear();
  }

  /// Disposes the cache. Must be called when the database is closed.
  void dispose() {
    clear();
  }
}
