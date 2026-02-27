import 'package:sqlite3/sqlite3.dart';

/// Verifies database schema integrity after migrations.
class SchemaVerifier {
  /// Verifies that all expected tables exist in the database.
  ///
  /// Returns a list of missing table names. Empty list means all tables exist.
  List<String> verifyTables(Database db, List<String> expectedTables) {
    final existingTables = _getTableNames(db);
    final missing = <String>[];

    for (final table in expectedTables) {
      if (!existingTables.contains(table.toLowerCase())) {
        missing.add(table);
      }
    }

    return missing;
  }

  /// Returns a list of all table names in the database.
  List<String> getTableNames(Database db) => _getTableNames(db);

  /// Returns the column info for a given table.
  List<ColumnInfo> getColumns(Database db, String tableName) {
    final result = db.select('PRAGMA table_info("$tableName")');
    return result.rows.map((row) {
      return ColumnInfo(
        name: row[1] as String,
        type: row[2] as String,
        notNull: (row[3] as int) == 1,
        defaultValue: row[4],
        primaryKey: (row[5] as int) > 0,
      );
    }).toList();
  }

  /// Runs a SQLite integrity check.
  ///
  /// Returns `null` if the database is healthy, or an error message.
  String? integrityCheck(Database db) {
    final result = db.select('PRAGMA integrity_check');
    if (result.isEmpty) return 'No result from integrity check';
    final value = result.first.values.first as String;
    return value == 'ok' ? null : value;
  }

  List<String> _getTableNames(Database db) {
    final result = db.select(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
    );
    return result.rows.map((row) => (row[0] as String).toLowerCase()).toList();
  }
}

/// Information about a database column.
class ColumnInfo {
  /// Creates a new [ColumnInfo].
  const ColumnInfo({
    required this.name,
    required this.type,
    required this.notNull,
    required this.primaryKey,
    this.defaultValue,
  });

  /// Column name.
  final String name;

  /// SQLite type name (TEXT, INTEGER, REAL, BLOB, NULL).
  final String type;

  /// Whether the column has a NOT NULL constraint.
  final bool notNull;

  /// Default value expression, if any.
  final Object? defaultValue;

  /// Whether the column is part of the primary key.
  final bool primaryKey;

  @override
  String toString() =>
      'ColumnInfo($name $type${notNull ? " NOT NULL" : ""}${primaryKey ? " PK" : ""})';
}
