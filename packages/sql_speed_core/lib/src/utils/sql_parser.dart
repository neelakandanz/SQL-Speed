/// Lightweight SQL parser that extracts table names from queries.
///
/// Used by the stream engine to auto-detect which tables a query
/// depends on, so that table change events can trigger re-queries.
class SqlParser {
  /// Extracts table names from a SQL query string.
  ///
  /// Handles common patterns:
  /// - `FROM table_name`
  /// - `JOIN table_name`
  /// - `INSERT INTO table_name`
  /// - `UPDATE table_name`
  /// - `DELETE FROM table_name`
  /// - Subqueries and CTEs
  ///
  /// Returns a set of lowercase table names.
  static Set<String> extractTables(String sql) {
    final tables = <String>{};
    final normalized = sql
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .replaceAll('\t', ' ');

    // Match patterns: FROM/JOIN/INTO/UPDATE + table name
    final patterns = [
      RegExp(r'\bFROM\s+(\w+)', caseSensitive: false),
      RegExp(r'\bJOIN\s+(\w+)', caseSensitive: false),
      RegExp(r'\bINTO\s+(\w+)', caseSensitive: false),
      RegExp(r'\bUPDATE\s+(\w+)', caseSensitive: false),
      RegExp(r'\bTABLE\s+(?:IF\s+(?:NOT\s+)?EXISTS\s+)?(\w+)',
          caseSensitive: false),
    ];

    for (final pattern in patterns) {
      for (final match in pattern.allMatches(normalized)) {
        final tableName = match.group(1)!.toLowerCase();
        // Skip SQL keywords that might be false positives
        if (!_sqlKeywords.contains(tableName)) {
          tables.add(tableName);
        }
      }
    }

    return tables;
  }

  /// Common SQL keywords that should not be treated as table names.
  static const _sqlKeywords = {
    'select',
    'from',
    'where',
    'and',
    'or',
    'not',
    'in',
    'is',
    'null',
    'like',
    'between',
    'exists',
    'all',
    'any',
    'as',
    'on',
    'set',
    'values',
    'order',
    'by',
    'group',
    'having',
    'limit',
    'offset',
    'union',
    'except',
    'intersect',
    'case',
    'when',
    'then',
    'else',
    'end',
    'with',
    'recursive',
  };
}
