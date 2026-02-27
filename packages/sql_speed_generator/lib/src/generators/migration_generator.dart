/// Generates migration SQL by comparing model versions.
///
/// This is a P2 (future) feature. Currently a placeholder.
/// When implemented, it will:
/// 1. Compare the current model schema with the stored schema
/// 2. Generate ALTER TABLE statements for added/removed/modified columns
/// 3. Generate CREATE/DROP TABLE for new/removed tables
/// 4. Produce a migration function that can be used in onUpgrade
class MigrationGenerator {
  /// Generates ALTER TABLE SQL for adding a column.
  static String addColumn(String table, String column, String type) {
    return 'ALTER TABLE $table ADD COLUMN $column $type';
  }

  /// Generates DROP TABLE SQL.
  static String dropTable(String table) {
    return 'DROP TABLE IF EXISTS $table';
  }

  /// Generates CREATE INDEX SQL.
  static String createIndex(String table, String column, {bool unique = false}) {
    final prefix = unique ? 'UNIQUE ' : '';
    final indexName = unique
        ? 'idx_${table}_${column}_unique'
        : 'idx_${table}_$column';
    return 'CREATE ${prefix}INDEX IF NOT EXISTS $indexName ON $table ($column)';
  }

  /// Generates DROP INDEX SQL.
  static String dropIndex(String indexName) {
    return 'DROP INDEX IF EXISTS $indexName';
  }
}
