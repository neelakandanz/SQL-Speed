/// Marks a field to have a database index.
///
/// Indexes improve query performance on columns used in
/// WHERE, ORDER BY, and JOIN clauses.
///
/// ```dart
/// @Index()
/// final String email;
/// ```
class Index {
  /// Creates a new [Index] annotation.
  const Index({this.name});

  /// Custom index name. Defaults to `idx_<table>_<column>`.
  final String? name;
}

/// Marks a field to have a unique database index.
///
/// Ensures no two rows can have the same value for this column.
///
/// ```dart
/// @UniqueIndex()
/// final String email;
/// ```
class UniqueIndex {
  /// Creates a new [UniqueIndex] annotation.
  const UniqueIndex({this.name});

  /// Custom index name. Defaults to `idx_<table>_<column>_unique`.
  final String? name;
}

/// Marks a composite index across multiple columns.
///
/// Applied at the class level.
///
/// ```dart
/// @CompositeIndex(['first_name', 'last_name'])
/// @Table(name: 'users')
/// class UserModel { ... }
/// ```
class CompositeIndex {
  /// Creates a new [CompositeIndex] annotation.
  const CompositeIndex(this.columns, {this.unique = false, this.name});

  /// The column names to include in the composite index.
  final List<String> columns;

  /// Whether the index enforces uniqueness.
  final bool unique;

  /// Custom index name.
  final String? name;
}
