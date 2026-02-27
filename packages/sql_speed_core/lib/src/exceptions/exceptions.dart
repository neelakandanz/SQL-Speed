/// Base exception for all sql_speed errors.
class SqlSpeedException implements Exception {
  /// Creates a new [SqlSpeedException].
  const SqlSpeedException(this.message, {this.sql, this.originalError});

  /// Human-readable error message.
  final String message;

  /// The SQL query that caused the error, if applicable.
  final String? sql;

  /// The original error from the SQLite driver, if any.
  final Object? originalError;

  @override
  String toString() {
    final buffer = StringBuffer('SqlSpeedException: $message');
    if (sql != null) {
      buffer.write('\nSQL: $sql');
    }
    if (originalError != null) {
      buffer.write('\nCaused by: $originalError');
    }
    return buffer.toString();
  }
}

/// Thrown when the database file is not found.
class DatabaseNotFoundException extends SqlSpeedException {
  /// Creates a new [DatabaseNotFoundException].
  const DatabaseNotFoundException(String path)
      : super('Database not found at path: $path');
}

/// Thrown when trying to open a database that is already open.
class DatabaseAlreadyOpenException extends SqlSpeedException {
  /// Creates a new [DatabaseAlreadyOpenException].
  const DatabaseAlreadyOpenException()
      : super('Database is already open. Close it before reopening.');
}

/// Thrown when the database has been closed and an operation is attempted.
class DatabaseClosedException extends SqlSpeedException {
  /// Creates a new [DatabaseClosedException].
  const DatabaseClosedException()
      : super('Database is closed. Open it before performing operations.');
}

/// Thrown when a SQL query has invalid syntax or execution fails.
class QueryException extends SqlSpeedException {
  /// Creates a new [QueryException].
  const QueryException(super.message, {super.sql, super.originalError});
}

/// Thrown when a constraint (UNIQUE, FOREIGN KEY, NOT NULL, CHECK) is violated.
class ConstraintException extends SqlSpeedException {
  /// Creates a new [ConstraintException].
  const ConstraintException(super.message, {super.sql, super.originalError});
}

/// Thrown when a Dart↔SQLite type conversion fails.
class TypeMappingException extends SqlSpeedException {
  /// Creates a new [TypeMappingException].
  const TypeMappingException(super.message, {super.originalError});
}

/// Thrown when a migration fails. The database is auto-rolled back.
class MigrationException extends SqlSpeedException {
  /// Creates a new [MigrationException].
  const MigrationException(super.message, {super.sql, super.originalError});

  /// The database version before the failed migration.
  int get fromVersion => 0;

  /// The target version of the failed migration.
  int get toVersion => 0;
}

/// Thrown when an encryption operation fails.
class EncryptionException extends SqlSpeedException {
  /// Creates a new [EncryptionException].
  const EncryptionException(super.message, {super.originalError});
}

/// Thrown when a transaction fails.
class TransactionException extends SqlSpeedException {
  /// Creates a new [TransactionException].
  const TransactionException(super.message, {super.sql, super.originalError});
}
