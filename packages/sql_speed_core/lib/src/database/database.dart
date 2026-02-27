import 'dart:async';

import '../batch/batch_executor.dart';
import '../engine/isolate_engine.dart';
import '../exceptions/exceptions.dart';
import '../query_builder/delete_builder.dart';
import '../query_builder/insert_builder.dart';
import '../query_builder/select_builder.dart';
import '../query_builder/update_builder.dart';
import '../stream/stream_manager.dart';
import '../types/type_mapper.dart';
import 'database_config.dart';

/// The main sql_speed database class.
///
/// Provides raw SQL execution, reactive streams, query builder,
/// transactions, and batch operations — all running on a background isolate.
///
/// ```dart
/// final db = await SqlSpeed.open(path: 'app.db', version: 1);
/// await db.execute('CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)');
/// final users = await db.query('SELECT * FROM users');
/// await db.close();
/// ```
class SqlSpeedDatabase {
  SqlSpeedDatabase._({
    required IsolateEngine engine,
    required this.config,
  })  : _engine = engine,
        _streamManager = StreamManager(),
        _typeMapper = TypeMapper();

  /// Internal factory used by [SqlSpeed.openWithConfig].
  static SqlSpeedDatabase create({
    required IsolateEngine engine,
    required DatabaseConfig config,
  }) {
    return SqlSpeedDatabase._(engine: engine, config: config);
  }

  final IsolateEngine _engine;
  final StreamManager _streamManager;
  final TypeMapper _typeMapper;
  bool _closed = false;

  /// The database configuration.
  final DatabaseConfig config;

  /// Access the type mapper to register custom type converters.
  TypeMapper get typeMapper => _typeMapper;

  // ---------------------------------------------------------------------------
  // Raw SQL API
  // ---------------------------------------------------------------------------

  /// Executes a SQL statement with no return value.
  ///
  /// Use for CREATE TABLE, DROP TABLE, ALTER TABLE, etc.
  ///
  /// ```dart
  /// await db.execute('CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)');
  /// ```
  Future<void> execute(String sql, [List<Object?>? parameters]) {
    _ensureOpen();
    return _engine.execute(sql, parameters);
  }

  /// Executes a SELECT query and returns results as a list of maps.
  ///
  /// ```dart
  /// final users = await db.query('SELECT * FROM users WHERE age > ?', [25]);
  /// ```
  Future<List<Map<String, Object?>>> query(
    String sql, [
    List<Object?>? parameters,
  ]) {
    _ensureOpen();
    return _engine.query(sql, parameters);
  }

  /// Executes an INSERT and returns the last insert row ID.
  ///
  /// ```dart
  /// final id = await db.insert(
  ///   'INSERT INTO users (name, age) VALUES (?, ?)',
  ///   ['Alice', 30],
  /// );
  /// ```
  Future<int> insert(String sql, [List<Object?>? parameters]) {
    _ensureOpen();
    return _engine.insert(sql, parameters).then((id) {
      _notifyTablesChanged(sql);
      return id;
    });
  }

  /// Executes an UPDATE and returns the number of affected rows.
  ///
  /// ```dart
  /// final count = await db.update(
  ///   'UPDATE users SET age = ? WHERE name = ?',
  ///   [31, 'Alice'],
  /// );
  /// ```
  Future<int> update(String sql, [List<Object?>? parameters]) {
    _ensureOpen();
    return _engine.update(sql, parameters).then((count) {
      _notifyTablesChanged(sql);
      return count;
    });
  }

  /// Executes a DELETE and returns the number of affected rows.
  ///
  /// ```dart
  /// final count = await db.delete('DELETE FROM users WHERE id = ?', [5]);
  /// ```
  Future<int> delete(String sql, [List<Object?>? parameters]) {
    _ensureOpen();
    return _engine.update(sql, parameters).then((count) {
      _notifyTablesChanged(sql);
      return count;
    });
  }

  // ---------------------------------------------------------------------------
  // Transactions
  // ---------------------------------------------------------------------------

  /// Executes a function within a database transaction.
  ///
  /// If the function completes normally, the transaction is committed.
  /// If it throws, the transaction is rolled back.
  ///
  /// ```dart
  /// await db.transaction((txn) async {
  ///   await txn.insert('INSERT INTO users ...', [...]);
  ///   await txn.insert('INSERT INTO profiles ...', [...]);
  /// });
  /// ```
  Future<void> transaction(
    Future<void> Function(TransactionContext txn) action,
  ) async {
    _ensureOpen();
    final ops = <({String sql, List<Object?>? parameters})>[];
    final txn = TransactionContext._(ops);
    await action(txn);
    await _engine.transaction(ops);
  }

  // ---------------------------------------------------------------------------
  // Batch Operations
  // ---------------------------------------------------------------------------

  /// Executes a batch of operations in a single transaction.
  ///
  /// All operations are collected first, then executed together.
  ///
  /// ```dart
  /// await db.batch((batch) {
  ///   for (var user in users) {
  ///     batch.insert('INSERT INTO users VALUES (?, ?)', [user.name, user.age]);
  ///   }
  /// });
  /// ```
  Future<void> batch(void Function(BatchCollector batch) action) async {
    _ensureOpen();
    final collector = BatchCollector();
    action(collector);

    final ops = collector.operations
        .map((op) => (sql: op.sql, parameters: op.parameters))
        .toList();
    await _engine.batch(ops);
  }

  // ---------------------------------------------------------------------------
  // Reactive Streams
  // ---------------------------------------------------------------------------

  /// Returns a reactive stream for the given SQL query.
  ///
  /// The stream emits immediately with current data, then re-emits
  /// whenever the watched tables change.
  ///
  /// ```dart
  /// final stream = db.watch('SELECT * FROM todos WHERE done = 0');
  /// stream.listen((todos) => print('${todos.length} remaining'));
  /// ```
  Stream<List<Map<String, Object?>>> watch(
    String sql, [
    List<Object?>? parameters,
    List<String>? tables,
  ]) {
    _ensureOpen();
    return _streamManager.watch(
      queryFn: () => _engine.query(sql, parameters),
      sql: sql,
      tables: tables,
    );
  }

  // ---------------------------------------------------------------------------
  // Query Builder
  // ---------------------------------------------------------------------------

  /// Creates a fluent SELECT query builder.
  ///
  /// ```dart
  /// final results = await db
  ///   .select('users', columns: ['name', 'age'])
  ///   .where('age > ?', [25])
  ///   .orderBy('name')
  ///   .get();
  /// ```
  SelectBuilder select(String table, {List<String>? columns}) {
    _ensureOpen();
    return SelectBuilder(
      table,
      columns: columns,
      executor: (sql, params) => _engine.query(sql, params),
    );
  }

  /// Creates a fluent INSERT query builder.
  InsertBuilder insertInto(String table) {
    _ensureOpen();
    return InsertBuilder(
      table,
      executor: (sql, params) => _engine.insert(sql, params).then((id) {
        _notifyTablesChanged(sql);
        return id;
      }),
    );
  }

  /// Creates a fluent UPDATE query builder.
  UpdateBuilder updateTable(String table) {
    _ensureOpen();
    return UpdateBuilder(
      table,
      executor: (sql, params) => _engine.update(sql, params).then((count) {
        _notifyTablesChanged(sql);
        return count;
      }),
    );
  }

  /// Creates a fluent DELETE query builder.
  DeleteBuilder deleteFrom(String table) {
    _ensureOpen();
    return DeleteBuilder(
      table,
      executor: (sql, params) => _engine.update(sql, params).then((count) {
        _notifyTablesChanged(sql);
        return count;
      }),
    );
  }

  // ---------------------------------------------------------------------------
  // Type Registration
  // ---------------------------------------------------------------------------

  /// Registers a custom Dart↔SQLite type converter.
  ///
  /// ```dart
  /// db.registerType<Money>(
  ///   encode: (money) => money.cents,
  ///   decode: (value) => Money(value as int),
  /// );
  /// ```
  void registerType<T>({
    required Object? Function(T value) encode,
    required T Function(Object? value) decode,
  }) {
    _typeMapper.register<T>(encode: encode, decode: decode);
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Closes the database and releases all resources.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _streamManager.dispose();
    await _engine.close();
  }

  /// Whether the database is open.
  bool get isOpen => !_closed;

  void _ensureOpen() {
    if (_closed) throw const DatabaseClosedException();
  }

  /// Notifies the stream manager about table changes.
  void _notifyTablesChanged(String sql) {
    final tables =
        _streamManager.activeCount > 0 ? _extractTables(sql) : const <String>{};
    for (final table in tables) {
      _streamManager.onTableChanged(table);
    }
  }

  Set<String> _extractTables(String sql) {
    // Delegate to SQL parser for table extraction
    return importSqlParser(sql);
  }
}

// Helper to avoid circular imports — calls SqlParser.extractTables
Set<String> importSqlParser(String sql) {
  // This gets replaced at runtime; for now inline a simple version
  final tables = <String>{};
  final patterns = [
    RegExp(r'\bFROM\s+(\w+)', caseSensitive: false),
    RegExp(r'\bINTO\s+(\w+)', caseSensitive: false),
    RegExp(r'\bUPDATE\s+(\w+)', caseSensitive: false),
  ];
  for (final pattern in patterns) {
    for (final match in pattern.allMatches(sql)) {
      tables.add(match.group(1)!.toLowerCase());
    }
  }
  return tables;
}

/// Context for operations within a transaction.
class TransactionContext {
  TransactionContext._(this._ops);

  final List<({String sql, List<Object?>? parameters})> _ops;

  /// Adds an INSERT to the transaction.
  void insert(String sql, [List<Object?>? parameters]) {
    _ops.add((sql: sql, parameters: parameters));
  }

  /// Adds an UPDATE to the transaction.
  void update(String sql, [List<Object?>? parameters]) {
    _ops.add((sql: sql, parameters: parameters));
  }

  /// Adds a DELETE to the transaction.
  void delete(String sql, [List<Object?>? parameters]) {
    _ops.add((sql: sql, parameters: parameters));
  }

  /// Adds a raw SQL execution to the transaction.
  void execute(String sql, [List<Object?>? parameters]) {
    _ops.add((sql: sql, parameters: parameters));
  }
}
