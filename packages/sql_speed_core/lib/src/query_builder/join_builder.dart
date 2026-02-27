/// Types of SQL JOINs.
enum JoinType {
  /// INNER JOIN — only matching rows from both tables.
  inner,

  /// LEFT JOIN — all rows from left table, matching from right.
  left,

  /// RIGHT JOIN — all rows from right table, matching from left.
  right,

  /// CROSS JOIN — cartesian product of both tables.
  cross,
}

/// Represents a single JOIN clause in a query.
class JoinClause {
  /// Creates a new [JoinClause].
  const JoinClause({
    required this.table,
    required this.on,
    this.type = JoinType.inner,
  });

  /// The table to join.
  final String table;

  /// The ON condition.
  final String on;

  /// The type of join.
  final JoinType type;

  /// Converts this join clause to a SQL string.
  String toSql() {
    final joinWord = switch (type) {
      JoinType.inner => 'INNER JOIN',
      JoinType.left => 'LEFT JOIN',
      JoinType.right => 'RIGHT JOIN',
      JoinType.cross => 'CROSS JOIN',
    };
    return '$joinWord $table ON $on';
  }
}
