/// Fluent builder for UPDATE queries.
///
/// ```dart
/// final count = await db
///   .updateTable('users')
///   .set({'age': 31})
///   .where('name = ?', ['Alice'])
///   .execute();
/// ```
class UpdateBuilder {
  /// Creates a new [UpdateBuilder] for the given table.
  UpdateBuilder(
    this._table, {
    required Future<int> Function(String, List<Object?>?) executor,
  }) : _executor = executor;

  final String _table;
  final Future<int> Function(String sql, List<Object?>? parameters) _executor;

  Map<String, Object?>? _values;
  String? _whereClause;
  List<Object?> _whereParams = [];

  /// Sets the column values to update.
  UpdateBuilder set(Map<String, Object?> values) {
    _values = values;
    return this;
  }

  /// Adds a WHERE clause.
  UpdateBuilder where(String condition, [List<Object?>? parameters]) {
    _whereClause = condition;
    _whereParams = parameters ?? [];
    return this;
  }

  /// Builds the SQL query string.
  String buildSql() {
    if (_values == null || _values!.isEmpty) {
      throw ArgumentError('No values provided for UPDATE');
    }

    final buffer = StringBuffer('UPDATE $_table SET ');
    buffer.write(_values!.keys.map((k) => '$k = ?').join(', '));

    if (_whereClause != null) {
      buffer.write(' WHERE $_whereClause');
    }

    return buffer.toString();
  }

  /// Builds the parameter list.
  List<Object?> buildParams() {
    return [...?_values?.values, ..._whereParams];
  }

  /// Executes the UPDATE and returns the number of affected rows.
  Future<int> execute() {
    return _executor(buildSql(), buildParams());
  }
}
