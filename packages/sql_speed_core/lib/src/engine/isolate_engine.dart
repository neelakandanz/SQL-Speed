import 'dart:async';
import 'dart:isolate';

import '../database/database_config.dart';
import '../exceptions/exceptions.dart';
import '../utils/logger.dart';
import 'connection_pool.dart';
import 'database_engine.dart';
import 'query_executor.dart';

/// Message types sent between main and database isolates.
enum _MessageType {
  execute,
  query,
  queryRaw,
  insert,
  update,
  delete,
  transaction,
  batch,
  close,
}

/// A message sent from the main isolate to the database isolate.
class _IsolateRequest {
  const _IsolateRequest({
    required this.type,
    required this.id,
    this.sql,
    this.parameters,
    this.operations,
  });

  final _MessageType type;
  final int id;
  final String? sql;
  final List<Object?>? parameters;
  final List<_BatchOperation>? operations;
}

/// A batch operation for bulk execution.
class _BatchOperation {
  const _BatchOperation(this.sql, this.parameters);

  final String sql;
  final List<Object?>? parameters;
}

/// A response from the database isolate.
class _IsolateResponse {
  const _IsolateResponse({
    required this.id,
    this.data,
    this.error,
  });

  final int id;
  final Object? data;
  final String? error;
}

/// Manages a background isolate for database operations.
///
/// All database operations are sent to a dedicated isolate via
/// SendPort/ReceivePort, keeping the main (UI) thread free from
/// blocking I/O.
class IsolateEngine implements DatabaseEngine {
  IsolateEngine._();

  Isolate? _isolate;
  SendPort? _sendPort;
  final Map<int, Completer<Object?>> _pending = {};
  int _nextId = 0;
  bool _closed = false;

  /// Starts the background isolate and opens the database.
  static Future<IsolateEngine> start(DatabaseConfig config) async {
    final engine = IsolateEngine._();
    await engine._spawn(config);
    return engine;
  }

  Future<void> _spawn(DatabaseConfig config) async {
    final receivePort = ReceivePort();
    final completer = Completer<SendPort>();

    _isolate = await Isolate.spawn(
      _isolateMain,
      _IsolateInit(
        sendPort: receivePort.sendPort,
        path: config.path,
        maxReadConnections: config.maxReadConnections,
        statementCacheSize: config.statementCacheSize,
        enableLogging: config.enableLogging,
        pageSize: config.pageSize,
        cacheSize: config.cacheSize,
        mmapSize: config.mmapSize,
        tempStoreIndex: config.tempStore.index,
      ),
    );

    receivePort.listen((message) {
      if (message is SendPort) {
        completer.complete(message);
      } else if (message is _IsolateResponse) {
        final pending = _pending.remove(message.id);
        if (pending == null) return;

        if (message.error != null) {
          pending.completeError(QueryException(message.error!));
        } else {
          pending.complete(message.data);
        }
      }
    });

    _sendPort = await completer.future;
  }

  /// Sends a request to the isolate and waits for a response.
  Future<T> _request<T>(_IsolateRequest request) {
    if (_closed) throw const DatabaseClosedException();

    final completer = Completer<Object?>();
    _pending[request.id] = completer;
    _sendPort!.send(request);
    return completer.future.then((value) => value as T);
  }

  /// Executes a SQL statement with no return value.
  @override
  Future<void> execute(String sql, [List<Object?>? parameters]) {
    return _request<void>(_IsolateRequest(
      type: _MessageType.execute,
      id: _nextId++,
      sql: sql,
      parameters: parameters,
    ));
  }

  /// Executes a SELECT query and returns results.
  @override
  Future<List<Map<String, Object?>>> query(
    String sql, [
    List<Object?>? parameters,
  ]) {
    return _request<List<Map<String, Object?>>>(_IsolateRequest(
      type: _MessageType.query,
      id: _nextId++,
      sql: sql,
      parameters: parameters,
    ));
  }

  /// Executes a SELECT query and returns raw row data (column-indexed).
  @override
  Future<List<List<Object?>>> queryRaw(
    String sql, [
    List<Object?>? parameters,
  ]) {
    return _request<List<List<Object?>>>(_IsolateRequest(
      type: _MessageType.queryRaw,
      id: _nextId++,
      sql: sql,
      parameters: parameters,
    ));
  }

  /// Executes an INSERT and returns the last insert row ID.
  @override
  Future<int> insert(String sql, [List<Object?>? parameters]) {
    return _request<int>(_IsolateRequest(
      type: _MessageType.insert,
      id: _nextId++,
      sql: sql,
      parameters: parameters,
    ));
  }

  /// Executes an UPDATE/DELETE and returns the affected row count.
  @override
  Future<int> update(String sql, [List<Object?>? parameters]) {
    return _request<int>(_IsolateRequest(
      type: _MessageType.update,
      id: _nextId++,
      sql: sql,
      parameters: parameters,
    ));
  }

  /// Executes multiple operations in a single transaction.
  @override
  Future<void> transaction(
    List<({String sql, List<Object?>? parameters})> operations,
  ) {
    return _request<void>(_IsolateRequest(
      type: _MessageType.transaction,
      id: _nextId++,
      operations: operations
          .map((op) => _BatchOperation(op.sql, op.parameters))
          .toList(),
    ));
  }

  /// Executes batch operations in a single transaction.
  @override
  Future<void> batch(
    List<({String sql, List<Object?>? parameters})> operations,
  ) {
    return _request<void>(_IsolateRequest(
      type: _MessageType.batch,
      id: _nextId++,
      operations: operations
          .map((op) => _BatchOperation(op.sql, op.parameters))
          .toList(),
    ));
  }

  /// Closes the database and kills the background isolate.
  @override
  Future<void> close() async {
    if (_closed) return;

    try {
      // Send close request before setting _closed flag,
      // otherwise _request will reject it.
      final completer = Completer<Object?>();
      final id = _nextId++;
      _pending[id] = completer;
      _sendPort!.send(_IsolateRequest(
        type: _MessageType.close,
        id: id,
      ));
      await completer.future;
    } finally {
      _closed = true;
      _isolate?.kill(priority: Isolate.beforeNextEvent);
      _isolate = null;
      _sendPort = null;

      // Cancel any remaining pending requests
      for (final completer in _pending.values) {
        completer.completeError(const DatabaseClosedException());
      }
      _pending.clear();
    }
  }
}

/// Initialization data sent to the database isolate.
class _IsolateInit {
  const _IsolateInit({
    required this.sendPort,
    required this.path,
    required this.maxReadConnections,
    required this.statementCacheSize,
    required this.enableLogging,
    required this.pageSize,
    required this.cacheSize,
    required this.mmapSize,
    required this.tempStoreIndex,
  });

  final SendPort sendPort;
  final String path;
  final int maxReadConnections;
  final int statementCacheSize;
  final bool enableLogging;
  final int pageSize;
  final int cacheSize;
  final int mmapSize;
  final int tempStoreIndex;
}

/// Entry point for the database isolate.
void _isolateMain(_IsolateInit init) {
  final receivePort = ReceivePort();
  init.sendPort.send(receivePort.sendPort);

  // Build a lightweight config to pass PRAGMAs to the pool
  final pragmaConfig = DatabaseConfig(
    path: init.path,
    pageSize: init.pageSize,
    cacheSize: init.cacheSize,
    mmapSize: init.mmapSize,
    tempStore: TempStore.values[init.tempStoreIndex],
  );

  final pool = ConnectionPool(
    path: init.path,
    maxReadConnections: init.maxReadConnections,
    statementCacheSize: init.statementCacheSize,
  );
  pool.open(config: pragmaConfig);

  final logger = init.enableLogging ? SqlSpeedLogger() : null;

  final writeExecutor = QueryExecutor(
    pool.writeConnection!.database,
    pool.writeConnection!.cache,
    logger: logger,
  );

  // Pre-create read executors to avoid allocation per query
  final readExecutors = <PooledConnection, QueryExecutor>{};
  QueryExecutor _getReadExecutor(PooledConnection conn) {
    return readExecutors.putIfAbsent(
      conn,
      () => QueryExecutor(conn.database, conn.cache, logger: logger),
    );
  }

  receivePort.listen((message) {
    if (message is! _IsolateRequest) return;

    try {
      switch (message.type) {
        case _MessageType.execute:
          writeExecutor.execute(message.sql!, message.parameters);
          init.sendPort.send(_IsolateResponse(id: message.id));

        case _MessageType.query:
          // Use a read connection for SELECTs
          final conn = pool.acquireRead();
          try {
            final result =
                _getReadExecutor(conn).query(message.sql!, message.parameters);
            init.sendPort.send(_IsolateResponse(id: message.id, data: result));
          } finally {
            pool.releaseRead(conn);
          }

        case _MessageType.queryRaw:
          final conn = pool.acquireRead();
          try {
            final resultSet = _getReadExecutor(conn)
                .queryRaw(message.sql!, message.parameters);
            final rows = resultSet.rows
                .map((List<Object?> row) => row.toList())
                .toList();
            init.sendPort.send(_IsolateResponse(id: message.id, data: rows));
          } finally {
            pool.releaseRead(conn);
          }

        case _MessageType.insert:
          final id = writeExecutor.insert(message.sql!, message.parameters);
          init.sendPort.send(_IsolateResponse(id: message.id, data: id));

        case _MessageType.update:
        case _MessageType.delete:
          final count = writeExecutor.update(message.sql!, message.parameters);
          init.sendPort.send(_IsolateResponse(id: message.id, data: count));

        case _MessageType.transaction:
        case _MessageType.batch:
          final db = pool.writeConnection!.database;
          final ops = message.operations!;
          if (ops.isEmpty) {
            init.sendPort.send(_IsolateResponse(id: message.id));
            break;
          }
          db.execute('BEGIN TRANSACTION');
          try {
            // Fast path: if all SQL strings are identical, prepare once and re-bind
            final firstSql = ops.first.sql;
            final allSame = ops.every((op) => op.sql == firstSql);

            if (allSame) {
              final stmt = pool.writeConnection!.cache.get(firstSql);
              for (final op in ops) {
                final params = op.parameters;
                if (params != null && params.isNotEmpty) {
                  stmt.execute(writeExecutor.convertParams(params));
                } else {
                  stmt.execute(const <Object?>[]);
                }
              }
            } else {
              for (final op in ops) {
                writeExecutor.execute(op.sql, op.parameters);
              }
            }
            db.execute('COMMIT');
            init.sendPort.send(_IsolateResponse(id: message.id));
          } catch (e) {
            db.execute('ROLLBACK');
            rethrow;
          }

        case _MessageType.close:
          pool.dispose();
          init.sendPort.send(_IsolateResponse(id: message.id));
          receivePort.close();
      }
    } catch (e) {
      init.sendPort.send(
        _IsolateResponse(id: message.id, error: e.toString()),
      );
    }
  });
}
