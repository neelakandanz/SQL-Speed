/// Fluent builder for DELETE queries.
///
/// ```dart
/// final count = await db
///   .deleteFrom('users')
///   .where('id = ?', [5])
///   .execute();
/// ```
class DeleteBuilder {
  /// Creates a new [DeleteBuilder] for the given table.
  DeleteBuilder(
    this._table, {
    required Future<int> Function(String, List<Object?>?) executor,
  }) : _executor = executor;

  final String _table;
  final Future<int> Function(String sql, List<Object?>? parameters) _executor;

  String? _whereClause;
  List<Object?> _whereParams = [];

  /// Adds a WHERE clause.
  DeleteBuilder where(String condition, [List<Object?>? parameters]) {
    _whereClause = condition;
    _whereParams = parameters ?? [];
    return this;
  }

  /// Builds the SQL query string.
  String buildSql() {
    final buffer = StringBuffer('DELETE FROM $_table');

    if (_whereClause != null) {
      buffer.write(' WHERE $_whereClause');
    }

    return buffer.toString();
  }

  /// Builds the parameter list.
  List<Object?> buildParams() {
    return [..._whereParams];
  }

  /// Executes the DELETE and returns the number of affected rows.
  Future<int> execute() {
    return _executor(buildSql(), buildParams());
  }
}
