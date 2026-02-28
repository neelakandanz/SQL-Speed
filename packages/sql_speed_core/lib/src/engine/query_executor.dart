import 'package:sqlite3/sqlite3.dart'
    show Database, PreparedStatement, ResultSet, SqliteException;

import '../exceptions/exceptions.dart';
import '../utils/logger.dart';
import 'statement_cache.dart';

/// Executes SQL queries using cached prepared statements.
///
/// Handles parameter binding, result mapping, and error wrapping.
class QueryExecutor {
  /// Creates a new [QueryExecutor].
  QueryExecutor(this._db, this._cache, {SqlSpeedLogger? logger})
      : _logger = logger;

  final Database _db;
  final StatementCache _cache;
  final SqlSpeedLogger? _logger;

  /// Executes a SQL statement that returns no data (CREATE, DROP, ALTER, etc.).
  void execute(String sql, [List<Object?>? parameters]) {
    _logger?.logQuery(sql, parameters);
    final Stopwatch? stopwatch =
        _logger != null ? (Stopwatch()..start()) : null;

    try {
      if (parameters == null || parameters.isEmpty) {
        _db.execute(sql);
      } else {
        final stmt = _cache.get(sql);
        stmt.execute(convertParams(parameters));
      }
    } on SqliteException catch (e) {
      throw _wrapException(e, sql);
    } finally {
      if (stopwatch != null) {
        stopwatch.stop();
        _logger!.logTiming(sql, stopwatch.elapsed);
      }
    }
  }

  /// Executes a SELECT query and returns results as a list of maps.
  List<Map<String, Object?>> query(String sql, [List<Object?>? parameters]) {
    _logger?.logQuery(sql, parameters);
    final Stopwatch? stopwatch =
        _logger != null ? (Stopwatch()..start()) : null;

    try {
      final resultSet = _selectRaw(sql, parameters);
      return _mapResults(resultSet);
    } on SqliteException catch (e) {
      throw _wrapException(e, sql);
    } finally {
      if (stopwatch != null) {
        stopwatch.stop();
        _logger!.logTiming(sql, stopwatch.elapsed);
      }
    }
  }

  /// Executes a SELECT query and returns the raw [ResultSet].
  ///
  /// Avoids Map allocation overhead — caller accesses results by column index.
  ResultSet queryRaw(String sql, [List<Object?>? parameters]) {
    _logger?.logQuery(sql, parameters);
    try {
      return _selectRaw(sql, parameters);
    } on SqliteException catch (e) {
      throw _wrapException(e, sql);
    }
  }

  /// Internal: runs a SELECT and returns the raw ResultSet.
  ResultSet _selectRaw(String sql, [List<Object?>? parameters]) {
    final stmt = _cache.get(sql);
    if (parameters == null || parameters.isEmpty) {
      return stmt.select();
    } else {
      return stmt.select(convertParams(parameters));
    }
  }

  /// Executes an INSERT and returns the last insert row ID.
  int insert(String sql, [List<Object?>? parameters]) {
    _logger?.logQuery(sql, parameters);
    final Stopwatch? stopwatch =
        _logger != null ? (Stopwatch()..start()) : null;

    try {
      final stmt = _cache.get(sql);
      if (parameters != null && parameters.isNotEmpty) {
        stmt.execute(convertParams(parameters));
      } else {
        stmt.execute(const <Object?>[]);
      }
      return _db.lastInsertRowId;
    } on SqliteException catch (e) {
      throw _wrapException(e, sql);
    } finally {
      if (stopwatch != null) {
        stopwatch.stop();
        _logger!.logTiming(sql, stopwatch.elapsed);
      }
    }
  }

  /// Executes an UPDATE/DELETE and returns the number of affected rows.
  int update(String sql, [List<Object?>? parameters]) {
    _logger?.logQuery(sql, parameters);
    final Stopwatch? stopwatch =
        _logger != null ? (Stopwatch()..start()) : null;

    try {
      final stmt = _cache.get(sql);
      if (parameters != null && parameters.isNotEmpty) {
        stmt.execute(convertParams(parameters));
      } else {
        stmt.execute(const <Object?>[]);
      }
      return _db.updatedRows;
    } on SqliteException catch (e) {
      throw _wrapException(e, sql);
    } finally {
      if (stopwatch != null) {
        stopwatch.stop();
        _logger!.logTiming(sql, stopwatch.elapsed);
      }
    }
  }

  /// Converts parameters, replacing `bool` and `DateTime` with SQLite types.
  /// Returns the original list if no conversion is needed to avoid allocation.
  List<Object?> convertParams(List<Object?> parameters) {
    // Fast path: check if any conversion is needed
    var needsConversion = false;
    for (final p in parameters) {
      if (p is bool || p is DateTime) {
        needsConversion = true;
        break;
      }
    }
    if (!needsConversion) return parameters;

    return parameters.map((p) {
      if (p is bool) return p ? 1 : 0;
      if (p is DateTime) return p.millisecondsSinceEpoch;
      return p;
    }).toList();
  }

  /// Maps a ResultSet to a list of maps.
  List<Map<String, Object?>> _mapResults(ResultSet resultSet) {
    final columns = resultSet.columnNames;
    final rows = resultSet.rows;
    if (rows.isEmpty) return const [];
    // Use Map.fromIterables for efficient single-pass construction
    return List<Map<String, Object?>>.generate(
      rows.length,
      (i) => Map<String, Object?>.fromIterables(columns, rows[i]),
      growable: false,
    );
  }

  /// Wraps a SQLite exception into a sql_speed exception.
  SqlSpeedException _wrapException(SqliteException e, String sql) {
    final message = e.message;

    if (message.contains('UNIQUE constraint') ||
        message.contains('FOREIGN KEY constraint') ||
        message.contains('NOT NULL constraint') ||
        message.contains('CHECK constraint')) {
      return ConstraintException(message, sql: sql, originalError: e);
    }

    return QueryException(message, sql: sql, originalError: e);
  }
}
