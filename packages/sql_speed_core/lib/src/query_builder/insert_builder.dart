/// Fluent builder for INSERT queries.
///
/// ```dart
/// final id = await db
///   .insertInto('users')
///   .values({'name': 'Alice', 'age': 30})
///   .execute();
/// ```
class InsertBuilder {
  /// Creates a new [InsertBuilder] for the given table.
  InsertBuilder(
    this._table, {
    required Future<int> Function(String, List<Object?>?) executor,
  }) : _executor = executor;

  final String _table;
  final Future<int> Function(String sql, List<Object?>? parameters) _executor;

  Map<String, Object?>? _values;
  bool _orReplace = false;
  bool _orIgnore = false;

  /// Sets the values to insert.
  InsertBuilder values(Map<String, Object?> values) {
    _values = values;
    return this;
  }

  /// Uses INSERT OR REPLACE (upsert).
  InsertBuilder orReplace() {
    _orReplace = true;
    _orIgnore = false;
    return this;
  }

  /// Uses INSERT OR IGNORE (skip on conflict).
  InsertBuilder orIgnore() {
    _orIgnore = true;
    _orReplace = false;
    return this;
  }

  /// Builds the SQL query string.
  String buildSql() {
    if (_values == null || _values!.isEmpty) {
      throw ArgumentError('No values provided for INSERT');
    }

    final buffer = StringBuffer('INSERT ');
    if (_orReplace) buffer.write('OR REPLACE ');
    if (_orIgnore) buffer.write('OR IGNORE ');
    buffer.write('INTO $_table (');
    buffer.write(_values!.keys.join(', '));
    buffer.write(') VALUES (');
    buffer.write(List.filled(_values!.length, '?').join(', '));
    buffer.write(')');

    return buffer.toString();
  }

  /// Builds the parameter list.
  List<Object?> buildParams() {
    return _values?.values.toList() ?? [];
  }

  /// Executes the INSERT and returns the last insert row ID.
  Future<int> execute() {
    return _executor(buildSql(), buildParams());
  }
}
