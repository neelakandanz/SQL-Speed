import 'dart:async';

import 'package:sqlite3/sqlite3.dart' hide DatabaseConfig;

import '../database/database_config.dart';
import '../exceptions/exceptions.dart';
import 'statement_cache.dart';

/// A pooled database connection with its own statement cache.
class PooledConnection {
  /// Creates a new [PooledConnection].
  PooledConnection(this.database, {int statementCacheSize = 100})
      : cache = StatementCache(database, maxSize: statementCacheSize);

  /// The underlying SQLite database connection.
  final Database database;

  /// Statement cache for this connection.
  final StatementCache cache;

  /// Whether this connection is currently in use.
  bool inUse = false;

  /// Disposes this connection and its cache.
  void dispose() {
    cache.dispose();
    database.dispose();
  }
}

/// Manages a pool of read connections and a single write connection.
///
/// Architecture:
/// - 1 write connection (serialized writes via queue)
/// - N read connections (parallel reads, default N=3)
/// - WAL mode enables readers and writer to operate concurrently
class ConnectionPool {
  /// Creates a new [ConnectionPool].
  ConnectionPool({
    required this.path,
    this.maxReadConnections = 3,
    this.statementCacheSize = 100,
  });

  /// Path to the database file.
  final String path;

  /// Maximum number of read connections.
  final int maxReadConnections;

  /// Statement cache size per connection.
  final int statementCacheSize;

  PooledConnection? _writeConnection;
  final List<PooledConnection> _readConnections = [];
  final _writeQueue = <Completer<void>>[];
  bool _writeLocked = false;
  bool _disposed = false;

  /// Whether this pool uses an in-memory database.
  bool get _isMemory => path == ':memory:';

  /// Opens the connection pool.
  void open({DatabaseConfig? config}) {
    if (_disposed) {
      throw const DatabaseClosedException();
    }

    // Create write connection
    final writeDb = sqlite3.open(path);
    writeDb.execute('PRAGMA journal_mode=WAL');
    writeDb.execute('PRAGMA synchronous=NORMAL');
    writeDb.execute('PRAGMA foreign_keys=ON');
    // Performance PRAGMAs
    writeDb.execute('PRAGMA page_size=${config?.pageSize ?? 4096}');
    writeDb.execute('PRAGMA cache_size=${config?.cacheSize ?? -8000}');
    writeDb.execute('PRAGMA mmap_size=${config?.mmapSize ?? 268435456}');
    writeDb.execute(
        'PRAGMA temp_store=${(config?.tempStore ?? TempStore.memory).index}');
    writeDb.execute('PRAGMA wal_autocheckpoint=1000');
    _writeConnection = PooledConnection(
      writeDb,
      statementCacheSize: statementCacheSize,
    );

    if (!_isMemory) {
      // Create read connections (only for file-based databases).
      // For :memory: databases, each sqlite3.open(':memory:') creates
      // a separate database, so reads must go through the write connection.
      for (var i = 0; i < maxReadConnections; i++) {
        final readDb = sqlite3.open(path, mode: OpenMode.readOnly);
        // Apply read-only PRAGMAs
        readDb.execute('PRAGMA cache_size=${config?.cacheSize ?? -8000}');
        readDb.execute('PRAGMA mmap_size=${config?.mmapSize ?? 268435456}');
        readDb.execute(
            'PRAGMA temp_store=${(config?.tempStore ?? TempStore.memory).index}');
        _readConnections.add(
          PooledConnection(readDb, statementCacheSize: statementCacheSize),
        );
      }
    }
  }

  /// Acquires the write connection. Only one writer at a time.
  Future<PooledConnection> acquireWrite() async {
    if (_disposed) throw const DatabaseClosedException();

    if (_writeLocked) {
      final completer = Completer<void>();
      _writeQueue.add(completer);
      await completer.future;
    }

    _writeLocked = true;
    return _writeConnection!;
  }

  /// Releases the write connection for the next writer.
  void releaseWrite() {
    _writeLocked = false;
    if (_writeQueue.isNotEmpty) {
      final next = _writeQueue.removeAt(0);
      next.complete();
    }
  }

  /// Acquires a read connection from the pool.
  PooledConnection acquireRead() {
    if (_disposed) throw const DatabaseClosedException();

    // For in-memory databases, use the write connection for reads
    if (_isMemory) return _writeConnection!;

    // Find an idle read connection
    for (final conn in _readConnections) {
      if (!conn.inUse) {
        conn.inUse = true;
        return conn;
      }
    }

    // All busy — return first one (will serialize with it)
    final conn = _readConnections.first;
    return conn;
  }

  /// Releases a read connection back to the pool.
  void releaseRead(PooledConnection connection) {
    connection.inUse = false;
  }

  /// Returns the write connection directly (for use in isolate).
  PooledConnection? get writeConnection => _writeConnection;

  /// Disposes all connections.
  void dispose() {
    _disposed = true;
    _writeConnection?.dispose();
    for (final conn in _readConnections) {
      conn.dispose();
    }
    _readConnections.clear();

    // Cancel any pending writers
    for (final completer in _writeQueue) {
      completer.completeError(const DatabaseClosedException());
    }
    _writeQueue.clear();
  }
}
