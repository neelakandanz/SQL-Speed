import '../database/database_config.dart';
import '../exceptions/exceptions.dart';
import 'connection_pool.dart';
import 'database_engine.dart';
import 'query_executor.dart';

/// Synchronous database engine that runs SQLite operations directly
/// on the calling thread via FFI — no isolate overhead.
///
/// This eliminates the ~1000-1500µs isolate round-trip cost per operation,
/// bringing single-operation latency down to ~5-50µs (comparable to
/// ObjectBox/Isar's FFI-based approach).
///
/// **Trade-off**: Operations block the calling isolate. For most CRUD
/// operations this is negligible (<1ms), but long-running queries or
/// large bulk operations should still use [IsolateEngine].
class SyncEngine implements DatabaseEngine {
  SyncEngine._(this._pool, this._writeExecutor);

  final ConnectionPool _pool;
  final QueryExecutor _writeExecutor;
  bool _closed = false;

  // Pre-create read executors to avoid allocation per query
  final _readExecutors = <PooledConnection, QueryExecutor>{};

  /// Opens a database synchronously and returns a [SyncEngine].
  static SyncEngine open(DatabaseConfig config) {
    final pool = ConnectionPool(
      path: config.path,
      maxReadConnections: config.maxReadConnections,
      statementCacheSize: config.statementCacheSize,
    );
    pool.open(config: config);

    final writeExecutor = QueryExecutor(
      pool.writeConnection!.database,
      pool.writeConnection!.cache,
    );

    return SyncEngine._(pool, writeExecutor);
  }

  QueryExecutor _getReadExecutor(PooledConnection conn) {
    return _readExecutors.putIfAbsent(
      conn,
      () => QueryExecutor(conn.database, conn.cache),
    );
  }

  void _ensureOpen() {
    if (_closed) throw const DatabaseClosedException();
  }

  @override
  Future<void> execute(String sql, [List<Object?>? parameters]) {
    _ensureOpen();
    _writeExecutor.execute(sql, parameters);
    return Future<void>.value();
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String sql, [
    List<Object?>? parameters,
  ]) {
    _ensureOpen();
    final conn = _pool.acquireRead();
    try {
      final result = _getReadExecutor(conn).query(sql, parameters);
      return Future.value(result);
    } finally {
      _pool.releaseRead(conn);
    }
  }

  @override
  Future<List<List<Object?>>> queryRaw(
    String sql, [
    List<Object?>? parameters,
  ]) {
    _ensureOpen();
    final conn = _pool.acquireRead();
    try {
      final resultSet = _getReadExecutor(conn).queryRaw(sql, parameters);
      final rows =
          resultSet.rows.map((List<Object?> row) => row.toList()).toList();
      return Future.value(rows);
    } finally {
      _pool.releaseRead(conn);
    }
  }

  @override
  Future<int> insert(String sql, [List<Object?>? parameters]) {
    _ensureOpen();
    final id = _writeExecutor.insert(sql, parameters);
    return Future.value(id);
  }

  @override
  Future<int> update(String sql, [List<Object?>? parameters]) {
    _ensureOpen();
    final count = _writeExecutor.update(sql, parameters);
    return Future.value(count);
  }

  @override
  Future<void> transaction(
    List<({String sql, List<Object?>? parameters})> operations,
  ) {
    _ensureOpen();
    _executeBatch(operations);
    return Future<void>.value();
  }

  @override
  Future<void> batch(
    List<({String sql, List<Object?>? parameters})> operations,
  ) {
    _ensureOpen();
    _executeBatch(operations);
    return Future<void>.value();
  }

  void _executeBatch(
    List<({String sql, List<Object?>? parameters})> operations,
  ) {
    if (operations.isEmpty) return;

    final db = _pool.writeConnection!.database;
    db.execute('BEGIN TRANSACTION');
    try {
      // Fast path: if all SQL strings are identical, prepare once and re-bind
      final firstSql = operations.first.sql;
      final allSame = operations.every((op) => op.sql == firstSql);

      if (allSame) {
        final stmt = _pool.writeConnection!.cache.get(firstSql);
        for (final op in operations) {
          final params = op.parameters;
          if (params != null && params.isNotEmpty) {
            stmt.execute(_writeExecutor.convertParams(params));
          } else {
            stmt.execute(const <Object?>[]);
          }
        }
      } else {
        for (final op in operations) {
          _writeExecutor.execute(op.sql, op.parameters);
        }
      }
      db.execute('COMMIT');
    } catch (e) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  @override
  Future<void> close() {
    if (_closed) return Future<void>.value();
    _closed = true;
    _pool.dispose();
    return Future<void>.value();
  }
}
