import 'join_builder.dart';

/// Fluent builder for SELECT queries.
///
/// ```dart
/// final results = await db
///   .select('users', columns: ['name', 'age'])
///   .where('age > ?', [25])
///   .orderBy('name')
///   .limit(10)
///   .get();
/// ```
class SelectBuilder {
  /// Creates a new [SelectBuilder] for the given table.
  SelectBuilder(
    this._table, {
    List<String>? columns,
    required Future<List<Map<String, Object?>>> Function(String, List<Object?>?)
        executor,
  })  : _columns = columns ?? const ['*'],
        _executor = executor;

  final String _table;
  final List<String> _columns;
  final Future<List<Map<String, Object?>>> Function(
    String sql,
    List<Object?>? parameters,
  ) _executor;

  String? _whereClause;
  List<Object?> _whereParams = [];
  String? _orderByClause;
  int? _limitValue;
  int? _offsetValue;
  String? _groupByClause;
  String? _havingClause;
  List<Object?> _havingParams = [];
  final List<JoinClause> _joins = [];
  bool _distinct = false;

  /// Adds a WHERE clause.
  SelectBuilder where(String condition, [List<Object?>? parameters]) {
    _whereClause = condition;
    _whereParams = parameters ?? [];
    return this;
  }

  /// Adds an ORDER BY clause.
  SelectBuilder orderBy(String column, {bool descending = false}) {
    _orderByClause = '$column${descending ? ' DESC' : ' ASC'}';
    return this;
  }

  /// Adds a LIMIT clause.
  SelectBuilder limit(int count) {
    _limitValue = count;
    return this;
  }

  /// Adds an OFFSET clause.
  SelectBuilder offset(int count) {
    _offsetValue = count;
    return this;
  }

  /// Adds a GROUP BY clause.
  SelectBuilder groupBy(String columns) {
    _groupByClause = columns;
    return this;
  }

  /// Adds a HAVING clause (requires GROUP BY).
  SelectBuilder having(String condition, [List<Object?>? parameters]) {
    _havingClause = condition;
    _havingParams = parameters ?? [];
    return this;
  }

  /// Adds a JOIN clause.
  SelectBuilder join(String table, {required String on, JoinType type = JoinType.inner}) {
    _joins.add(JoinClause(table: table, on: on, type: type));
    return this;
  }

  /// Adds a LEFT JOIN clause.
  SelectBuilder leftJoin(String table, {required String on}) {
    return join(table, on: on, type: JoinType.left);
  }

  /// Makes the SELECT DISTINCT.
  SelectBuilder distinct() {
    _distinct = true;
    return this;
  }

  /// Builds the SQL query string.
  String buildSql() {
    final buffer = StringBuffer('SELECT ');
    if (_distinct) buffer.write('DISTINCT ');
    buffer.write(_columns.join(', '));
    buffer.write(' FROM $_table');

    for (final joinClause in _joins) {
      buffer.write(' ${joinClause.toSql()}');
    }

    if (_whereClause != null) {
      buffer.write(' WHERE $_whereClause');
    }

    if (_groupByClause != null) {
      buffer.write(' GROUP BY $_groupByClause');
    }

    if (_havingClause != null) {
      buffer.write(' HAVING $_havingClause');
    }

    if (_orderByClause != null) {
      buffer.write(' ORDER BY $_orderByClause');
    }

    if (_limitValue != null) {
      buffer.write(' LIMIT $_limitValue');
    }

    if (_offsetValue != null) {
      buffer.write(' OFFSET $_offsetValue');
    }

    return buffer.toString();
  }

  /// Builds the combined parameter list.
  List<Object?> buildParams() {
    return [..._whereParams, ..._havingParams];
  }

  /// Executes the query and returns all results.
  Future<List<Map<String, Object?>>> get() {
    return _executor(buildSql(), buildParams());
  }

  /// Executes the query and returns the first result, or null.
  Future<Map<String, Object?>?> first() async {
    _limitValue = 1;
    final results = await get();
    return results.isEmpty ? null : results.first;
  }

  /// Executes the query and returns the count of matching rows.
  Future<int> count() async {
    final originalColumns = List<String>.from(_columns);
    _columns
      ..clear()
      ..add('COUNT(*) as count');
    final result = await first();
    _columns
      ..clear()
      ..addAll(originalColumns);
    return (result?['count'] as int?) ?? 0;
  }
}
