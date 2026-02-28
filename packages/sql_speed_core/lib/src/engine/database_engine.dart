/// Abstract interface for database engines.
///
/// Both [IsolateEngine] (background isolate) and [SyncEngine] (direct FFI)
/// implement this interface, allowing [SqlSpeedDatabase] to work with either.
abstract class DatabaseEngine {
  /// Executes a SQL statement with no return value.
  Future<void> execute(String sql, [List<Object?>? parameters]);

  /// Executes a SELECT query and returns results as a list of maps.
  Future<List<Map<String, Object?>>> query(
    String sql, [
    List<Object?>? parameters,
  ]);

  /// Executes a SELECT query and returns raw row data (column-indexed).
  ///
  /// Faster than [query] when Map overhead is unnecessary.
  Future<List<List<Object?>>> queryRaw(
    String sql, [
    List<Object?>? parameters,
  ]);

  /// Executes an INSERT and returns the last insert row ID.
  Future<int> insert(String sql, [List<Object?>? parameters]);

  /// Executes an UPDATE/DELETE and returns the affected row count.
  Future<int> update(String sql, [List<Object?>? parameters]);

  /// Executes multiple operations in a single transaction.
  Future<void> transaction(
    List<({String sql, List<Object?>? parameters})> operations,
  );

  /// Executes batch operations in a single transaction.
  Future<void> batch(
    List<({String sql, List<Object?>? parameters})> operations,
  );

  /// Closes the database and releases all resources.
  Future<void> close();
}
